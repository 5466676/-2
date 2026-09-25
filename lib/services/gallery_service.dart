import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:photo_manager/photo_manager.dart';

import '../config.dart';
import 'scan_pipeline.dart';

/// صورة من المعرض.
class GalleryImage implements ScanCandidate {
  GalleryImage(this.asset);

  final AssetEntity asset;
  Uint8List? _thumb;

  @override
  String get id => asset.id;

  DateTime get createdAt => asset.createDateTime;

  @override
  Future<Uint8List?> thumbnailBytes() async => _thumb ??=
      await asset.thumbnailDataWithSize(
        const ThumbnailSize.square(AppConfig.thumbnailSize),
        quality: 90,
      );

  @override
  Future<String?> filePath() async => (await asset.file)?.path;

  Future<File?> file() => asset.file;
}

/// الوصول لصور الواتساب عبر photo_manager + الحذف.
class GalleryService {
  /// يطلب صلاحية الصور. يرجع true إذا في وصول (كامل أو محدود).
  Future<bool> requestPermission() async {
    final state = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
      ),
    );
    return state.hasAccess;
  }

  Future<void> openSettings() => PhotoManager.openSetting();

  /// كل صور مجلدات الواتساب المضافة بالشهر المحدد، الأحدث أولًا.
  Future<List<GalleryImage>> imagesForMonth(int year, int month) async {
    final filter = FilterOptionGroup(
      createTimeCond: DateTimeCond(
        min: DateTime(year, month),
        max: DateTime(year, month + 1).subtract(const Duration(milliseconds: 1)),
      ),
      orders: const [OrderOption(type: OrderOptionType.createDate)],
    );
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: false,
      filterOption: filter,
    );
    final whatsapp = paths.where(
      (p) => AppConfig.whatsappAlbumNames.contains(p.name),
    );

    final result = <GalleryImage>[];
    final seen = <String>{};
    for (final path in whatsapp) {
      final count = await path.assetCountAsync;
      for (var page = 0; page * AppConfig.galleryPageSize < count; page++) {
        final assets = await path.getAssetListPaged(
          page: page,
          size: AppConfig.galleryPageSize,
        );
        for (final a in assets) {
          if (seen.add(a.id)) result.add(GalleryImage(a));
        }
      }
    }
    return result;
  }

  /// يحذف الصور. من أندرويد 11 وطالع بتروح عالمهملات (قابلة للاسترجاع)
  /// والنظام بيطلب تأكيد وحدة للدفعة كلها. يرجع معرّفات اللي انحذفت
  /// فعلًا (فاضية إذا المستخدم لغى).
  Future<List<String>> delete(List<GalleryImage> images) async {
    if (images.isEmpty) return const [];
    if (Platform.isAndroid && await _androidSdk() >= 30) {
      return PhotoManager.editor.android.moveToTrash(
        images.map((e) => e.asset).toList(),
      );
    }
    return PhotoManager.editor.deleteWithIds(images.map((e) => e.id).toList());
  }

  int? _sdk;

  Future<int> _androidSdk() async =>
      _sdk ??= (await DeviceInfoPlugin().androidInfo).version.sdkInt;
}
