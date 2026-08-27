import '../../../../core/types/result.dart';
import '../entities/media_file.dart';

/// The local library of converted files.
abstract interface class MediaLibraryRepository {
  /// All tracked files, newest first.
  Future<Result<List<MediaFile>>> getAll();

  /// Records a newly converted file.
  Future<Result<MediaFile>> add(MediaFile file);

  /// Renames both the entry and the file on disk.
  Future<Result<MediaFile>> rename(MediaFile file, String newName);

  /// Deletes the entry and the file on disk.
  Future<Result<void>> delete(MediaFile file);

  /// Drops entries whose file no longer exists, e.g. deleted by a file manager.
  Future<Result<int>> pruneMissing();
}
