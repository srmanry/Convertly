import 'package:equatable/equatable.dart';

/// One clip's place in a combined track: which part of it is used, where that
/// part sits, and how loud it plays.
class MixTrack extends Equatable {
  const MixTrack({
    this.volume = 1,
    this.start = Duration.zero,
    this.trimStart = Duration.zero,
    this.trimEnd,
  });

  /// Playback gain. 1 leaves the clip as it is.
  final double volume;

  /// Where the used part begins on the finished track.
  final Duration start;

  /// Point in the source where the used part begins.
  final Duration trimStart;

  /// Point in the source where the used part ends.
  ///
  /// Null means "play to the end", which is what a clip that has not been
  /// trimmed uses, so an unknown source length is not a problem.
  final Duration? trimEnd;

  /// True once the clip is shorter than the file it came from.
  bool get isTrimmed => trimStart > Duration.zero || trimEnd != null;

  /// How much of the source is used, when both ends are known.
  Duration? get usedLength {
    final Duration? end = trimEnd;
    if (end == null) {
      return null;
    }
    final Duration span = end - trimStart;
    return span.isNegative ? Duration.zero : span;
  }

  MixTrack copyWith({
    double? volume,
    Duration? start,
    Duration? trimStart,
    Duration? trimEnd,
  }) {
    return MixTrack(
      volume: volume ?? this.volume,
      start: start ?? this.start,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
    );
  }

  @override
  List<Object?> get props => <Object?>[volume, start, trimStart, trimEnd];
}
