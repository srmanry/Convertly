/// Constant bitrate presets offered for compressed output formats.
enum AudioQuality {
  kbps96(bitrate: 96),
  kbps128(bitrate: 128),
  kbps192(bitrate: 192),
  kbps256(bitrate: 256),
  kbps320(bitrate: 320);

  const AudioQuality({required this.bitrate});

  final int bitrate;

  String get label => '$bitrate kbps';

  static AudioQuality fromName(
    String? name, {
    AudioQuality fallback = AudioQuality.kbps192,
  }) {
    return AudioQuality.values.firstWhere(
      (AudioQuality quality) => quality.name == name,
      orElse: () => fallback,
    );
  }
}
