import 'dart:io';
import 'package:convertly/core/services/noise_model_service.dart';
import 'package:convertly/core/services/output_directory_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hands out a real temporary directory in place of the app's own.
class _TempDirectories implements OutputDirectoryService {
  _TempDirectories(this._temp);

  final Directory _temp;

  @override
  Future<Directory> resolveTemp() async => _temp;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Serves a model-shaped asset, counting how often it is read.
class _FakeBundle extends CachingAssetBundle {
  int loads = 0;
  bool fails = false;

  @override
  Future<ByteData> load(String key) async {
    loads++;
    if (fails) {
      throw const FileSystemException('asset missing');
    }
    final List<int> bytes = <int>[
      ...'${NoiseModelService.header} 1\n'.codeUnits,
      ...List<int>.filled(64, 7),
    ];
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      String.fromCharCodes((await load(key)).buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late _FakeBundle bundle;
  late NoiseModelService service;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('noise_model_test');
    bundle = _FakeBundle();
    service = NoiseModelService(_TempDirectories(temp));
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('the model is written where FFmpeg can open it', () async {
    final String? path = await service.resolvePath(bundle: bundle);

    // FFmpeg's arnndn takes a path, so an asset inside the APK is no use
    // until it has been written out.
    expect(path, isNotNull);
    expect(File(path!).existsSync(), isTrue);
    expect(File(path).readAsStringSync(), startsWith(NoiseModelService.header));
  });

  test(
    'a second clean-up reuses the copy instead of writing it again',
    () async {
      await service.resolvePath(bundle: bundle);
      await service.resolvePath(bundle: bundle);

      expect(bundle.loads, 1);
    },
  );

  test('a half-written copy from an interrupted run is replaced', () async {
    final File stale = File('${temp.path}/${NoiseModelService.fileName}')
      ..writeAsBytesSync(<int>[0, 1, 2]);

    final String? path = await service.resolvePath(bundle: bundle);

    expect(path, stale.path);
    expect(stale.readAsStringSync(), startsWith(NoiseModelService.header));
  });

  test(
    'a model that cannot be written reports null rather than throwing',
    () async {
      bundle.fails = true;

      // The caller turns this into "no AI clean-up" rather than a crash, and
      // the command builder refuses to pass the request off as AI-cleaned.
      expect(await service.resolvePath(bundle: bundle), isNull);
    },
  );
}
