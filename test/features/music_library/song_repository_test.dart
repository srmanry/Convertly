import 'dart:io';

import 'package:convertly/features/files/data/datasources/media_library_database.dart';
import 'package:convertly/features/files/data/datasources/media_library_local_datasource.dart';
import 'package:convertly/features/files/data/repositories/media_library_repository_impl.dart';
import 'package:convertly/features/files/domain/entities/media_file.dart';
import 'package:convertly/features/music_library/data/datasources/device_audio_datasource.dart';
import 'package:convertly/features/music_library/data/repositories/music_library_repository_impl.dart';
import 'package:convertly/features/music_library/domain/entities/song.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Device implements DeviceAudioDataSource {
  bool allowEdit = true;
  String? renamedUri;
  String? deletedUri;
  List<Song> songs = <Song>[];
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<List<Song>> readSongs() async => songs;
  @override
  Future<bool> renameSong(String uri, String newName) async {
    renamedUri = uri;
    return allowEdit;
  }

  @override
  Future<bool> deleteSong(String uri) async {
    deletedUri = uri;
    return allowEdit;
  }
}

void main() {
  late Directory directory;
  late MediaLibraryDatabase database;
  late MediaLibraryLocalDataSourceImpl local;
  late MusicLibraryRepositoryImpl repository;
  late _Device device;
  final DateTime created = DateTime(2026, 10, 12, 10, 30);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('audioforge_song_test');
    await databaseFactory.setDatabasesPath(directory.path);
    database = MediaLibraryDatabase(databaseName: 'songs.db');
    local = MediaLibraryLocalDataSourceImpl(database);
    device = _Device();
    repository = MusicLibraryRepositoryImpl(
      device,
      MediaLibraryRepositoryImpl(local),
    );
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  Future<Song> addSong(String name) async {
    final File file = File('${directory.path}/$name');
    await file.writeAsString('original audio bytes');
    await local.insert(
      MediaFile(
        id: null,
        name: name,
        originalName: 'original.mp4',
        path: file.path,
        type: MediaFileType.audio,
        format: 'mp3',
        sizeInBytes: await file.length(),
        createdAt: created,
        sourceType: MediaSourceType.videoToAudio,
        duration: const Duration(seconds: 33),
      ),
    );
    return (await repository.appSongs()).valueOrNull!.firstWhere(
      (Song value) => value.title == name,
    );
  }

  test(
    'rename updates the disk and database while keeping the date and song identity',
    () async {
      final Song original = await addSong('original.mp3');
      final Song renamed = (await repository.renameSong(
        original,
        'Renamed',
      )).valueOrNull!;
      expect(renamed.id, original.id);
      expect(renamed.title, 'Renamed.mp3');
      expect(renamed.format, 'MP3');
      expect(renamed.createdAt, created);
      expect(await File(original.path).exists(), isFalse);
      expect(await File(renamed.path).readAsString(), 'original audio bytes');
      final MediaFile stored = (await local.readAll()).single;
      expect(stored.path, renamed.path);
      expect(stored.createdAt, created);
      expect(stored.originalName, 'original.mp4');
    },
  );

  test(
    'rename avoids overwriting another track and a no-op keeps the path',
    () async {
      final Song original = await addSong('original.mp3');
      await addSong('Taken.mp3');
      expect(
        (await repository.renameSong(original, 'original')).valueOrNull!.path,
        original.path,
      );
      final Song renamed = (await repository.renameSong(
        original,
        'Taken',
      )).valueOrNull!;
      expect(renamed.fileName, 'Taken_1.mp3');
      expect(await File('${directory.path}/Taken.mp3').exists(), isTrue);
      expect((await local.readAll()), hasLength(2));
    },
  );

  test('delete removes the file and its database entry', () async {
    final Song original = await addSong('original.mp3');
    expect((await repository.deleteSong(original)).valueOrNull, isTrue);
    expect(await File(original.path).exists(), isFalse);
    expect(await local.readAll(), isEmpty);
  });

  test('invalid rename leaves the original file intact', () async {
    final Song original = await addSong('original.mp3');
    expect((await repository.renameSong(original, ' /// ')).isFailure, isTrue);
    expect(await File(original.path).exists(), isTrue);
    expect((await local.readAll()).single.name, 'original.mp3');
  });

  test(
    'phone edits use the content URI and cancellation does not fake a change',
    () async {
      const Song original = Song(
        id: 'device:42',
        title: 'Original',
        path: 'content://media/external/audio/media/42',
        source: SongSource.phone,
      );
      device.allowEdit = false;
      expect(
        (await repository.renameSong(original, 'Renamed')).valueOrNull,
        isNull,
      );
      expect((await repository.deleteSong(original)).valueOrNull, isFalse);
      expect(device.renamedUri, original.path);
      expect(device.deletedUri, original.path);
      device
        ..allowEdit = true
        ..songs = <Song>[
          Song(
            id: original.id,
            title: 'Renamed',
            path: original.path,
            source: SongSource.phone,
          ),
        ];
      expect(
        (await repository.renameSong(original, 'Renamed')).valueOrNull!.title,
        'Renamed',
      );
    },
  );

  test(
    'phone details use the index date and filename, without inventing a creation date',
    () {
      final Song indexed = DeviceAudioDataSourceImpl.fromRow(<Object?, Object?>{
        'id': 42,
        'uri': 'content://media/external/audio/media/42',
        'title': 'Song',
        'displayName': 'Song.mp3',
        'dateAddedMs': created.millisecondsSinceEpoch,
      });
      expect(indexed.createdAt, created);
      expect(indexed.fileName, 'Song.mp3');
      expect(indexed.format, 'MP3');
      expect(
        DeviceAudioDataSourceImpl.fromRow(<Object?, Object?>{
          'id': 1,
        }).createdAt,
        isNull,
      );
    },
  );
}
