import 'package:get/get.dart';

import '../../../../core/services/output_directory_service.dart';
import '../../../files/domain/repositories/media_library_repository.dart';
import '../../data/repositories/storage_repository_impl.dart';
import '../../domain/repositories/storage_repository.dart';
import '../../domain/usecases/storage_usecases.dart';
import '../controllers/storage_controller.dart';

class StorageBinding extends Bindings {
  @override
  void dependencies() {
    final StorageRepository repository = StorageRepositoryImpl(
      Get.find<MediaLibraryRepository>(),
      Get.find<OutputDirectoryService>(),
    );

    Get.lazyPut<StorageController>(
      () => StorageController(
        GetStorageUsage(repository),
        ClearWorkingFiles(repository),
        ClearConvertedFiles(repository),
      ),
    );
  }
}
