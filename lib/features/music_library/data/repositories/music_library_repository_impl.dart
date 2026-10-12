import '../../../../core/errors/failure.dart';
import '../../../../core/types/result.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../files/domain/entities/media_file.dart';
import '../../../files/domain/repositories/media_library_repository.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_library_repository.dart';
import '../datasources/device_audio_datasource.dart';
import '../../../../core/i18n/translation_keys.dart';

class MusicLibraryRepositoryImpl implements MusicLibraryRepository {
  const MusicLibraryRepositoryImpl(this._device, this._appFiles);

  final DeviceAudioDataSource _device;
  final MediaLibraryRepository _appFiles;

  Future<Result<MediaFile>> _appFile(Song song) async {
    final Result<List<MediaFile>> files = await _appFiles.getAll();
    return files.fold(Result<MediaFile>.failure, (List<MediaFile> files) {
      for (final MediaFile file in files) {
        if (_toSong(file).id == song.id) return Result<MediaFile>.success(file);
      }
      return const Result<MediaFile>.failure(
        FileFailure(messageKey: K.errorFileGone),
      );
    });
  }

  @override
  Future<Result<Song?>> renameSong(Song song, String newName) async {
    final String? name = FileUtils.sanitizeFileName(newName);
    if (name == null) {
      return const Result<Song?>.failure(
        FileFailure(messageKey: K.errorInvalidFileName),
      );
    }
    if (name ==
        FileUtils.baseNameWithoutExtension(song.fileName ?? song.title)) {
      return Result<Song?>.success(song);
    }
    try {
      if (song.source == SongSource.app) {
        final Result<MediaFile> file = await _appFile(song);
        if (file.failureOrNull case final Failure failure) {
          return Result<Song?>.failure(failure);
        }
        final Result<MediaFile> renamed = await _appFiles.rename(
          file.valueOrNull!,
          name,
        );
        return renamed.fold<Result<Song?>>(
          Result<Song?>.failure,
          (MediaFile value) => Result<Song?>.success(_toSong(value)),
        );
      }
      if (!await _device.renameSong(song.path, name)) {
        return const Result<Song?>.success(null);
      }
      final List<Song> songs = await _device.readSongs();
      for (final Song updated in songs) {
        if (updated.id == song.id) return Result<Song?>.success(updated);
      }
      return const Result<Song?>.failure(
        FileFailure(messageKey: K.errorFileGone),
      );
    } catch (error) {
      return Result<Song?>.failure(
        FileFailure(
          messageKey: K.errorFileNotRenamed,
          debugMessage: error.toString(),
        ),
      );
    }
  }

  @override
  Future<Result<bool>> deleteSong(Song song) async {
    try {
      if (song.source == SongSource.phone) {
        return Result<bool>.success(await _device.deleteSong(song.path));
      }
      final Result<MediaFile> file = await _appFile(song);
      if (file.failureOrNull case final Failure failure) {
        return Result<bool>.failure(failure);
      }
      final Result<void> deleted = await _appFiles.delete(file.valueOrNull!);
      return deleted.fold<Result<bool>>(
        Result<bool>.failure,
        (_) => const Result<bool>.success(true),
      );
    } catch (error) {
      return Result<bool>.failure(
        FileFailure(
          messageKey: K.errorFileNotDeleted,
          debugMessage: error.toString(),
        ),
      );
    }
  }

  @override
  Future<bool> hasDevicePermission() async {
    try {
      return await _device.hasPermission();
    } catch (error) {
      // A platform that cannot answer is treated as "not granted"; the player
      // then offers to ask rather than pretending it already has access.
      return false;
    }
  }

  @override
  Future<bool> requestDevicePermission() async {
    try {
      return await _device.requestPermission();
    } catch (error) {
      return false;
    }
  }

  @override
  Future<Result<List<Song>>> deviceSongs() async {
    try {
      return Result<List<Song>>.success(await _device.readSongs());
    } catch (error) {
      return Result<List<Song>>.failure(
        FileFailure(
          messageKey: K.errorMusicNotRead,
          debugMessage: error.toString(),
        ),
      );
    }
  }

  @override
  Future<Result<List<Song>>> appSongs() async {
    final Result<List<MediaFile>> stored = await _appFiles.getAll();

    return stored.fold(Result<List<Song>>.failure, (List<MediaFile> files) {
      return Result<List<Song>>.success(<Song>[
        for (final MediaFile file in files)
          if (file.type == MediaFileType.audio) _toSong(file),
      ]);
    });
  }

  static Song _toSong(MediaFile file) {
    return Song(
      id: 'app:${file.id ?? file.path}',
      title: file.name,
      path: file.path,
      source: SongSource.app,
      duration: file.duration,
      sizeInBytes: file.sizeInBytes,
      fileName: file.name,
      format: file.format.toUpperCase(),
      createdAt: file.createdAt,
    );
  }
}
