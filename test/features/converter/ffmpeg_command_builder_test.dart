import 'package:convertly/core/enums/audio_format.dart';
import 'package:convertly/core/enums/audio_quality.dart';
import 'package:convertly/core/enums/export_speed.dart';
import 'package:convertly/features/converter/data/ffmpeg_command_builder.dart';
import 'package:convertly/features/converter/domain/entities/conversion_request.dart';
import 'package:flutter_test/flutter_test.dart';

/// Index of [value] in [args], or -1.
int indexOf(List<String> args, String value) => args.indexOf(value);

void main() {
  speedTests();

  group('codec selection', () {
    test('maps each format to its encoder', () {
      expect(FfmpegCommandBuilder.codecFor(AudioFormat.mp3), 'libmp3lame');
      expect(FfmpegCommandBuilder.codecFor(AudioFormat.m4a), 'aac');
      expect(FfmpegCommandBuilder.codecFor(AudioFormat.wav), 'pcm_s16le');
    });
  });

  group('video to audio', () {
    final ConversionRequest request = ConversionRequest(
      inputPaths: const <String>['/in/clip.mp4'],
      outputPath: '/out/clip_audio.mp3',
      format: AudioFormat.mp3,
      quality: AudioQuality.kbps192,
      totalDuration: const Duration(minutes: 3),
    );

    test('reads the input and writes the output last', () {
      final List<String> args = FfmpegCommandBuilder.build(request);

      expect(args[indexOf(args, '-i') + 1], '/in/clip.mp4');
      expect(args.last, '/out/clip_audio.mp3');
    });

    test('drops the video stream', () {
      expect(FfmpegCommandBuilder.build(request), contains('-vn'));
    });

    test('applies the selected bitrate', () {
      final List<String> args = FfmpegCommandBuilder.build(request);

      expect(args[indexOf(args, '-c:a') + 1], 'libmp3lame');
      expect(args[indexOf(args, '-b:a') + 1], '192k');
    });

    test('overwrites without prompting', () {
      expect(FfmpegCommandBuilder.build(request), contains('-y'));
    });
  });

  test('wav output carries no bitrate flag', () {
    final List<String> args = FfmpegCommandBuilder.build(
      ConversionRequest(
        inputPaths: const <String>['/in/song.mp3'],
        outputPath: '/out/song.wav',
        format: AudioFormat.wav,
        // Even when a quality is supplied it must be ignored for WAV.
        quality: AudioQuality.kbps320,
      ),
    );

    expect(args, isNot(contains('-b:a')));
    expect(args[indexOf(args, '-c:a') + 1], 'pcm_s16le');
  });

  group('trimming', () {
    test('emits start and end after the input', () {
      final List<String> args = FfmpegCommandBuilder.build(
        ConversionRequest(
          inputPaths: const <String>['/in/song.mp3'],
          outputPath: '/out/cut.mp3',
          format: AudioFormat.mp3,
          quality: AudioQuality.kbps192,
          trimStart: const Duration(seconds: 30),
          trimEnd: const Duration(seconds: 90, milliseconds: 500),
        ),
      );

      expect(args[indexOf(args, '-ss') + 1], '30.000');
      expect(args[indexOf(args, '-to') + 1], '90.500');
      // Output seeking: the seek flags must follow -i to stay accurate.
      expect(indexOf(args, '-ss'), greaterThan(indexOf(args, '-i')));
    });

    test('omits the flags when no range is set', () {
      final List<String> args = FfmpegCommandBuilder.build(
        ConversionRequest(
          inputPaths: const <String>['/in/song.mp3'],
          outputPath: '/out/song.m4a',
          format: AudioFormat.m4a,
        ),
      );

      expect(args, isNot(contains('-ss')));
      expect(args, isNot(contains('-to')));
    });
  });

  group('merging', () {
    final ConversionRequest request = ConversionRequest(
      inputPaths: const <String>['/in/a.mp3', '/in/b.mp3', '/in/c.wav'],
      outputPath: '/out/merged_audio.mp3',
      format: AudioFormat.mp3,
      quality: AudioQuality.kbps192,
    );

    test('passes every input in order', () {
      final List<String> args = FfmpegCommandBuilder.build(request);
      final List<String> inputs = <String>[
        for (int i = 0; i < args.length - 1; i++)
          if (args[i] == '-i') args[i + 1],
      ];

      expect(inputs, <String>['/in/a.mp3', '/in/b.mp3', '/in/c.wav']);
    });

    test('builds a concat filter covering all inputs', () {
      final List<String> args = FfmpegCommandBuilder.build(request);

      expect(
        args[indexOf(args, '-filter_complex') + 1],
        '[0:a][1:a][2:a]concat=n=3:v=0:a=1[out]',
      );
      expect(args[indexOf(args, '-map') + 1], '[out]');
    });

    test('does not strip video, which the concat filter already excludes', () {
      expect(FfmpegCommandBuilder.build(request), isNot(contains('-vn')));
    });
  });

  group('ConversionRequest', () {
    test('reports progress against the trimmed length', () {
      const ConversionRequest request = ConversionRequest(
        inputPaths: <String>['/in/song.mp3'],
        outputPath: '/out/cut.mp3',
        format: AudioFormat.mp3,
        trimStart: Duration(seconds: 10),
        trimEnd: Duration(seconds: 40),
        totalDuration: Duration(minutes: 5),
      );

      expect(request.expectedDuration, const Duration(seconds: 30));
    });

    test('falls back to the full length when not trimming', () {
      const ConversionRequest request = ConversionRequest(
        inputPaths: <String>['/in/song.mp3'],
        outputPath: '/out/song.wav',
        format: AudioFormat.wav,
        totalDuration: Duration(minutes: 5),
      );

      expect(request.expectedDuration, const Duration(minutes: 5));
    });

    test(
      'rejects an inverted trim range instead of reporting a negative span',
      () {
        const ConversionRequest request = ConversionRequest(
          inputPaths: <String>['/in/song.mp3'],
          outputPath: '/out/cut.mp3',
          format: AudioFormat.mp3,
          trimStart: Duration(seconds: 60),
          trimEnd: Duration(seconds: 10),
        );

        expect(request.expectedDuration, isNull);
      },
    );
  });
}

