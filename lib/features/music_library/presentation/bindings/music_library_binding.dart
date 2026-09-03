import 'package:get/get.dart';

import '../../../files/domain/repositories/media_library_repository.dart';
import '../../data/datasources/device_audio_datasource.dart';
import '../../data/repositories/music_library_repository_impl.dart';
import '../../domain/repositories/music_library_repository.dart';
import '../../domain/usecases/music_library_usecases.dart';
import '../controllers/music_library_controller.dart';

/// Wires the player tab. Registered by the shell, since the tab is built with
/// it rather than reached through a route of its own.
abstract final class MusicLibraryBinding {
  static void register() {
    if (Get.isRegistered<MusicLibraryController>()) {
      return;
    }

    final MusicLibraryRepository repository = MusicLibraryRepositoryImpl(
      DeviceAudioDataSourceImpl(),
      Get.find<MediaLibraryRepository>(),
    );

    Get.lazyPut<MusicLibraryController>(
      () => MusicLibraryController(
        GetDeviceSongs(repository),
        GetAppSongs(repository),
        EnsureDevicePermission(repository),
      ),
    );
  }
}
