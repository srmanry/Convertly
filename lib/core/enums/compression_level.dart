import 'audio_quality.dart';

/// Preset compression strengths, mapped onto concrete bitrates.
enum CompressionLevel {
  high(label: 'High quality', quality: AudioQuality.kbps256),
  medium(label: 'Medium', quality: AudioQuality.kbps128),
  low(label: 'Small size', quality: AudioQuality.kbps96);

  const CompressionLevel({required this.label, required this.quality});

  final String label;
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
