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

  /// Deletes several files at once.
  ///
  /// Returns how many were actually removed. A file that cannot be deleted
  /// from disk keeps its database row, so the library never hides something
  /// that is still taking up space.
  Future<Result<int>> deleteMany(List<MediaFile> files);

  /// Drops entries whose file no longer exists, e.g. deleted by a file manager.
  Future<Result<int>> pruneMissing();
}
