import 'dart:io';

import 'package:convertly/core/constants/app_constants.dart';
import 'package:convertly/core/services/output_directory_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Stands in for the real plugin, refusing external storage the way every
/// non-Android platform does.
///
/// path_provider throws here rather than returning null, which is what once
/// escaped [OutputDirectoryService.resolve] as an unhandled async error and
/// left the conversion screen spinning forever.
class NoExternalStoragePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  NoExternalStoragePathProvider(this.documentsPath);

  final String documentsPath;
  bool wasAskedForExternalStorage = false;

  @override
  Future<String?> getExternalStoragePath() async {
    wasAskedForExternalStorage = true;
    throw UnsupportedError(
      'getExternalStoragePath is not supported on this platform',
    );
  }

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getTemporaryPath() async => documentsPath;
}

void main() {
  late Directory root;
  late NoExternalStoragePathProvider platform;

  setUp(() {
    root = Directory.systemTemp.createTempSync('convertly_output_test');
    platform = NoExternalStoragePathProvider(root.path);
    PathProviderPlatform.instance = platform;
  });

  tearDown(() => root.deleteSync(recursive: true));

  group('OutputDirectoryService on a platform without external storage', () {
    test('resolves a writable directory instead of throwing', () async {
      final Directory output = await OutputDirectoryService().resolve();

      expect(output.existsSync(), isTrue);
      expect(output.path, startsWith(root.path));
      expect(output.path, endsWith(AppConstants.outputFolderName));
    });

    test('does not ask for external storage off Android', () async {
      // The call itself is the bug: it throws before any fallback can run.
      await OutputDirectoryService().resolve();

      expect(platform.wasAskedForExternalStorage, isFalse);
    });

    test('canWrite reports success rather than surfacing the throw', () async {
      expect(await OutputDirectoryService().canWrite(), isTrue);
    });

    test('resolving twice reuses the same directory', () async {
      final OutputDirectoryService service = OutputDirectoryService();

      expect((await service.resolve()).path, (await service.resolve()).path);
    });
  });

  group('relocated iOS output files', () {
    const String oldRoot =
        '/var/mobile/Containers/Data/Application/OLD/Documents/AudioForge';

    test('a stale container path resolves to the existing output', () async {
      final OutputDirectoryService service = OutputDirectoryService();
      final Directory output = await service.resolve();
      final File current = File('${output.path}/merged_audio.mp3')
        ..writeAsStringSync('audio');
      expect(
        await service.resolveExistingPath('$oldRoot/merged_audio.mp3'),
        current.path,
      );
    });

    test(
      'file URIs and names with Unicode and spaces survive relocation',
      () async {
        final OutputDirectoryService service = OutputDirectoryService();
        final Directory output = await service.resolve();
        const String name = 'Sapna Dance मिस इंडिया.mp3';
        final File current = File('${output.path}/$name')
          ..writeAsStringSync('audio');
        expect(
          await service.resolveExistingPath(
            Uri.file('$oldRoot/$name').toString(),
          ),
          current.path,
        );
      },
    );

    test(
      'a genuinely missing output is not replaced with another file',
      () async {
        final OutputDirectoryService service = OutputDirectoryService();
        expect(
          await service.resolveExistingPath('$oldRoot/gone.mp3'),
          '$oldRoot/gone.mp3',
        );
      },
    );

    test('device URIs and unrelated file paths stay unchanged', () async {
      final OutputDirectoryService service = OutputDirectoryService();
      final Directory output = await service.resolve();
      File('${output.path}/song.mp3').writeAsStringSync('different song');
      for (final String path in <String>[
        'content://media/external/audio/media/1',
        'https://example.com/song.mp3',
        '/other/Music/song.mp3',
      ]) {
        expect(await service.resolveExistingPath(path), path);
      }
    });
  });
}
