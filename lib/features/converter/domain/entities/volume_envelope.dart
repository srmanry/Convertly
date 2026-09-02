import 'package:equatable/equatable.dart';

/// How loud a clip is at each point along its own length.
///
/// A single slider sets one level for a whole track. This sets a level for
/// every moment of it, so one clip can drop away while another comes forward
/// and then return, without cutting anything.
///
/// Levels are evenly spaced across the clip: the first sits at its start, the
/// last at its end, and the rest divide the time between them. A clip with no
/// shaping carries no envelope at all.
class VolumeEnvelope extends Equatable {
  const VolumeEnvelope(this.levels);

  /// How many points a drawn shape is kept as.
  ///
  /// Fine enough to follow a finger, coarse enough that the filter built from
  /// it stays a readable length.
  static const int resolution = 48;

  /// The resting level, which leaves a clip exactly as it is.
  static const double unity = 1;

  /// Loudest a point can be pushed. Past this the limiter does more to the
  /// sound than the shaping does.
  static const double maxLevel = 2;

  /// A flat line at [unity]: shaped by the user but currently changing nothing.
  static VolumeEnvelope get flat =>
      VolumeEnvelope(List<double>.filled(resolution, unity));

  /// One level per point, from the start of the clip to its end.
  final List<double> levels;

  bool get isEmpty => levels.isEmpty;

  /// True when every point sits at the resting level, so the envelope has no
  /// effect and does not need to reach the filter graph.
  bool get isFlat =>
      isEmpty || levels.every((double level) => (level - unity).abs() < 0.001);

  double levelAt(int index) =>
      index >= 0 && index < levels.length ? levels[index] : unity;

  /// The same shape with [index] moved to [level].
  VolumeEnvelope withLevelAt(int index, double level) {
    if (index < 0 || index >= levels.length) {
      return this;
    }
    final List<double> next = List<double>.of(levels);
    next[index] = level.clamp(0, maxLevel);
    return VolumeEnvelope(next);
  }

  @override
  List<Object?> get props => <Object?>[levels];
}
