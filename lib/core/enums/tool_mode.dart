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
  ),
  mix(
    title: 'Audio Mixer',
    description: 'Layer several tracks so they play together',
    actionLabel: 'Add Audio Files',
    outputSuffix: '_mixed',
  ),
  arrange(
    title: 'Audio Timeline',
    description: 'Add clips one after another into a single file',
    actionLabel: 'Add Audio Files',
    outputSuffix: '_timeline',
  ),
  cleanup(
    title: 'Noise Remover',
    description: 'Clean background noise out of an audio file',
    actionLabel: 'Select Audio',
    outputSuffix: '_cleaned',
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

  bool get picksMultiple => this == ToolMode.merge || combinesTracks;

  /// Places its inputs on one timeline instead of playing them end to end.
  ///
  /// The mixer and the timeline run through the same engine and differ only
  /// in where a new clip lands: the mixer stacks every clip at the start so
  /// they sound together, the timeline puts each one after the last.
  bool get combinesTracks => this == ToolMode.mix || this == ToolMode.arrange;

  /// Stacks every clip at the start of the output, so they sound together.
  bool get isMix => this == ToolMode.mix;

  /// Lays clips out in turn, each with a position that can be moved.
  bool get isTimeline => this == ToolMode.arrange;

  /// Nothing is combined until there is a second clip, so the export stays
  /// disabled rather than quietly producing a copy of the input.
  bool get needsTwoSources => combinesTracks;

  bool get isCleanup => this == ToolMode.cleanup;

  bool get supportsTrim => this == ToolMode.cut;

  /// Compression works by lowering the bitrate, so the format is fixed and the
  /// user picks a quality preset instead.
  bool get isCompression => this == ToolMode.compress;

  /// Formats a mode can output.
  List<AudioFormat> get availableFormats =>
      isCompression ? const <AudioFormat>[AudioFormat.mp3] : AudioFormat.values;
}
