import 'audio_format.dart';

/// The conversion tools offered by the app.
///
/// Every mode runs through the same conversion engine; they differ only in
/// what the user configures and which FFmpeg arguments that produces.
enum ToolMode {
  videoToAudio(
    title: 'Video to Audio',
    description: 'Extract audio from a video',
    actionLabel: 'Select Video',
    outputSuffix: '_audio',
  ),
  audioConvert(
    title: 'Audio Converter',
    description: 'Convert audio between formats',
    actionLabel: 'Select Audio',
    outputSuffix: '_converted',
  ),
  cut(
    title: 'Audio Cutter',
    description: 'Trim a section out of an audio file',
    actionLabel: 'Select Audio',
    outputSuffix: '_cut',
  ),
  merge(
    title: 'Audio Merger',
    description: 'Join several audio files into one',
    actionLabel: 'Add Audio Files',
    outputSuffix: '_merged',
  ),
  compress(
    title: 'Audio Compressor',
    description: 'Reduce the size of an audio file',
    actionLabel: 'Select Audio',
    outputSuffix: '_compressed',
  );

  const ToolMode({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.outputSuffix,
  });

  final String title;
  final String description;
  final String actionLabel;
  final String outputSuffix;

  bool get picksVideo => this == ToolMode.videoToAudio;

  bool get picksMultiple => this == ToolMode.merge;

  bool get supportsTrim => this == ToolMode.cut;

  /// Compression works by lowering the bitrate, so the format is fixed and the
  /// user picks a quality preset instead.
  bool get isCompression => this == ToolMode.compress;

  /// Formats a mode can output.
  List<AudioFormat> get availableFormats =>
      isCompression ? const <AudioFormat>[AudioFormat.mp3] : AudioFormat.values;
}
