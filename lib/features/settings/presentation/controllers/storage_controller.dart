import 'package:get/get.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/types/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/storage_usage.dart';
import '../../domain/usecases/storage_usecases.dart';

/// Drives the storage screen.
class StorageController extends GetxController {
  StorageController(
    this._getUsage,
    this._clearWorkingFiles,
    this._clearConvertedFiles,
  );

  final GetStorageUsage _getUsage;
  final ClearWorkingFiles _clearWorkingFiles;
  final ClearConvertedFiles _clearConvertedFiles;

  final Rx<StorageUsage> usage = StorageUsage.empty.obs;
  final RxBool isLoading = false.obs;
  final RxBool isClearing = false.obs;
  final RxString errorMessage = ''.obs;

  /// Set after a clear, so the screen can say what was freed.
  final RxString statusMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    refreshUsage();
  }

  /// Re-measures what is on disk.
  ///
  /// Called whenever the screen is shown as well as after a clear, so figures
  /// reflect files deleted elsewhere in the app rather than a stale total.
  Future<void> refreshUsage() async {
    isLoading.value = true;
    errorMessage.value = '';

    final Result<StorageUsage> result = await _getUsage(const NoParams());
    result.fold(
      (Failure failure) => errorMessage.value = failure.message,
      (StorageUsage value) => usage.value = value,
    );

    isLoading.value = false;
  }

  /// Removes leftovers from interrupted conversions.
  Future<void> clearWorkingFiles() async {
    if (isClearing.value) {
      return;
    }
    final int before = usage.value.workingBytes;
    await _clear(() => _clearWorkingFiles(const NoParams()), (
      StorageUsage after,
    ) {
      final int freed = before - after.workingBytes;
      return freed > 0
          ? 'Working files removed.'
          : 'There were no working files to remove.';
    });
  }

  /// Deletes every converted file the app is keeping.
  Future<void> clearConvertedFiles() async {
    if (isClearing.value) {
      return;
    }
    await _clear(() => _clearConvertedFiles(const NoParams()), (
      StorageUsage after,
    ) {
      return after.convertedCount == 0
          ? 'All converted files deleted.'
          : 'Some files could not be deleted and were kept.';
    });
  }

  /// Runs [action], then re-measures so the figures shown are the real ones
  /// rather than an assumption about what the action freed.
  Future<void> _clear(
    Future<Result<Object?>> Function() action,
    String Function(StorageUsage after) describe,
  ) async {
    isClearing.value = true;
    errorMessage.value = '';
    statusMessage.value = '';

    final Result<Object?> result = await action();

    await result.fold(
      (Failure failure) async {
        errorMessage.value = failure.message;
      },
      (_) async {
        await refreshUsage();
        statusMessage.value = describe(usage.value);
      },
    );

    isClearing.value = false;
  }
}
