import 'dart:io';

import 'package:convertly/features/files/data/datasources/media_library_database.dart';
import 'package:convertly/features/files/data/datasources/media_library_local_datasource.dart';
import 'package:convertly/features/files/data/repositories/media_library_repository_impl.dart';
import 'package:convertly/features/files/domain/entities/media_file.dart';
import 'package:convertly/core/types/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Exercises the real SQLite engine, so persistence is verified rather than
/// assumed.
void main() {
  late Directory tempDir;
  late MediaLibraryDatabase database;
  late MediaLibraryLocalDataSourceImpl dataSource;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('convertly_db_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    database = MediaLibraryDatabase(databaseName: 'test_library.db');
    dataSource = MediaLibraryLocalDataSourceImpl(database);
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Creates a real file on disk plus its library entry.
  Future<MediaFile> insertWithFile(String name) async {
    final File file = File('${tempDir.path}/$name');
    await file.writeAsString('audio-bytes');

    return dataSource.insert(
      MediaFile(
        id: null,
        name: name,
        originalName: 'source.mp4',
        path: file.path,
        type: MediaFileType.audio,
        format: 'MP3',
        sizeInBytes: await file.length(),
        createdAt: DateTime(2026, 8, 26),
        sourceType: MediaSourceType.videoToAudio,
        duration: const Duration(minutes: 4, seconds: 45),
      ),
    );
  }

  test('an inserted row is assigned an id', () async {
    final MediaFile saved = await insertWithFile('one.mp3');

    expect(saved.id, isNotNull);
  });

  test('rows survive closing and reopening the database', () async {
    await insertWithFile('one.mp3');
    await insertWithFile('two.mp3');

    // Closing drops the in-memory handle; reading again must hit real storage.
    await database.close();

    final List<MediaFile> reloaded = await dataSource.readAll();

    expect(reloaded, hasLength(2));
    expect(
      reloaded.map((MediaFile file) => file.name),
      containsAll(<String>['one.mp3', 'two.mp3']),
    );
  });

  test('metadata round-trips through storage unchanged', () async {
    await insertWithFile('one.mp3');
    await database.close();

    final MediaFile loaded = (await dataSource.readAll()).single;

    expect(loaded.format, 'MP3');
    expect(loaded.duration, const Duration(minutes: 4, seconds: 45));
    expect(loaded.type, MediaFileType.audio);
    expect(loaded.sourceType, MediaSourceType.videoToAudio);
    expect(loaded.createdAt, DateTime(2026, 8, 26));
  });

  test('deleting one row leaves the others', () async {
    final MediaFile first = await insertWithFile('one.mp3');
    await insertWithFile('two.mp3');

    await dataSource.deleteById(first.id!);

    final List<MediaFile> remaining = await dataSource.readAll();
    expect(remaining, hasLength(1));
    expect(remaining.single.name, 'two.mp3');
  });

  test('deleteByIds removes a whole selection in one statement', () async {
    final MediaFile a = await insertWithFile('a.mp3');
    final MediaFile b = await insertWithFile('b.mp3');
    await insertWithFile('c.mp3');

    await dataSource.deleteByIds(<int>[a.id!, b.id!]);

    final List<MediaFile> remaining = await dataSource.readAll();
    expect(remaining, hasLength(1));
    expect(remaining.single.name, 'c.mp3');
  });

  test('deleteByIds with an empty list is a no-op', () async {
    await insertWithFile('a.mp3');

    await dataSource.deleteByIds(<int>[]);

    expect(await dataSource.readAll(), hasLength(1));
  });

  group('repository batch delete', () {
    test('removes the files from disk as well as the database', () async {
      final MediaLibraryRepositoryImpl repository = MediaLibraryRepositoryImpl(
        dataSource,
      );
      final MediaFile a = await insertWithFile('a.mp3');
      final MediaFile b = await insertWithFile('b.mp3');
      await insertWithFile('c.mp3');

      final Result<int> result = await repository.deleteMany(<MediaFile>[a, b]);

      expect(result.valueOrNull, 2);
      expect(File(a.path).existsSync(), isFalse);
      expect(File(b.path).existsSync(), isFalse);
      expect(await dataSource.readAll(), hasLength(1));
    });

    test('still clears an entry whose file is already gone', () async {
      final MediaLibraryRepositoryImpl repository = MediaLibraryRepositoryImpl(
        dataSource,
      );
      final MediaFile orphan = await insertWithFile('gone.mp3');
      await File(orphan.path).delete();

      final Result<int> result = await repository.deleteMany(<MediaFile>[
        orphan,
      ]);

      expect(result.valueOrNull, 1);
      expect(await dataSource.readAll(), isEmpty);
    });

    test('an empty selection succeeds without touching storage', () async {
      final MediaLibraryRepositoryImpl repository = MediaLibraryRepositoryImpl(
        dataSource,
      );
      await insertWithFile('a.mp3');

      final Result<int> result = await repository.deleteMany(<MediaFile>[]);

      expect(result.valueOrNull, 0);
      expect(await dataSource.readAll(), hasLength(1));
    });
  });
}
