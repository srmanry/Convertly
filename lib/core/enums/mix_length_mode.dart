import 'package:get/get.dart';

import '../i18n/translation_keys.dart';

/// How long a mixed export runs for.
///
/// The value maps straight onto FFmpeg's `amix` `duration` option, which is
/// what decides when the mix stops rather than any length we calculate here.
enum MixLengthMode {
  mainTrack(labelKey: K.mixLengthMain, ffmpegDuration: 'first'),
  longestTrack(labelKey: K.mixLengthLongest, ffmpegDuration: 'longest');

  const MixLengthMode({
    required this.labelKey,
    required this.ffmpegDuration,
  });

  final String labelKey;

  /// Passed to FFmpeg, so it stays in English whatever the app is read in.
  final String ffmpegDuration;

  String get label => labelKey.tr;
}
