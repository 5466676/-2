import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../config.dart';
import 'image_hash.dart';

/// نوع القرار اللي أخده المستخدم على صورة.
enum Decision {
  /// شال عنها الصح — مش معايدة، ما نرجع نعلّم عليها.
  kept,

  /// مسحها — أي صورة شبهها بتنعلّم مباشرة.
  deleted,
}

/// ذاكرة القرارات: بصمات الصور اللي المستخدم قرر فيها سابقًا.
///
/// البصمات كلها بتنحمّل للذاكرة (عددها صغير)، فالمقارنة سريعة.
class DecisionStore {
  DecisionStore({this._maxDistance = AppConfig.hashMatchDistance});

  final int _maxDistance;
  final Map<Decision, Set<int>> _hashes = {
    for (final d in Decision.values) d: <int>{},
  };

  /// عدد البصمات المخزنة لقرار معيّن.
  int count(Decision decision) => _hashes[decision]!.length;

  /// هل في بصمة مخزنة قريبة من [hash] بهالقرار؟
  bool matches(int hash, Decision decision) {
    final set = _hashes[decision]!;
    if (set.contains(hash)) return true;
    for (final h in set) {
      if (ImageHash.distance(h, hash) <= _maxDistance) return true;
    }
    return false;
  }

  /// يسجّل قرارات جديدة. القرار الأحدث بيغلب: صورة انمسحت بعد ما كانت
  /// "محتفظ فيها" بتنشال من لستة المحتفظ فيها، والعكس.
  Future<void> record(Decision decision, Iterable<int> hashes) async {
    final list = hashes.toList();
    if (list.isEmpty) return;
    final other = decision == Decision.kept ? Decision.deleted : Decision.kept;
    _hashes[decision]!.addAll(list);
    _hashes[other]!.removeAll(list);
    await persist(decision, list);
  }

  /// يمسح كل الذاكرة.
  Future<void> clear() async {
    for (final set in _hashes.values) {
      set.clear();
    }
    await persistClear();
  }

  /// نقطة التخزين الدائم — النسخة الأساسية بالذاكرة بس (للاختبارات).
  Future<void> persist(Decision decision, List<int> hashes) async {}

  Future<void> persistClear() async {}

  void loadInto(Decision decision, Iterable<int> hashes) =>
      _hashes[decision]!.addAll(hashes);
}

/// نسخة دائمة من [DecisionStore] مخزنة بـ SQLite.
class SqfliteDecisionStore extends DecisionStore {
  SqfliteDecisionStore._(this._db);

  final Database _db;

  static const _table = 'decisions';

  static Future<SqfliteDecisionStore> open() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, AppConfig.databaseName),
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE $_table (
          hash INTEGER PRIMARY KEY,
          decision TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      '''),
    );
    final store = SqfliteDecisionStore._(db);
    final rows = await db.query(_table, columns: ['hash', 'decision']);
    for (final row in rows) {
      final decision = Decision.values.asNameMap()[row['decision']];
      if (decision != null) store.loadInto(decision, [row['hash'] as int]);
    }
    return store;
  }

  @override
  Future<void> persist(Decision decision, List<int> hashes) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _db.batch();
    for (final h in hashes) {
      batch.insert(
        _table,
        {'hash': h, 'decision': decision.name, 'created_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> persistClear() => _db.delete(_table);
}
