import 'package:equatable/equatable.dart';

import '../../../../core/enums/audio_format.dart';
import '../../../../core/enums/audio_quality.dart';
import '../../../../core/enums/export_speed.dart';
import 'cleanup_settings.dart';
import 'mix_settings.dart';

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
    this.speed = ExportSpeed.normal,
    this.mix,
    this.cleanup,
  });

  /// Whether this request has everything the engine needs.
  ///
  /// Checked by the repository so an invalid request becomes a user-facing
  /// failure rather than an assertion crash in release.
  bool get isValid =>
      inputPaths.isNotEmpty &&
      inputPaths.every((String path) => path.isNotEmpty) &&
      outputPath.isNotEmpty &&
      // A missing entry would silently play that clip whole, at full level,
      // from zero, so a mismatched list is rejected rather than padded.
      (mix == null || mix!.tracks.length == inputPaths.length);

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

  /// Tempo the output is rendered at. Pitch is preserved.
  final ExportSpeed speed;

  /// Set when the inputs are layered on top of each other rather than joined.
  final MixSettings? mix;

  /// Set when the input is being denoised.
  final CleanupSettings? cleanup;

  bool get isMix => mix != null;

  bool get isMerge => mix == null && inputPaths.length > 1;

  bool get isTrim => trimStart != null || trimEnd != null;

  /// Length of the source section being read.
  Duration? get selectedDuration {
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

  /// Length of the output, which is what progress is measured against.
  ///
  /// Speeding up shortens the result, so the percentage would run past 100%
  /// if the source length were used instead.
  Duration? get expectedDuration {
    final Duration? selected = selectedDuration;
    if (selected == null) {
      return null;
    }
    if (speed.isNormal) {
      return selected;
    }
    return Duration(
      milliseconds: (selected.inMilliseconds / speed.value).round(),
    );
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
    speed,
    mix,
    cleanup,
  ];
}
