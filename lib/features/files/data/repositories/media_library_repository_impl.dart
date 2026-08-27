import 'dart:io';

import '../../../../core/errors/failure.dart';
import '../../../../core/types/result.dart';
import '../../../../core/utils/file_utils.dart';
import '../../domain/entities/media_file.dart';
import '../../domain/repositories/media_library_repository.dart';
import '../datasources/media_library_local_datasource.dart';

class MediaLibraryRepositoryImpl implements MediaLibraryRepository {
  const MediaLibraryRepositoryImpl(this._localDataSource);

  final MediaLibraryLocalDataSource _localDataSource;

  @override
  Future<Result<List<MediaFile>>> getAll() async {
    try {
      return Result<List<MediaFile>>.success(await _localDataSource.readAll());
    } catch (error) {
      return Result<List<MediaFile>>.failure(
        CacheFailure(
          message: 'Your files could not be loaded.',
          debugMessage: error.toString(),
        ),
      );
    }
  }

  @override
  Future<Result<MediaFile>> add(MediaFile file) async {
    try {
      return Result<MediaFile>.success(await _localDataSource.insert(file));
    } catch (error) {
      return Result<MediaFile>.failure(
        CacheFailure(
          message: 'This file could not be saved to your library.',
          debugMessage: error.toString(),
        ),
      );
    }
  }

  @override
  Future<Result<MediaFile>> rename(MediaFile file, String newName) async {
    final String? sanitized = FileUtils.sanitizeFileName(newName);
    if (sanitized == null) {
      return const Result<MediaFile>.failure(
        FileFailure(message: 'Please enter a valid file name.'),
      );
    }

    try {
      final File source = File(file.path);
      if (!source.existsSync()) {
        return const Result<MediaFile>.failure(
          FileFailure(message: 'This file no longer exists on your device.'),
        );
      }

      final String extension = FileUtils.extensionOf(file.path);
      final String directory = file.path.substring(
        0,
        file.path.lastIndexOf(Platform.pathSeparator),
      );
      final String targetPath = FileUtils.uniquePath(
        directory: directory,
        baseName: sanitized,
        extension: extension,
      );

      // Rename on disk first: if it fails, the database still matches reality.
      final File renamed = await source.rename(targetPath);

      final MediaFile updated = file.copyWith(
        name: FileUtils.basename(renamed.path),
        path: renamed.path,
      );
      await _localDataSource.updateFile(updated);

      return Result<MediaFile>.success(updated);
    } on FileSystemException catch (error) {
      return Result<MediaFile>.failure(
        FileFailure(
          message: 'This file could not be renamed.',
          debugMessage: error.toString(),
        ),
      );
    } catch (error) {
      return Result<MediaFile>.failure(
        UnknownFailure(debugMessage: error.toString()),
      );
    }
  }

  @override
  Future<Result<void>> delete(MediaFile file) async {
    try {
      final File target = File(file.path);
      if (target.existsSync()) {
        await target.delete();
      }

      // The row is removed even when the file was already gone, so the library
      // never lists something the user cannot open.
      if (file.id case final int id) {
        await _localDataSource.deleteById(id);
      }

      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure(
        FileFailure(
          message: 'This file could not be deleted.',
          debugMessage: error.toString(),
        ),
      );
    }
  }

  @override
  Future<Result<int>> pruneMissing() async {
    try {
      final List<MediaFile> all = await _localDataSource.readAll();
      int removed = 0;

      for (final MediaFile file in all) {
        if (File(file.path).existsSync()) {
          continue;
        }
        if (file.id case final int id) {
          await _localDataSource.deleteById(id);
          removed++;
        }
      }

      return Result<int>.success(removed);
    } catch (error) {
      return Result<int>.failure(CacheFailure(debugMessage: error.toString()));
    }
  }
}
