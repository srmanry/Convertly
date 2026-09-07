import 'dart:math' as math;
import 'dart:typed_data';

/// Turns decoded audio into the handful of numbers a waveform is drawn from.
///
/// Deliberately pure Dart with no FFmpeg import: decoding and summarising are
/// separate jobs, and keeping the summary here means it can be tested against
/// known samples on the host instead of only on a device.
abstract final class WaveformPeaks {
  /// Buckets 16-bit little-endian mono PCM into [bucketCount] heights in the
  /// range 0..1.
  ///
  /// Each bucket is the RMS — the energy — of the samples it covers, not their
  /// loudest single sample. At the resolution a phone-width waveform asks for,
  /// one bar spans on the order of a second, and over a second of mastered
  /// music the loudest sample is essentially always near full scale. Peak
  /// bucketing therefore draws every bar at the same height: a solid block
  /// with none of the shape the user is trying to aim at. RMS follows how loud
  /// the passage actually is, which is the shape the ear agrees with.
  ///
  /// Values are scaled against the loudest bucket, not against full scale, so
  /// a quietly recorded track still fills the view.
  static List<double> fromPcm(Uint8List bytes, {required int bucketCount}) {
    if (bucketCount <= 0) {
      return const <double>[];
    }

    // Two bytes per sample; a trailing odd byte is an incomplete sample.
    final int sampleCount = bytes.lengthInBytes ~/ 2;
    if (sampleCount == 0) {
      return List<double>.filled(bucketCount, 0);
    }

    final Int16List samples = bytes.buffer.asInt16List(
      bytes.offsetInBytes,
      sampleCount,
    );

    final List<double> peaks = List<double>.filled(bucketCount, 0);
    double loudest = 0;

    for (int bucket = 0; bucket < bucketCount; bucket++) {
      // Computed from the bucket index rather than accumulated, so rounding
      // cannot drift and leave the last bucket short of the end of the track.
      final int from = sampleCount * bucket ~/ bucketCount;
      final int to = sampleCount * (bucket + 1) ~/ bucketCount;
      if (to <= from) {
        continue;
      }

      // Squares are accumulated as ints: the largest possible square is about
      // 1.07e9, so even a bucket of millions of samples stays inside a 64-bit
      // int and the sum is exact.
      int sumOfSquares = 0;
      for (int i = from; i < to; i++) {
        final int sample = samples[i];
        sumOfSquares += sample * sample;
      }

      final double value = math.sqrt(sumOfSquares / (to - from)) / 32768;
      peaks[bucket] = value;
      loudest = math.max(loudest, value);
    }

    if (loudest == 0) {
      return peaks;
    }

    for (int i = 0; i < bucketCount; i++) {
      peaks[i] = (peaks[i] / loudest).clamp(0.0, 1.0);
    }

    return peaks;
  }
}
