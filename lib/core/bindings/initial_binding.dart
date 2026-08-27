import 'package:get/get.dart';

import '../../features/files/data/datasources/media_library_database.dart';
import '../../features/files/data/datasources/media_library_local_datasource.dart';
import '../../features/files/data/repositories/media_library_repository_impl.dart';
import '../../features/files/domain/repositories/media_library_repository.dart';
import '../../features/settings/data/datasources/settings_local_datasource.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/settings/domain/usecases/get_settings.dart';
import '../../features/settings/domain/usecases/save_settings.dart';
import '../../features/settings/presentation/controllers/settings_controller.dart';
import '../services/ffmpeg_service.dart';
import '../services/output_directory_service.dart';
import '../services/share_service.dart';
import '../services/storage_service.dart';

/// Registers dependencies that must live for the whole app session.
///
/// Everything route-scoped belongs in that route's own binding instead.
class InitialBinding extends Bindings {
  InitialBinding(this._storage);

  final StorageService _storage;

  @override
  void dependencies() {
    Get.put<StorageService>(_storage, permanent: true);
    Get.put<FfmpegService>(FfmpegService(), permanent: true);
    Get.put<OutputDirectoryService>(OutputDirectoryService(), permanent: true);
    Get.put<ShareService>(ShareService(), permanent: true);
    Get.put<MediaLibraryDatabase>(MediaLibraryDatabase(), permanent: true);

    final SettingsRepository settingsRepository = SettingsRepositoryImpl(
      SettingsLocalDataSourceImpl(_storage),
    );
    Get.put<SettingsRepository>(settingsRepository, permanent: true);

    final MediaLibraryRepository mediaLibraryRepository =
        MediaLibraryRepositoryImpl(
          MediaLibraryLocalDataSourceImpl(Get.find<MediaLibraryDatabase>()),
        );
    Get.put<MediaLibraryRepository>(mediaLibraryRepository, permanent: true);

    Get.put<SettingsController>(
      SettingsController(
        GetSettings(settingsRepository),
        SaveSettings(settingsRepository),
      ),
      permanent: true,
    );
  }
}
