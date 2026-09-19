import 'dart:async';

import 'package:convertly/core/enums/tool_mode.dart';
import 'package:convertly/core/services/ffmpeg_service.dart';
import 'package:convertly/core/services/output_directory_service.dart';
import 'package:convertly/core/services/waveform_service.dart';
import 'package:convertly/features/converter/domain/entities/media_info.dart';
import 'package:convertly/features/converter/domain/usecases/convert_media.dart';
import 'package:convertly/features/converter/domain/usecases/pick_media.dart';
import 'package:convertly/features/converter/presentation/controllers/converter_controller.dart';
import 'package:convertly/features/converter/presentation/controllers/trim_waveform_controller.dart';
import 'package:convertly/features/files/domain/usecases/media_library_usecases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'mixer_controller_test.dart' as harness;

/// Lets a test decide when each decode finishes, so a second file can be
/// picked while the first is still in flight.
class _QueuedWaveforms extends WaveformService {
  _QueuedWaveforms() : super(FfmpegService(), OutputDirectoryService());

  final Map<String, Completer<List<double>?>> pending =
      <String, Completer<List<double>?>>{};
  final List<String> requested = <String>[];

  @override
  Future<List<double>?> peaksFor(String source) {
    requested.add(source);
    return (pending[source] ??= Completer<List<double>?>()).future;
  }

  void finish(String source, List<double>? peaks) =>
      (pending[source] ??= Completer<List<double>?>()).complete(peaks);
}

void main() {
  late harness.FakeMediaRepository media;
  late _QueuedWaveforms waveforms;
  late ConverterController converter;
  late TrimWaveformController controller;

  setUp(() {
    media = harness.FakeMediaRepository();
    waveforms = _QueuedWaveforms();

    converter = ConverterController(
      ToolMode.cut,
      PickVideo(media),
      PickAudio(media),
      PickAudioFiles(media),
      ConvertMedia(harness.UnusedConversionRepository()),
      CancelConversion(harness.UnusedConversionRepository()),
      AddMediaFile(harness.UnusedLibraryRepository()),
      OutputDirectoryService(),
      GetMediaFiles(harness.UnusedLibraryRepository()),
      InspectMedia(media),
    );
    Get.put<ConverterController>(converter);

    controller = TrimWaveformController(waveforms);
    Get.put<TrimWaveformController>(controller);
  });

  tearDown(Get.reset);

  MediaInfo song(String name) =>
      harness.track(name, duration: const Duration(minutes: 3));

  test('starts with nothing to draw', () {
    expect(controller.peaks.value, isEmpty);
    expect(controller.isLoading.value, isFalse);
  });

  test('decodes the picked file and holds its peaks', () async {
    final MediaInfo first = song('one');

    final Future<void> loading = controller.load(first);
    expect(controller.isLoading.value, isTrue);

    waveforms.finish(first.path, <double>[0.1, 0.9]);
    await loading;

    expect(controller.peaks.value, <double>[0.1, 0.9]);
    expect(controller.isLoading.value, isFalse);
  });

  test('the same file is not decoded twice', () async {
    final MediaInfo first = song('one');

    final Future<void> loading = controller.load(first);
    waveforms.finish(first.path, <double>[0.5]);
    await loading;

    await controller.load(first);

    expect(waveforms.requested, <String>[first.path]);
  });

  test('a decode that lands after the file changed is discarded', () async {
    final MediaInfo first = song('one');
    final MediaInfo second = song('two');

    final Future<void> firstLoad = controller.load(first);
    final Future<void> secondLoad = controller.load(second);

    // The slow first decode finishes last, after the user has moved on.
    waveforms.finish(second.path, <double>[0.2, 0.2]);
    await secondLoad;
    waveforms.finish(first.path, <double>[0.9, 0.9, 0.9]);
    await firstLoad;

    expect(controller.peaks.value, <double>[
      0.2,
      0.2,
    ], reason: 'the abandoned file must not overwrite the current waveform');
  });

  test(
    'a file that cannot be decoded leaves no waveform, and no error',
    () async {
      final MediaInfo first = song('one');

      final Future<void> loading = controller.load(first);
      waveforms.finish(first.path, null);
      await loading;

      expect(controller.peaks.value, isEmpty);
      expect(controller.isLoading.value, isFalse);
    },
  );

  test('clearing the source clears the waveform', () async {
    final MediaInfo first = song('one');

    final Future<void> loading = controller.load(first);
    waveforms.finish(first.path, <double>[0.4]);
    await loading;

    await controller.load(null);

    expect(controller.peaks.value, isEmpty);
    expect(controller.isLoading.value, isFalse);
  });

  test(
    'replacing peaks gives a new list, so the painter sees the change',
    () async {
      final MediaInfo first = song('one');
      final MediaInfo second = song('two');

      final Future<void> firstLoad = controller.load(first);
      waveforms.finish(first.path, <double>[0.4]);
      await firstLoad;
      final List<double> before = controller.peaks.value;

      final Future<void> secondLoad = controller.load(second);
      waveforms.finish(second.path, <double>[0.4]);
      await secondLoad;

      expect(identical(before, controller.peaks.value), isFalse);
    },
  );
}
