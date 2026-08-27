import 'package:get/get.dart';

import '../../../files/domain/repositories/media_library_repository.dart';
import '../../../files/domain/usecases/media_library_usecases.dart';
import '../../../files/presentation/controllers/files_controller.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../../../../core/services/share_service.dart';
import '../controllers/shell_controller.dart';

/// Registers the controllers the shell and its tabs need.
///
/// [SettingsController] is intentionally absent: it is registered permanently
/// at bootstrap because the theme depends on it.
class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ShellController>(ShellController.new);

    final MediaLibraryRepository repository =
        Get.find<MediaLibraryRepository>();

    Get.lazyPut<HomeController>(
      () => HomeController(GetMediaFiles(repository)),
    );
    Get.lazyPut<FilesController>(
      () => FilesController(
        GetMediaFiles(repository),
        RenameMediaFile(repository),
        DeleteMediaFile(repository),
        DeleteMediaFiles(repository),
        PruneMissingMediaFiles(repository),
        Get.find<ShareService>(),
      ),
    );
  }
}
