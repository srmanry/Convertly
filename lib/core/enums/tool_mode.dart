import 'package:get/get.dart';

import '../i18n/translation_keys.dart';
import 'audio_format.dart';

/// The conversion tools offered by the app.
///
/// Every mode runs through the same conversion engine; they differ only in
/// what the user configures and which FFmpeg arguments that produces.
enum ToolMode {
  videoToAudio(
    titleKey: K.toolVideoToAudio,
    descriptionKey: K.toolVideoToAudioDesc,
    actionLabelKey: K.selectVideo,
    outputSuffix: '_audio',
  ),
  audioConvert(
    titleKey: K.toolAudioConvert,
    descriptionKey: K.toolAudioConvertDesc,
    actionLabelKey: K.selectAudio,
    outputSuffix: '_converted',
  ),
  cut(
    titleKey: K.toolCut,
    descriptionKey: K.toolCutDesc,
    actionLabelKey: K.selectAudio,
    outputSuffix: '_cut',
  ),
  merge(
    titleKey: K.toolMerge,
    descriptionKey: K.toolMergeDesc,
    actionLabelKey: K.addAudioFiles,
    outputSuffix: '_merged',
  ),
  compress(
    titleKey: K.toolCompress,
    descriptionKey: K.toolCompressDesc,
    actionLabelKey: K.selectAudio,
    outputSuffix: '_compressed',
  ),
  mix(
    titleKey: K.toolMix,
    descriptionKey: K.toolMixDesc,
    actionLabelKey: K.addAudioFiles,
    outputSuffix: '_mixed',
  ),
  arrange(
    titleKey: K.toolArrange,
    descriptionKey: K.toolArrangeDesc,
    actionLabelKey: K.addAudioFiles,
    outputSuffix: '_timeline',
  ),
  cleanup(
    titleKey: K.toolCleanup,
    descriptionKey: K.toolCleanupDesc,
    actionLabelKey: K.selectAudio,
    outputSuffix: '_cleaned',
  );

  const ToolMode({
    required this.titleKey,
    required this.descriptionKey,
    required this.actionLabelKey,
    required this.outputSuffix,
  });

  /// Keys rather than text: an enum is built once, at startup, while the
  /// language can change at any moment, so the words are looked up each time
  /// they are read.
  final String titleKey;
  final String descriptionKey;
  final String actionLabelKey;

  /// Added to the output file name, so it stays the same in every language:
  /// a file named on a phone set to Hindi must still be recognisable after
  /// the language is switched back.
  final String outputSuffix;

  String get title => titleKey.tr;
  String get description => descriptionKey.tr;
  String get actionLabel => actionLabelKey.tr;

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
