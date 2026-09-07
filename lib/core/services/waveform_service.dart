import 'dart:io';
import 'dart:typed_data';

import 'waveform_isolate.dart';
import 'ffmpeg_service.dart';
import 'output_directory_service.dart';

/// Produces the bar heights the trim waveform is drawn from.
///
/// Two steps, deliberately kept apart: FFmpeg decodes the track to raw PCM in
/// a scratch file, then that file is summarised into peaks off the UI thread.
class WaveformService {
  WaveformService(this._ffmpeg, this._directories);

  final FfmpegService _ffmpeg;
  final OutputDirectoryService _directories;

  /// Bars to draw. Enough to show the shape of a track, few enough that the
  /// painter stays cheap on a phone that is about to run an encode.
  static const int barCount = 220;

  /// Reads [source] and returns [barCount] peaks in the range 0..1.
  ///
  /// Returns null when the audio could not be decoded — a missing waveform is
  /// a degraded trim screen, not a failed one, so callers fall back to the
  /// plain range control rather than showing an error.
  Future<List<double>?> peaksFor(String source) async {
    final Directory temp = await _directories.resolveTemp();
    final File scratch = File(
      '${temp.path}/waveform_${DateTime.now().microsecondsSinceEpoch}.pcm',
    );

    try {
      final bool decoded = await _ffmpeg.decodeToPcm(
        source: source,
        destination: scratch.path,
      );
      if (!decoded || !scratch.existsSync()) {
        return null;
      }

      final Uint8List bytes = await scratch.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }

      // A few megabytes of PCM bucketed on the UI thread is a visible stutter
      // on a cheap phone, so the loop runs in an isolate.
      return await computeWaveformPeaks(bytes, barCount);
    } finally {
      // The scratch file is worthless the moment it has been summarised, and
      // leaving it behind would grow the app's storage on every trim.
      if (scratch.existsSync()) {
        try {
          await scratch.delete();
        } on FileSystemException {
          // Cleanup is best effort; clearTemp sweeps the rest later.
        }
      }
    }
  }
}
