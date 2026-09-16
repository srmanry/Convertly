import 'package:convertly/core/enums/audio_format.dart';
import 'package:convertly/core/enums/audio_quality.dart';
import 'package:convertly/core/enums/cleanup_mode.dart';
import 'package:convertly/core/enums/export_speed.dart';
import 'package:convertly/core/enums/mix_length_mode.dart';
import 'package:convertly/core/enums/noise_strength.dart';
import 'package:convertly/features/converter/data/ffmpeg_command_builder.dart';
import 'package:convertly/features/converter/domain/entities/cleanup_settings.dart';
import 'package:convertly/features/converter/domain/entities/conversion_request.dart';
import 'package:convertly/features/converter/domain/entities/mix_settings.dart';
import 'package:convertly/features/converter/domain/entities/mix_track.dart';
import 'package:convertly/features/converter/domain/entities/volume_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

/// Index of [value] in [args], or -1.
int indexOf(List<String> args, String value) => args.indexOf(value);

void main() {
  speedTests();
  envelopeTests();
  mixTests();
  cleanupTests();

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

// --- Mixing -----------------------------------------------------------------

/// A mix request over [volumes], with everything else left at its default.
ConversionRequest mixRequest(
  List<double> volumes, {
  List<Duration>? startOffsets,
  bool loopShorterTracks = false,
  MixLengthMode lengthMode = MixLengthMode.longestTrack,
  ExportSpeed speed = ExportSpeed.normal,
}) {
  return ConversionRequest(
    inputPaths: <String>[
      for (int i = 0; i < volumes.length; i++) '/in/track$i.mp3',
    ],
    outputPath: '/out/mixed_audio.mp3',
    format: AudioFormat.mp3,
    quality: AudioQuality.kbps192,
    speed: speed,
    mix: MixSettings(
      tracks: <MixTrack>[
        for (int i = 0; i < volumes.length; i++)
          MixTrack(
            volume: volumes[i],
            start: startOffsets != null && i < startOffsets.length
                ? startOffsets[i]
                : Duration.zero,
          ),
      ],
      loopShorterTracks: loopShorterTracks,
      lengthMode: lengthMode,
    ),
  );
}

String filterGraph(List<String> args) =>
    args[args.indexOf('-filter_complex') + 1];

void mixTests() {
  group('mixing', () {
    test('layers every input with its own volume', () {
      final List<String> args = FfmpegCommandBuilder.build(
        mixRequest(<double>[1, 0.35]),
      );

      expect(
        filterGraph(args),
        '[0:a]volume=1[t0];[1:a]volume=0.35[t1];[t0][t1]'
        'amix=inputs=2:duration=longest:dropout_transition=0:normalize=0'
        '[mixed];[mixed]alimiter=limit=0.95:level=0[out]',
      );
      expect(args[args.indexOf('-map') + 1], '[out]');
    });

    test('mixes rather than concatenates when several inputs are given', () {
      final List<String> args = FfmpegCommandBuilder.build(
        mixRequest(<double>[1, 1]),
      );

      expect(filterGraph(args), contains('amix='));
      expect(filterGraph(args), isNot(contains('concat=')));
    });

    test('stops with the main track when asked to', () {
      final List<String> args = FfmpegCommandBuilder.build(
        mixRequest(<double>[1, 0.5], lengthMode: MixLengthMode.mainTrack),
      );

      expect(filterGraph(args), contains('duration=first'));
    });

    test('loops every layer but never the main track', () {
      final List<String> args = FfmpegCommandBuilder.build(
        mixRequest(<double>[1, 0.4, 0.4], loopShorterTracks: true),
      );

      // -stream_loop is an input option, so each one must sit directly before
      // the input it applies to.
      expect(args.sublist(args.indexOf('-i')), <String>[
        '-i',
        '/in/track0.mp3',
        '-stream_loop',
        '-1',
        '-i',
        '/in/track1.mp3',
        '-stream_loop',
        '-1',
        '-i',
        '/in/track2.mp3',
        ...args.sublist(args.indexOf('-filter_complex')),
      ]);
    });

    test('a looping mix always ends with the main track', () {
      // Otherwise an endless layer would keep the export running forever.
      final List<String> args = FfmpegCommandBuilder.build(
        mixRequest(
          <double>[1, 0.4],
          loopShorterTracks: true,
          lengthMode: MixLengthMode.longestTrack,
        ),
      );

      expect(filterGraph(args), contains('duration=first'));
    });

    test('chains a tempo change after the mix', () {
      final List<String> args = FfmpegCommandBuilder.build(
        mixRequest(<double>[1, 1], speed: ExportSpeed.oneAndHalf),
      );

      expect(
        filterGraph(args),
        endsWith('alimiter=limit=0.95:level=0,atempo=1.5[out]'),
      );
      expect(args, isNot(contains('-filter:a')));
    });

    test('rejects a request whose entries do not cover every input', () {
      const ConversionRequest request = ConversionRequest(
        inputPaths: <String>['/in/a.mp3', '/in/b.mp3'],
        outputPath: '/out/mixed.mp3',
        format: AudioFormat.mp3,
        mix: MixSettings(tracks: <MixTrack>[MixTrack()]),
      );

      expect(request.isValid, isFalse);
    });

    test('a clip is delayed to the point it starts at', () {
      // A 40s track from zero, then a 20s clip that comes in at 0:41.
      final List<String> args = FfmpegCommandBuilder.build(
        mixRequest(
          <double>[1, 1],
          startOffsets: <Duration>[Duration.zero, const Duration(seconds: 41)],
        ),
      );

      expect(
        filterGraph(args),
        startsWith('[0:a]volume=1[t0];[1:a]volume=1,adelay=41000:all=1[t1];'),
      );
    });

    test('a track starting at zero carries no delay filter', () {
      expect(
        filterGraph(FfmpegCommandBuilder.build(mixRequest(<double>[1, 1]))),
        isNot(contains('adelay')),
      );
    });

    test('placement and level are both applied to the same track', () {
      final List<String> args = FfmpegCommandBuilder.build(
        mixRequest(
          <double>[1, 0.4],
          startOffsets: <Duration>[Duration.zero, const Duration(seconds: 5)],
        ),
      );

      expect(
        filterGraph(args),
        contains('[1:a]volume=0.40,adelay=5000:all=1[t1];'),
      );
    });

    test('sub-second placement keeps its precision', () {
      final List<String> args = FfmpegCommandBuilder.build(
        mixRequest(
          <double>[1, 1],
          startOffsets: <Duration>[
            Duration.zero,
            const Duration(seconds: 2, milliseconds: 250),
          ],
        ),
      );

      expect(filterGraph(args), contains('adelay=2250:all=1'));
    });

    test('an arrangement is still limited and mixed as one graph', () {
      final List<String> args = FfmpegCommandBuilder.build(
        mixRequest(
          <double>[1, 1],
          startOffsets: <Duration>[Duration.zero, const Duration(seconds: 41)],
        ),
      );

      // Non-overlapping clips still go through amix: only one is audible at a
      // time, so nothing is summed and the levels are untouched.
      expect(filterGraph(args), contains('amix=inputs=2:duration=longest'));
      expect(filterGraph(args), endsWith('alimiter=limit=0.95:level=0[out]'));
    });

    test('a clip is cut down to the part that was selected', () {
      final List<String> args = FfmpegCommandBuilder.build(
        ConversionRequest(
          inputPaths: const <String>['/in/a.mp3', '/in/b.mp3'],
          outputPath: '/out/timeline.mp3',
          format: AudioFormat.mp3,
          mix: const MixSettings(
            tracks: <MixTrack>[
              MixTrack(
                trimStart: Duration(seconds: 19),
                trimEnd: Duration(seconds: 81),
              ),
              // Right after the 62 seconds the first clip contributes.
              MixTrack(start: Duration(seconds: 62)),
            ],
          ),
        ),
      );

      expect(
        filterGraph(args),
        startsWith(
          '[0:a]atrim=start=19.000:end=81.000,asetpts=PTS-STARTPTS,'
          'volume=1[t0];[1:a]volume=1,adelay=62000:all=1[t1];',
        ),
      );
    });

    test('an untrimmed clip carries no trim filter', () {
      expect(
        filterGraph(FfmpegCommandBuilder.build(mixRequest(<double>[1, 1]))),
        isNot(contains('atrim')),
      );
    });

    test('a trimmed clip is rebased before it is moved into place', () {
      // atrim leaves the kept audio at its original timestamps, so rebasing
      // has to happen before the delay or the clip lands in the wrong place.
      final List<String> args = FfmpegCommandBuilder.build(
        ConversionRequest(
          inputPaths: const <String>['/in/a.mp3'],
          outputPath: '/out/timeline.mp3',
          format: AudioFormat.mp3,
          mix: const MixSettings(
            tracks: <MixTrack>[
              MixTrack(
                start: Duration(seconds: 30),
                trimStart: Duration(seconds: 5),
                trimEnd: Duration(seconds: 15),
              ),
            ],
          ),
        ),
      );

      final String graph = filterGraph(args);
      expect(graph.indexOf('asetpts'), lessThan(graph.indexOf('adelay')));
    });

    test('a clip trimmed only at the start needs no end', () {
      final List<String> args = FfmpegCommandBuilder.build(
        ConversionRequest(
          inputPaths: const <String>['/in/a.mp3'],
          outputPath: '/out/timeline.mp3',
          format: AudioFormat.mp3,
          mix: const MixSettings(
            tracks: <MixTrack>[MixTrack(trimStart: Duration(seconds: 5))],
          ),
        ),
      );

      expect(filterGraph(args), contains('atrim=start=5.000,'));
      expect(filterGraph(args), isNot(contains(':end=')));
    });

    test('rejects a request with no entry for every input', () {
      const ConversionRequest request = ConversionRequest(
        inputPaths: <String>['/in/a.mp3', '/in/b.mp3'],
        outputPath: '/out/mixed.mp3',
        format: AudioFormat.mp3,
        mix: MixSettings(tracks: <MixTrack>[MixTrack()]),
      );

      expect(request.isValid, isFalse);
    });

    test('a mix is not treated as a merge', () {
      final ConversionRequest request = mixRequest(<double>[1, 1]);

      expect(request.isMix, isTrue);
      expect(request.isMerge, isFalse);
    });
  });
}

// --- Noise removal ----------------------------------------------------------

/// A cleanup request in [mode] at [strength].
ConversionRequest cleanupRequest(
  CleanupMode mode, {
  NoiseStrength strength = NoiseStrength.medium,
  ExportSpeed speed = ExportSpeed.normal,
}) {
  return ConversionRequest(
    inputPaths: const <String>['/in/song.mp3'],
    outputPath: '/out/song_cleaned.mp3',
    format: AudioFormat.mp3,
    quality: AudioQuality.kbps192,
    speed: speed,
    cleanup: CleanupSettings(mode: mode, strength: strength),
  );
}

String audioFilter(List<String> args) => args[args.indexOf('-filter:a') + 1];

void cleanupTests() {
  group('noise removal', () {
    test('cuts rumble before denoising the rest', () {
      final List<String> args = FfmpegCommandBuilder.build(
        cleanupRequest(CleanupMode.backgroundNoise),
      );

      expect(audioFilter(args), 'highpass=f=80,afftdn=nr=12:nf=-28:tn=1');
    });

    test('strength changes how much is subtracted', () {
      expect(
        audioFilter(
          FfmpegCommandBuilder.build(
            cleanupRequest(
              CleanupMode.backgroundNoise,
              strength: NoiseStrength.light,
            ),
          ),
        ),
        contains('afftdn=nr=6:nf=-35'),
      );
      expect(
        audioFilter(
          FfmpegCommandBuilder.build(
            cleanupRequest(
              CleanupMode.backgroundNoise,
              strength: NoiseStrength.strong,
            ),
          ),
        ),
        contains('afftdn=nr=24:nf=-20'),
      );
    });

    test('voice focus keeps only the speech band', () {
      expect(
        audioFilter(
          FfmpegCommandBuilder.build(cleanupRequest(CleanupMode.voiceFocus)),
        ),
        'highpass=f=200,lowpass=f=3400,afftdn=nr=12:nf=-28:tn=1',
      );
    });

    test('removing vocals cancels the centre and takes no strength', () {
      final List<String> args = FfmpegCommandBuilder.build(
        cleanupRequest(
          CleanupMode.removeVocals,
          strength: NoiseStrength.strong,
        ),
      );

      expect(audioFilter(args), 'pan=stereo|c0=c0-c1|c1=c1-c0');
      expect(audioFilter(args), isNot(contains('afftdn')));
    });

    test('every strength stays inside afftdn\'s accepted range', () {
      for (final NoiseStrength strength in NoiseStrength.values) {
        expect(strength.reductionDb, greaterThanOrEqualTo(1));
        expect(strength.reductionDb, lessThanOrEqualTo(97));
        expect(strength.floorDb, greaterThanOrEqualTo(-80));
        expect(strength.floorDb, lessThanOrEqualTo(-20));
      }
    });

    test('a tempo change joins the same chain', () {
      expect(
        audioFilter(
          FfmpegCommandBuilder.build(
            cleanupRequest(
              CleanupMode.backgroundNoise,
              speed: ExportSpeed.half,
            ),
          ),
        ),
        endsWith(',atempo=0.5'),
      );
    });

    test('an untouched conversion carries no cleanup filter', () {
      const ConversionRequest request = ConversionRequest(
        inputPaths: <String>['/in/song.mp3'],
        outputPath: '/out/song.mp3',
        format: AudioFormat.mp3,
      );

      expect(FfmpegCommandBuilder.build(request), isNot(contains('-filter:a')));
    });
  });
}

// --- Shaping a clip's level over time ----------------------------------------

/// A mix of one clip carrying [envelope] across [length].
ConversionRequest shapedRequest(
  VolumeEnvelope envelope, {
  Duration length = const Duration(seconds: 10),
  double volume = 1,
}) {
  return ConversionRequest(
    inputPaths: const <String>['/in/a.mp3'],
    outputPath: '/out/mixed.mp3',
    format: AudioFormat.mp3,
    mix: MixSettings(
      tracks: <MixTrack>[
        MixTrack(volume: volume, envelope: envelope, length: length),
      ],
    ),
  );
}

/// Full at both ends with one point in the middle pulled down to [level].
VolumeEnvelope dipTo(double level) => VolumeEnvelope(<EnvelopePoint>[
  const EnvelopePoint(0, 1),
  EnvelopePoint(0.5, level),
  const EnvelopePoint(1, 1),
]);

/// The `volume` filter written for the single clip in [args].
String volumeFilter(List<String> args) {
  final String graph = filterGraph(args);
  final int start = graph.indexOf('volume=');
  final int end = graph.indexOf('[t0]', start);
  return graph.substring(start, end);
}

void envelopeTests() {
  group('shaping a level over time', () {
    test('a flat shape stays a plain level', () {
      // Nothing about the sound changes, so nothing has to be evaluated per
      // frame either.
      final List<String> args = FfmpegCommandBuilder.build(
        shapedRequest(VolumeEnvelope.flat),
      );

      expect(volumeFilter(args), 'volume=1');
      expect(filterGraph(args), isNot(contains('eval=frame')));
    });

    test('a shaped clip is evaluated as it plays', () {
      final VolumeEnvelope dipped = dipTo(0.2);

      final List<String> args = FfmpegCommandBuilder.build(
        shapedRequest(dipped),
      );

      // Without eval=frame the expression is read once and the shape never
      // moves.
      expect(volumeFilter(args), contains('eval=frame'));
      expect(volumeFilter(args), contains('t'));
    });

    test('a dip becomes a run down and a run back up', () {
      final VolumeEnvelope dipped = dipTo(0.2);

      final String filter = volumeFilter(
        FfmpegCommandBuilder.build(shapedRequest(dipped)),
      );

      // Down to the dip, then back: three turns, so three windowed terms.
      expect('+'.allMatches(filter).length, greaterThanOrEqualTo(2));
      expect(filter, contains('gte(t,'));
      expect(filter, contains('lt(t,'));
    });

    test('each run between points is one term', () {
      final String filter = volumeFilter(
        FfmpegCommandBuilder.build(shapedRequest(dipTo(0.2))),
      );

      // Three points make two runs, whatever the clip length.
      expect('gte(t,'.allMatches(filter).length, 2);
    });

    test('a point lands at its own time on the clip', () {
      final String filter = volumeFilter(
        FfmpegCommandBuilder.build(
          shapedRequest(dipTo(0.2), length: const Duration(seconds: 96)),
        ),
      );

      // Halfway along 1:36 is 0:48 exactly: points are not rounded onto a
      // fixed grid.
      expect(filter, contains('gte(t,48)'));
      expect(filter, contains('lt(t,48)'));
    });

    test('runs ease rather than jump in a straight line', () {
      final String filter = volumeFilter(
        FfmpegCommandBuilder.build(shapedRequest(dipTo(0.2))),
      );

      // The S-curve the lane draws, held at its end so it cannot curve back.
      expect(filter, contains('(3-2*min('));
      expect(filter, contains(',1)'));
    });

    test('a run between two equal levels stays a plain figure', () {
      final VolumeEnvelope held = VolumeEnvelope(<EnvelopePoint>[
        const EnvelopePoint(0, 0.5),
        const EnvelopePoint(0.5, 0.5),
        const EnvelopePoint(1, 1),
      ]);

      final String filter = volumeFilter(
        FfmpegCommandBuilder.build(shapedRequest(held)),
      );

      expect(filter, contains('lt(t,5)*0.5+'));
    });

    test('the last run has no upper bound', () {
      final VolumeEnvelope dipped = dipTo(0.5);

      final String filter = volumeFilter(
        FfmpegCommandBuilder.build(shapedRequest(dipped)),
      );

      // A measured length a fraction short must not drop the tail to silence,
      // so the run carrying the end has a lower bound only.
      final String lastRun = filter.substring(filter.lastIndexOf('gte(t,'));
      expect(lastRun, isNot(contains('lt(t,')));
    });

    test('the track level scales the whole shape', () {
      final VolumeEnvelope dipped = dipTo(0.5);

      final String filter = volumeFilter(
        FfmpegCommandBuilder.build(shapedRequest(dipped, volume: 0.5)),
      );

      // Half of the resting 1.0, so the shape starts at 0.5 rather than 1.
      expect(filter, contains('0.5'));
      expect(filter, isNot(contains('*1*')));
    });

    test('a clip of unknown length keeps its single level', () {
      final ConversionRequest request = ConversionRequest(
        inputPaths: const <String>['/in/a.mp3'],
        outputPath: '/out/mixed.mp3',
        format: AudioFormat.mp3,
        mix: MixSettings(
          tracks: <MixTrack>[MixTrack(volume: 0.6, envelope: dipTo(0.2))],
        ),
      );

      // There is nowhere to put the points without a length, so guessing is
      // worse than leaving the clip at the level it was given.
      expect(volumeFilter(FfmpegCommandBuilder.build(request)), 'volume=0.60');
    });
  });
}
