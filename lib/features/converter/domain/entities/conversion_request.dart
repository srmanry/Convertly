import 'package:equatable/equatable.dart';

import '../../../../core/enums/audio_format.dart';
import '../../../../core/enums/audio_quality.dart';

/// What the conversion engine should produce.
///
/// One request type serves every tool: extraction, format conversion,
/// trimming, merging and compression differ only in the fields they set, which
/// is what keeps a single engine behind all of them.
class ConversionRequest extends Equatable {
  const ConversionRequest({
    required this.inputPaths,
    required this.outputPath,
    required this.format,
    this.quality,
    this.trimStart,
    this.trimEnd,
    this.totalDuration,
  });

  /// Whether this request has everything the engine needs.
  ///
  /// Checked by the repository so an invalid request becomes a user-facing
  /// failure rather than an assertion crash in release.
  bool get isValid =>
      inputPaths.isNotEmpty &&
      inputPaths.every((String path) => path.isNotEmpty) &&
      outputPath.isNotEmpty;

  /// Single input for most tools; several, in order, for a merge.
  final List<String> inputPaths;

  final String outputPath;
  final AudioFormat format;

  /// Ignored for formats where [AudioFormat.supportsBitrate] is false.
  final AudioQuality? quality;

  final Duration? trimStart;
  final Duration? trimEnd;

  /// Media length, used to turn FFmpeg's position reports into a percentage.
  final Duration? totalDuration;

  bool get isMerge => inputPaths.length > 1;

  bool get isTrim => trimStart != null || trimEnd != null;

  /// Length of the output, which is what progress should be measured against.
  Duration? get expectedDuration {
    if (!isTrim) {
      return totalDuration;
    }
    final Duration start = trimStart ?? Duration.zero;
    final Duration? end = trimEnd ?? totalDuration;
    if (end == null) {
      return null;
    }
    final Duration span = end - start;
    return span.isNegative ? null : span;
  }

  @override
  List<Object?> get props => <Object?>[
    inputPaths,
    outputPath,
    format,
    quality,
    trimStart,
    trimEnd,
    totalDuration,
  ];
}
