import 'dart:collection';
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

  /// How many tracks' peaks are kept.
  ///
  /// Small on purpose: this holds [barCount] doubles per track, and the point
  /// is only to make going back to a file you just had open instant, not to
  /// remember the whole library.
  static const int maxCachedTracks = 6;

  /// Peaks already worked out, oldest first so the oldest is dropped first.
  ///
  /// Reading a track means decoding all of it to PCM, which on a long
  /// recording is seconds of work on a cheap phone. Doing that again because
  /// the user went back and reopened the same file is waiting they should
  /// never have to do.
  final LinkedHashMap<String, List<double>> _cache =
      LinkedHashMap<String, List<double>>();

  /// Reads [source] and returns [barCount] peaks in the range 0..1.
  ///
  /// Returns null when the audio could not be decoded — a missing waveform is
  /// a degraded trim screen, not a failed one, so callers fall back to the
  /// plain range control rather than showing an error.
  Future<List<double>?> peaksFor(String source) async {
    final String? key = _cacheKey(source);
    if (key != null) {
      final List<double>? cached = _cache.remove(key);
      if (cached != null) {
        // Re-inserted so the most recently used entry is the last to go.
        _cache[key] = cached;
        return cached;
      }
    }

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
      final List<double> peaks = await computeWaveformPeaks(bytes, barCount);
      if (key != null) {
        _cache[key] = peaks;
        while (_cache.length > maxCachedTracks) {
          _cache.remove(_cache.keys.first);
        }
      }
      return peaks;
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

  /// Identifies a file by what it is, not just where it is.
  ///
  /// Length and modified time are part of the key because a converted file
  /// can be replaced at the same path: keying on the path alone would then
  /// draw the old track's shape over the new one. Null when the file cannot
  /// be read at all, which simply means nothing is cached for it.
  String? _cacheKey(String source) {
    try {
      final FileStat stat = File(source).statSync();
      if (stat.type == FileSystemEntityType.notFound) {
        return null;
      }
      return '$source|${stat.size}|${stat.modified.microsecondsSinceEpoch}';
    } on FileSystemException {
      return null;
    }
  }

  /// Forgets everything held, for when storage is cleared underneath us.
  void clearCache() => _cache.clear();
}
