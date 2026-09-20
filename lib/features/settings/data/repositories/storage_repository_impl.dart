import 'dart:io';

import '../../../../core/errors/failure.dart';
import '../../../../core/services/output_directory_service.dart';
import '../../../../core/types/result.dart';
import '../../../files/domain/entities/media_file.dart';
import '../../../files/domain/repositories/media_library_repository.dart';
import '../../domain/entities/storage_usage.dart';
import '../../domain/repositories/storage_repository.dart';
import '../../../../core/i18n/translation_keys.dart';

class StorageRepositoryImpl implements StorageRepository {
  const StorageRepositoryImpl(this._library, this._directories);

  final MediaLibraryRepository _library;
  final OutputDirectoryService _directories;

  @override
  Future<Result<StorageUsage>> readUsage() async {
    try {
      final Result<List<MediaFile>> stored = await _library.getAll();
      final List<MediaFile>? files = stored.valueOrNull;
      if (files == null) {
        return const Result<StorageUsage>.failure(
          CacheFailure(messageKey: K.errorStorageNotRead),
        );
      }

      int convertedBytes = 0;
      int convertedCount = 0;
      int missingCount = 0;
      final Map<String, StorageGroup> byFormat = <String, StorageGroup>{};

      for (final MediaFile file in files) {
        // Measured from disk rather than from the size recorded when the file
        // was made: a file removed outside the app must not keep counting.
        final int size = await _sizeOf(file.path);
        if (size < 0) {
          missingCount++;
          continue;
        }

        convertedBytes += size;
        convertedCount++;

        final String label = file.format.toUpperCase();
        final StorageGroup? existing = byFormat[label];
        byFormat[label] = StorageGroup(
          label: label,
          bytes: (existing?.bytes ?? 0) + size,
          fileCount: (existing?.fileCount ?? 0) + 1,
        );
      }

      final List<StorageGroup> groups = byFormat.values.toList()
        ..sort((StorageGroup a, StorageGroup b) => b.bytes.compareTo(a.bytes));

      return Result<StorageUsage>.success(
        StorageUsage(
          convertedBytes: convertedBytes,
          convertedCount: convertedCount,
          workingBytes: await _workingBytes(),
          missingCount: missingCount,
          byFormat: groups,
          outputPath: (await _directories.resolve()).path,
        ),
      );
    } catch (error) {
      return Result<StorageUsage>.failure(
        StorageFailure(
          messageKey: K.errorStorageNotRead,
          debugMessage: error.toString(),
        ),
      );
    }
  }

  @override
  Future<Result<void>> clearWorkingFiles() async {
    try {
      await _directories.clearTemp();
      return const Result<void>.success(null);
    } catch (error) {
      return Result<void>.failure(
        StorageFailure(
          messageKey: K.errorWorkingNotRemoved,
          debugMessage: error.toString(),
        ),
      );
    }
  }

  @override
  Future<Result<int>> clearConvertedFiles() async {
    final Result<List<MediaFile>> stored = await _library.getAll();
    final List<MediaFile>? files = stored.valueOrNull;
    if (files == null) {
      return const Result<int>.failure(
        CacheFailure(messageKey: K.errorStorageNotRead),
      );
    }
    if (files.isEmpty) {
      return const Result<int>.success(0);
    }
    // deleteMany removes the files from disk as well as their entries, and
    // reports how many actually went.
    return _library.deleteMany(files);
  }

  /// Size of [path] in bytes, or -1 when the file is no longer there.
  Future<int> _sizeOf(String path) async {
    try {
      final File file = File(path);
      return file.existsSync() ? await file.length() : -1;
    } on FileSystemException {
      return -1;
    }
  }

  /// Room taken by the scratch directory, which holds only leftovers.
  Future<int> _workingBytes() async {
    try {
      final Directory temp = await _directories.resolveTemp();
      if (!temp.existsSync()) {
        return 0;
      }
      int total = 0;
      await for (final FileSystemEntity entity in temp.list(recursive: true)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } on FileSystemException {
      // An unreadable scratch directory is not worth failing the whole screen
      // for; it is reported as empty and the rest of the figures still show.
      return 0;
    }
  }
}
