import 'package:equatable/equatable.dart';

import '../../../../core/enums/mix_length_mode.dart';
import 'mix_track.dart';

/// How several clips are combined into one.
///
/// Every clip carries the part of it that is used, where that part sits, and
/// how loud it plays. Clips left at the same start play together as layers;
/// clips whose starts follow each other play in turn. Both are the same
/// operation, which is what lets one engine serve the mixer and the timeline.
///
/// The first clip is the main one: it sets the length in
/// [MixLengthMode.mainTrack] and is the one background layers sit behind.
class MixSettings extends Equatable {
  const MixSettings({
    required this.tracks,
    this.loopShorterTracks = false,
    this.lengthMode = MixLengthMode.longestTrack,
  });

  /// One entry per input, in the same order as the inputs.
  final List<MixTrack> tracks;

  /// Repeats every layer until the main track ends, so a short background
  /// sound fills a long song instead of stopping partway.
  final bool loopShorterTracks;

  final MixLengthMode lengthMode;

  /// Looping makes a layer endless, so the mix has to end with the main track
  /// or FFmpeg would never reach the end of the longest input.
  MixLengthMode get effectiveLengthMode =>
      loopShorterTracks ? MixLengthMode.mainTrack : lengthMode;

  /// Whether the input at [index] is repeated. The main track never is.
  bool loopsTrack(int index) => loopShorterTracks && index > 0;

  MixTrack trackAt(int index) =>
      index >= 0 && index < tracks.length ? tracks[index] : const MixTrack();

  @override
  List<Object?> get props => <Object?>[tracks, loopShorterTracks, lengthMode];
}
