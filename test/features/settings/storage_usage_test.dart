import 'dart:io';

import 'package:convertly/core/services/output_directory_service.dart';
import 'package:convertly/core/types/result.dart';
import 'package:convertly/features/files/data/datasources/media_library_database.dart';
import 'package:convertly/features/files/data/datasources/media_library_local_datasource.dart';
import 'package:convertly/features/files/data/repositories/media_library_repository_impl.dart';
import 'package:convertly/features/files/domain/entities/media_file.dart';
import 'package:convertly/features/files/domain/repositories/media_library_repository.dart';
import 'package:convertly/features/settings/data/repositories/storage_repository_impl.dart';
import 'package:convertly/features/settings/domain/entities/storage_usage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Points the app's directories at a scratch folder for the test.
class TestPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  TestPathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}

/// Measures against real files on disk rather than a mock, so the figures the
/// screen shows are the ones the device would report.
void main() {
  late Directory tempDir;
  late MediaLibraryDatabase database;
  late MediaLibraryRepository library;
  late OutputDirectoryService directories;
  late StorageRepositoryImpl storage;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('convertly_storage_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
    PathProviderPlatform.instance = TestPathProvider(tempDir.path);

    database = MediaLibraryDatabase(databaseName: 'storage_test.db');
    library = MediaLibraryRepositoryImpl(
      MediaLibraryLocalDataSourceImpl(database),
    );
    directories = OutputDirectoryService();
    storage = StorageRepositoryImpl(library, directories);
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Writes a real file of [bytes] bytes and records it in the library.
  Future<MediaFile> addFile(
    String name, {
    required int bytes,
    String format = 'MP3',
  }) async {
    final File file = File('${tempDir.path}/$name');
    await file.writeAsBytes(List<int>.filled(bytes, 0));

    final Result<MediaFile> added = await library.add(
      MediaFile(
        id: null,
        name: name,
        originalName: name,
        path: file.path,
        type: MediaFileType.audio,
        format: format,
        sizeInBytes: bytes,
        createdAt: DateTime.now(),
        sourceType: MediaSourceType.audioConvert,
      ),
    );
    return added.valueOrNull!;
  }

  Future<StorageUsage> readUsage() async =>
      (await storage.readUsage()).valueOrNull!;

  group('storage usage', () {
    test('reports nothing when the app holds no files', () async {
      final StorageUsage usage = await readUsage();

      expect(usage.convertedBytes, 0);
      expect(usage.convertedCount, 0);
      expect(usage.isEmpty, isTrue);
    });

    test('adds up what the saved files actually take', () async {
      await addFile('a.mp3', bytes: 3000);
      await addFile('b.mp3', bytes: 5000);

      final StorageUsage usage = await readUsage();

      expect(usage.convertedBytes, 8000);
      expect(usage.convertedCount, 2);
    });

    test('deleting a file frees its space', () async {
      final MediaFile keep = await addFile('a.mp3', bytes: 3000);
      final MediaFile remove = await addFile('b.mp3', bytes: 5000);

      await library.delete(remove);
      final StorageUsage usage = await readUsage();

      // This is the whole point of the screen: what is gone stops counting.
      expect(usage.convertedBytes, 3000);
      expect(usage.convertedCount, 1);
      expect(File(keep.path).existsSync(), isTrue);
    });

    test('measures the file on disk, not the size recorded for it', () async {
      final MediaFile file = await addFile('a.mp3', bytes: 4000);
      // A file replaced outside the app must not keep reporting its old size.
      await File(file.path).writeAsBytes(List<int>.filled(1000, 0));

      expect((await readUsage()).convertedBytes, 1000);
    });

    test(
      'an entry whose file is gone counts as missing, not as space',
      () async {
        final MediaFile file = await addFile('a.mp3', bytes: 4000);
        await File(file.path).delete();

        final StorageUsage usage = await readUsage();

        expect(usage.convertedBytes, 0);
        expect(usage.convertedCount, 0);
        expect(usage.missingCount, 1);
      },
    );

    test('splits the total by output format, largest first', () async {
      await addFile('a.mp3', bytes: 1000, format: 'MP3');
      await addFile('b.wav', bytes: 9000, format: 'WAV');
      await addFile('c.mp3', bytes: 2000, format: 'MP3');

      final List<StorageGroup> groups = (await readUsage()).byFormat;

      expect(groups.map((StorageGroup g) => g.label), <String>['WAV', 'MP3']);
      expect(groups.first.bytes, 9000);
      expect(groups.last.bytes, 3000);
      expect(groups.last.fileCount, 2);
    });

    test('reports where files are saved', () async {
      expect((await readUsage()).outputPath, isNotEmpty);
    });
  });

  group('reclaiming space', () {
    test('clearing removes every converted file from the device', () async {
      final MediaFile first = await addFile('a.mp3', bytes: 3000);
      await addFile('b.mp3', bytes: 5000);

      final Result<int> cleared = await storage.clearConvertedFiles();

      expect(cleared.valueOrNull, 2);
      expect(File(first.path).existsSync(), isFalse);

      final StorageUsage usage = await readUsage();
      expect(usage.convertedBytes, 0);
      expect(usage.convertedCount, 0);
    });

    test('clearing an empty library succeeds without complaint', () async {
      expect((await storage.clearConvertedFiles()).valueOrNull, 0);
    });

    test('working files are counted and can be removed', () async {
      final Directory working = await directories.resolveTemp();
      await File(
        '${working.path}/leftover.tmp',
      ).writeAsBytes(List<int>.filled(2500, 0));

      expect((await readUsage()).workingBytes, 2500);

      await storage.clearWorkingFiles();

      expect((await readUsage()).workingBytes, 0);
    });

    test('removing working files leaves converted files alone', () async {
      final MediaFile kept = await addFile('a.mp3', bytes: 3000);
      final Directory working = await directories.resolveTemp();
      await File(
        '${working.path}/leftover.tmp',
      ).writeAsBytes(List<int>.filled(2500, 0));

      await storage.clearWorkingFiles();

      expect(File(kept.path).existsSync(), isTrue);
      expect((await readUsage()).convertedBytes, 3000);
    });

    test('the total covers both finished and working files', () async {
      await addFile('a.mp3', bytes: 3000);
      final Directory working = await directories.resolveTemp();
      await File(
        '${working.path}/leftover.tmp',
      ).writeAsBytes(List<int>.filled(500, 0));

      expect((await readUsage()).totalBytes, 3500);
    });
  });
}
