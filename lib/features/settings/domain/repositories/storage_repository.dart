import '../../../../core/types/result.dart';
import '../entities/storage_usage.dart';

/// What the app is keeping on the device, and how to reclaim it.
abstract interface class StorageRepository {
  /// Measures what is currently stored.
  Future<Result<StorageUsage>> readUsage();

  /// Removes leftovers from interrupted conversions. Finished files are kept.
  Future<Result<void>> clearWorkingFiles();

  /// Deletes every converted file and its library entry.
  ///
  /// Returns how many were removed.
  Future<Result<int>> clearConvertedFiles();
}
