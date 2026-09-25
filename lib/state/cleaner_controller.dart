import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/gallery_service.dart';
import '../services/hash_store.dart';
import '../services/scan_pipeline.dart';

/// مراحل التطبيق — الشاشة الوحيدة بتعرض حسب المرحلة.
enum Stage { needsPermission, pickMonth, scanning, results, deleting, done }

/// كل حالة التطبيق.
class CleanerController extends ChangeNotifier {
  CleanerController({
    required this._gallery,
    required this._store,
    required this._pipeline,
  });

  final GalleryService _gallery;
  final DecisionStore _store;
  final ScanPipeline _pipeline;

  Stage _stage = Stage.needsPermission;
  Stage get stage => _stage;

  bool get modelAvailable => _pipeline.scorer.isAvailable;

  int? _year;
  int? _month;
  int? get year => _year;
  int? get month => _month;

  int _total = 0;
  int get total => _total;

  ScanStats _stats = ScanStats();
  ScanStats get stats => _stats;

  final List<ScanMatch> _matches = [];
  List<ScanMatch> get matches => List.unmodifiable(_matches);

  final Set<String> _selected = {};
  bool isSelected(String id) => _selected.contains(id);
  int get selectedCount => _selected.length;

  int _deletedCount = 0;
  int get deletedCount => _deletedCount;

  String? _error;
  String? get error => _error;

  int get rememberedKept => _store.count(Decision.kept);
  int get rememberedDeleted => _store.count(Decision.deleted);

  StreamSubscription<ScanProgress>? _scan;

  void _go(Stage stage) {
    _stage = stage;
    notifyListeners();
  }

  Future<void> requestPermission() async {
    _error = null;
    final ok = await _gallery.requestPermission();
    if (ok) {
      _go(Stage.pickMonth);
    } else {
      _error = 'التطبيق بحاجة لصلاحية الوصول للصور حتى يشتغل.';
      _go(Stage.needsPermission);
    }
  }

  Future<void> openSettings() => _gallery.openSettings();

  Future<void> startScan(int year, int month) async {
    await _scan?.cancel();
    _year = year;
    _month = month;
    _error = null;
    _matches.clear();
    _selected.clear();
    _stats = ScanStats();
    _total = 0;
    _go(Stage.scanning);

    final List<GalleryImage> images;
    try {
      images = await _gallery.imagesForMonth(year, month);
    } catch (e) {
      _error = 'ما قدرنا نقرأ الصور: $e';
      _go(Stage.pickMonth);
      return;
    }
    if (_stage != Stage.scanning) return; // انلغى أثناء التحميل.
    _total = images.length;
    notifyListeners();

    _scan = _pipeline.run(images).listen(
      (progress) {
        _stats = progress.stats;
        final match = progress.match;
        if (match != null) {
          _matches.add(match);
          _selected.add(match.candidate.id);
        }
        notifyListeners();
      },
      onDone: () {
        _scan = null;
        if (_stage == Stage.scanning) _go(Stage.results);
      },
    );
  }

  /// يوقف الفحص ويعرض اللي انلقى لحد هلق.
  Future<void> stopScan() async {
    await _scan?.cancel();
    _scan = null;
    _go(Stage.results);
  }

  void toggle(String id) {
    if (!_selected.remove(id)) _selected.add(id);
    notifyListeners();
  }

  void selectAll(bool value) {
    _selected.clear();
    if (value) _selected.addAll(_matches.map((m) => m.candidate.id));
    notifyListeners();
  }

  /// يمسح المختار، وبيتعلم: المختار → "محذوفات"، غير المختار → "ما تعلّم عليها".
  Future<void> deleteSelected() async {
    final chosen = _matches.where((m) => isSelected(m.candidate.id)).toList();
    final unchosen = _matches.where((m) => !isSelected(m.candidate.id)).toList();
    _error = null;
    _go(Stage.deleting);

    List<String> deletedIds;
    try {
      deletedIds = await _gallery.delete(
        chosen.map((m) => m.candidate as GalleryImage).toList(),
      );
    } catch (e) {
      _error = 'صار خطأ بالحذف: $e';
      _go(Stage.results);
      return;
    }

    if (chosen.isNotEmpty && deletedIds.isEmpty) {
      // المستخدم لغى نافذة التأكيد — ما منتعلم شي.
      _go(Stage.results);
      return;
    }

    final deleted = deletedIds.toSet();
    await _store.record(
      Decision.deleted,
      chosen.where((m) => deleted.contains(m.candidate.id)).map((m) => m.hash),
    );
    await _store.record(Decision.kept, unchosen.map((m) => m.hash));

    _deletedCount = deleted.length;
    _matches.removeWhere((m) => deleted.contains(m.candidate.id));
    _selected.removeAll(deleted);
    _go(Stage.done);
  }

  void backToMonths() {
    _scan?.cancel();
    _scan = null;
    _matches.clear();
    _selected.clear();
    _go(Stage.pickMonth);
  }

  Future<void> clearMemory() async {
    await _store.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _scan?.cancel();
    super.dispose();
  }
}
