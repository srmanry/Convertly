import 'dart:typed_data';

import 'package:convertly/core/utils/waveform_peaks.dart';
import 'package:flutter_test/flutter_test.dart';

/// Packs [samples] the way FFmpeg writes `s16le`: little-endian, two bytes each.
Uint8List pcm(List<int> samples) {
  final Uint8List bytes = Uint8List(samples.length * 2);
  final ByteData view = ByteData.view(bytes.buffer);
  for (int i = 0; i < samples.length; i++) {
    view.setInt16(i * 2, samples[i], Endian.little);
  }
  return bytes;
}

void main() {
  group('WaveformPeaks.fromPcm', () {
    test('splits the samples evenly across the buckets', () {
      final List<double> peaks = WaveformPeaks.fromPcm(
        pcm(<int>[1000, 1000, 4000, 4000, 2000, 2000]),
        bucketCount: 3,
      );

      expect(peaks, hasLength(3));
      expect(peaks[0], closeTo(0.25, 0.001));
      expect(peaks[1], closeTo(1.0, 0.001));
      expect(peaks[2], closeTo(0.5, 0.001));
    });

    test('a lone spike does not outweigh a sustained passage', () {
      final List<double> peaks = WaveformPeaks.fromPcm(
        pcm(<int>[
          16000, 0, 0, 0, 0, 0, 0, 0, // one hit, then silence
          8000, 8000, 8000, 8000, 8000, 8000, 8000, 8000, // held
        ]),
        bucketCount: 2,
      );

      // Peak bucketing would call the first bucket twice as loud as the
      // second. What the ear hears is the opposite, and so is the drawing.
      expect(peaks[1], 1.0);
      expect(peaks[0], lessThan(peaks[1]));
      expect(peaks[0], closeTo(0.707, 0.01));
    });

    test('a bar follows the energy of its slice', () {
      // Half-amplitude throughout is half the height, which is what makes a
      // quiet verse read as quieter than the chorus.
      final List<double> peaks = WaveformPeaks.fromPcm(
        pcm(<int>[8000, 8000, 16000, 16000]),
        bucketCount: 2,
      );

      expect(peaks[0], closeTo(0.5, 0.001));
      expect(peaks[1], 1.0);
    });

    test('scales against the loudest bucket so a quiet track still fills', () {
      final List<double> peaks = WaveformPeaks.fromPcm(
        pcm(<int>[100, 200]),
        bucketCount: 2,
      );

      expect(peaks[1], 1.0, reason: 'the loudest bucket always reaches full');
      expect(peaks[0], closeTo(0.5, 0.001));
    });

    test('treats negative samples by magnitude', () {
      final List<double> peaks = WaveformPeaks.fromPcm(
        pcm(<int>[-6000, 3000]),
        bucketCount: 2,
      );

      expect(peaks[0], 1.0);
      expect(peaks[1], closeTo(0.5, 0.001));
    });

    test('handles the most negative 16-bit sample', () {
      // -32768 has no positive counterpart in a signed 16-bit int; squaring
      // sidesteps the overflow a naive negation would hit.
      final List<double> peaks = WaveformPeaks.fromPcm(
        pcm(<int>[-32768, 16384]),
        bucketCount: 2,
      );

      expect(peaks[0], 1.0);
      expect(peaks[1], closeTo(0.5, 0.001));
    });

    test('a full-scale track does not flatten into a solid block', () {
      // The failure this replaced: loud music where every slice touches full
      // scale drew every bar the same height.
      final List<int> loud = <int>[
        for (int i = 0; i < 200; i++) i.isEven ? 32000 : -32000,
      ];
      final List<int> quiet = <int>[
        for (int i = 0; i < 200; i++) i.isEven ? 4000 : -4000,
      ];

      final List<double> peaks = WaveformPeaks.fromPcm(
        pcm(<int>[...loud, ...quiet]),
        bucketCount: 2,
      );

      expect(peaks[0], 1.0);
      expect(peaks[1], closeTo(0.125, 0.01));
    });

    test('silence stays flat instead of being scaled up to full', () {
      final List<double> peaks = WaveformPeaks.fromPcm(
        pcm(<int>[0, 0, 0, 0]),
        bucketCount: 4,
      );

      expect(peaks, everyElement(0.0));
    });

    test('more buckets than samples still returns the asked-for length', () {
      final List<double> peaks = WaveformPeaks.fromPcm(
        pcm(<int>[5000, 5000]),
        bucketCount: 8,
      );

      expect(peaks, hasLength(8));
      // Buckets that cover no sample read as silence rather than as noise.
      expect(peaks.where((double value) => value == 0), isNotEmpty);
    });

    test('empty audio gives a flat line, not an empty list', () {
      expect(
        WaveformPeaks.fromPcm(Uint8List(0), bucketCount: 5),
        List<double>.filled(5, 0),
      );
    });

    test('a trailing odd byte is ignored rather than read as a sample', () {
      final Uint8List complete = pcm(<int>[9000, 3000]);
      final Uint8List truncated = Uint8List.fromList(<int>[...complete, 0x7F]);

      expect(
        WaveformPeaks.fromPcm(truncated, bucketCount: 2),
        WaveformPeaks.fromPcm(complete, bucketCount: 2),
      );
    });

    test('a bucket count of zero or less asks for nothing', () {
      expect(WaveformPeaks.fromPcm(pcm(<int>[100]), bucketCount: 0), isEmpty);
      expect(WaveformPeaks.fromPcm(pcm(<int>[100]), bucketCount: -3), isEmpty);
    });

    test('the last bucket reaches the end of the track', () {
      // 10 samples over 4 buckets does not divide evenly; the loud stretch at
      // the very end must still show up.
      final List<double> peaks = WaveformPeaks.fromPcm(
        pcm(<int>[100, 100, 100, 100, 100, 100, 100, 9000, 9000, 9000]),
        bucketCount: 4,
      );

      expect(peaks.last, 1.0);
    });
  });
}
