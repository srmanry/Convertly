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
}
