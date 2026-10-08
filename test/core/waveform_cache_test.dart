import 'dart:io';
import 'dart:typed_data';

import 'package:convertly/core/services/ffmpeg_service.dart';
import 'package:convertly/core/services/output_directory_service.dart';
import 'package:convertly/core/services/waveform_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts decodes and writes a little PCM, standing in for FFmpeg.
class _CountingFfmpeg implements FfmpegService {
  int decodeCount = 0;

  @override
  Future<bool> decodeToPcm({
    required String source,
    required String destination,
    int sampleRate = 4000,
  }) async {
    decodeCount++;
    // Two seconds of silence-ish samples: enough for the bucketing to run.
    final Uint8List pcm = Uint8List(4000 * 2 * 2);
    for (int i = 0; i < pcm.length; i += 2) {
      pcm[i] = i % 128;
    }
    await File(destination).writeAsBytes(pcm);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// Hands out a real temporary directory.
class _TempDirectories implements OutputDirectoryService {
  _TempDirectories(this._temp);

  final Directory _temp;

  @override
  Future<Directory> resolveTemp() async => _temp;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late File track;
  late _CountingFfmpeg ffmpeg;
  late WaveformService service;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('waveform_cache_test');
    track = File('${temp.path}/track.mp3')..writeAsBytesSync(<int>[1, 2, 3, 4]);
    ffmpeg = _CountingFfmpeg();
    service = WaveformService(ffmpeg, _TempDirectories(temp));
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('reading the same track twice decodes it once', () async {
    final List<double>? first = await service.peaksFor(track.path);
    final List<double>? second = await service.peaksFor(track.path);

    expect(first, isNotNull);
    expect(second, first);
    expect(ffmpeg.decodeCount, 1);
  });

  test('a file replaced at the same path is read again', () async {
    await service.peaksFor(track.path);

    // A converted file can be overwritten in place; the shape on screen has
    // to follow what is actually there now.
    track.writeAsBytesSync(<int>[9, 9, 9, 9, 9, 9, 9, 9]);
    track.setLastModifiedSync(DateTime.now().add(const Duration(seconds: 5)));
    await service.peaksFor(track.path);

    expect(ffmpeg.decodeCount, 2);
  });

  test('old tracks are dropped rather than held forever', () async {
    for (int i = 0; i <= WaveformService.maxCachedTracks; i++) {
      final File other = File('${temp.path}/track_$i.mp3')
        ..writeAsBytesSync(<int>[i]);
      await service.peaksFor(other.path);
    }
    final int afterFilling = ffmpeg.decodeCount;

    // The first one has been pushed out by now, so it costs another decode.
    await service.peaksFor('${temp.path}/track_0.mp3');

    expect(ffmpeg.decodeCount, afterFilling + 1);
  });

  test('a missing file is simply not cached', () async {
    final List<double>? peaks = await service.peaksFor('${temp.path}/gone.mp3');

    expect(peaks, isNotNull);
    expect(ffmpeg.decodeCount, 1);

    await service.peaksFor('${temp.path}/gone.mp3');

    expect(ffmpeg.decodeCount, 2);
  });

  test('clearing forgets what was held', () async {
    await service.peaksFor(track.path);
    service.clearCache();
    await service.peaksFor(track.path);

    expect(ffmpeg.decodeCount, 2);
  });
}