// --- Export speed -----------------------------------------------------------

void speedTests() {
  group('export speed', () {
    test('normal speed adds no tempo filter', () {
      final List<String> args = FfmpegCommandBuilder.build(
        const ConversionRequest(
          inputPaths: <String>['/in/song.mp3'],
          outputPath: '/out/song.mp3',
          format: AudioFormat.mp3,
          speed: ExportSpeed.normal,
        ),
      );

      expect(args, isNot(contains('-filter:a')));
    });

    test('a slower speed applies atempo', () {
      final List<String> args = FfmpegCommandBuilder.build(
        const ConversionRequest(
          inputPaths: <String>['/in/song.mp3'],
          outputPath: '/out/song.mp3',
          format: AudioFormat.mp3,
          speed: ExportSpeed.threeQuarter,
        ),
      );

      expect(args[args.indexOf('-filter:a') + 1], 'atempo=0.75');
    });

    test('every offered speed stays inside atempo\'s single-pass range', () {
      for (final ExportSpeed speed in ExportSpeed.values) {
        expect(speed.value, greaterThanOrEqualTo(0.5));
        expect(speed.value, lessThanOrEqualTo(2.0));
      }
    });

    test('a merge chains the tempo change after the concat', () {
      final List<String> args = FfmpegCommandBuilder.build(
        const ConversionRequest(
          inputPaths: <String>['/in/a.mp3', '/in/b.mp3'],
          outputPath: '/out/merged.mp3',
          format: AudioFormat.mp3,
          speed: ExportSpeed.double_,
        ),
      );

      expect(
        args[args.indexOf('-filter_complex') + 1],
        '[0:a][1:a]concat=n=2:v=0:a=1[joined];[joined]atempo=2.0[out]',
      );
      // -filter:a and -filter_complex cannot both be used.
      expect(args, isNot(contains('-filter:a')));
    });

    test('a faster export shortens the expected duration', () {
      const ConversionRequest request = ConversionRequest(
        inputPaths: <String>['/in/song.mp3'],
        outputPath: '/out/song.mp3',
        format: AudioFormat.mp3,
        totalDuration: Duration(minutes: 4),
        speed: ExportSpeed.double_,
      );

      expect(request.selectedDuration, const Duration(minutes: 4));
      expect(request.expectedDuration, const Duration(minutes: 2));
    });

    test('a slower export lengthens the expected duration', () {
      const ConversionRequest request = ConversionRequest(
        inputPaths: <String>['/in/song.mp3'],
        outputPath: '/out/song.mp3',
        format: AudioFormat.mp3,
        trimStart: Duration(seconds: 10),
        trimEnd: Duration(seconds: 40),
        speed: ExportSpeed.half,
      );

      expect(request.selectedDuration, const Duration(seconds: 30));
      expect(request.expectedDuration, const Duration(seconds: 60));
    });

    test('labels read the way the player shows them', () {
      expect(ExportSpeed.half.label, '0.5x');
      expect(ExportSpeed.normal.label, '1x');
      expect(ExportSpeed.oneAndQuarter.label, '1.25x');
      expect(ExportSpeed.double_.label, '2x');
    });
  });
}
