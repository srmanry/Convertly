/// Output container/codec the converter can produce.
///
/// [supportsBitrate] drives whether the quality selector is shown; WAV is
/// uncompressed so a bitrate choice would be meaningless there.
enum AudioFormat {
  mp3(label: 'MP3', extension: 'mp3', supportsBitrate: true),
  m4a(label: 'M4A', extension: 'm4a', supportsBitrate: true),
  wav(label: 'WAV', extension: 'wav', supportsBitrate: false);

  const AudioFormat({
    required this.label,
    required this.extension,
    required this.supportsBitrate,
  });

  final String label;
  final String extension;
  final bool supportsBitrate;

  static AudioFormat fromName(
    String? name, {
    AudioFormat fallback = AudioFormat.mp3,
  }) {
    return AudioFormat.values.firstWhere(
      (AudioFormat format) => format.name == name,
      orElse: () => fallback,
    );
  }
}
