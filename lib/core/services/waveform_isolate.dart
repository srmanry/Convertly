import 'package:flutter/foundation.dart';

import '../utils/waveform_peaks.dart';

/// Runs the peak summary off the UI thread.
///
/// A top-level function because [compute] can only spawn one of those, and its
/// argument is a record so both inputs cross the isolate boundary together.
List<double> _bucket((Uint8List, int) input) {
  final (Uint8List bytes, int bucketCount) = input;
  return WaveformPeaks.fromPcm(bytes, bucketCount: bucketCount);
}

Future<List<double>> computeWaveformPeaks(Uint8List bytes, int bucketCount) {
  return compute(_bucket, (bytes, bucketCount));
}
