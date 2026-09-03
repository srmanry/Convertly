import '../../../../core/errors/failure.dart';
import '../../../../core/types/result.dart';
import '../../../files/domain/entities/media_file.dart';
import '../../../files/domain/repositories/media_library_repository.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_library_repository.dart';
import '../datasources/device_audio_datasource.dart';

class MusicLibraryRepositoryImpl implements MusicLibraryRepository {
  const MusicLibraryRepositoryImpl(this._device, this._appFiles);

  final DeviceAudioDataSource _device;
  final MediaLibraryRepository _appFiles;

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
          message: 'Could not read the music on this device.',
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
    );
  }
}
