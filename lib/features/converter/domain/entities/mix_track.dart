import 'package:equatable/equatable.dart';

import 'volume_envelope.dart';

/// One clip's place in a combined track: which part of it is used, where that
/// part sits, and how loud it plays.
class MixTrack extends Equatable {
  const MixTrack({
    this.volume = 1,
    this.start = Duration.zero,
    this.trimStart = Duration.zero,
    this.trimEnd,
    this.envelope,
    this.length,
  });

  /// Playback gain across the whole clip. 1 leaves it as it is.
  final double volume;

  /// Level over time, when the clip has been shaped rather than just set to
  /// one level. Null means the whole clip plays at [volume].
  final VolumeEnvelope? envelope;

  /// How long the part that plays runs for, when it is known.
  ///
  /// The envelope has no time axis of its own — its points are spread across
  /// this — so shaping is only applied to a clip whose length could be read.
  final Duration? length;

  /// True once shaping would change how the clip sounds.
  bool get hasEnvelope => envelope != null && !envelope!.isFlat;

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

  /// How much of the source is used, when it can be worked out.
  Duration? get usedLength {
    final Duration? end = trimEnd;
    if (end == null) {
      return length;
    }
    final Duration span = end - trimStart;
    return span.isNegative ? Duration.zero : span;
  }

  MixTrack copyWith({
    double? volume,
    Duration? start,
    Duration? trimStart,
    Duration? trimEnd,
    VolumeEnvelope? envelope,
    Duration? length,
  }) {
    return MixTrack(
      volume: volume ?? this.volume,
      start: start ?? this.start,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      envelope: envelope ?? this.envelope,
      length: length ?? this.length,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    volume,
    start,
    trimStart,
    trimEnd,
    envelope,
    length,
  ];
}
