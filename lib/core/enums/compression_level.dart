import 'package:get/get.dart';

import '../i18n/translation_keys.dart';
import 'audio_quality.dart';

/// Preset compression strengths, mapped onto concrete bitrates.
enum CompressionLevel {
  high(labelKey: K.compressionHigh, quality: AudioQuality.kbps256),
  medium(labelKey: K.compressionMedium, quality: AudioQuality.kbps128),
  low(labelKey: K.compressionLow, quality: AudioQuality.kbps96);

  const CompressionLevel({required this.labelKey, required this.quality});

  final String labelKey;

  String get label => labelKey.tr;
  final AudioQuality quality;

  /// Rough output size for [duration] at this bitrate.
  ///
  /// An estimate only: constant-bitrate audio plus container overhead, which
  /// is close enough to set expectations before converting.
  int estimatedSizeInBytes(Duration duration) {
    final int bitsPerSecond = quality.bitrate * 1000;
    return (duration.inMilliseconds / 1000 * bitsPerSecond / 8).round();
  }
}
