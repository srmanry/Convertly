import 'package:equatable/equatable.dart';

/// One point on a volume shape: where along the clip, and how loud there.
class EnvelopePoint extends Equatable {
  const EnvelopePoint(this.position, this.level);

  /// Where along the clip, from 0 at its start to 1 at its end.
  final double position;

  /// How loud, where [VolumeEnvelope.unity] leaves the clip as it is.
  final double level;

  @override
  List<Object?> get props => <Object?>[position, level];
}

/// How loud a clip is at each point along its own length.
///
/// A single slider sets one level for a whole track. This sets a level that
/// moves, so one clip can drop away while another comes forward and then
/// return, without cutting anything.
///
/// The shape is a handful of points the user places, the way automation works
/// in a music mixer. Between two points the level eases from one to the other
/// along an S-curve, which sounds natural and never overshoots either point.
/// The first point always sits at the clip's start and the last at its end.
class VolumeEnvelope extends Equatable {
  const VolumeEnvelope(this.points);

  /// The resting level, which leaves a clip exactly as it is.
  static const double unity = 1;

  /// Loudest a point can be pushed. Past this the limiter does more to the
  /// sound than the shaping does.
  static const double maxLevel = 2;

  /// Most points one clip can carry.
  ///
  /// Plenty for fades and dips on a phone screen, and it keeps the filter
  /// built from the shape a readable length.
  static const int maxPoints = 16;

  /// Closest two points may sit, as a share of the clip, so each stays a
  /// separate target under a finger.
  static const double minGap = 0.01;

  /// A flat line at [unity]: two end points, changing nothing.
  static const VolumeEnvelope flat = VolumeEnvelope(<EnvelopePoint>[
    EnvelopePoint(0, unity),
    EnvelopePoint(1, unity),
  ]);

  /// Rises from silence over the first [share] of the clip.
  static VolumeEnvelope fadeIn({double share = 0.15}) =>
      VolumeEnvelope(<EnvelopePoint>[
        const EnvelopePoint(0, 0),
        EnvelopePoint(share, unity),
        const EnvelopePoint(1, unity),
      ]);

  /// Falls to silence over the last [share] of the clip.
  static VolumeEnvelope fadeOut({double share = 0.15}) =>
      VolumeEnvelope(<EnvelopePoint>[
        const EnvelopePoint(0, unity),
        EnvelopePoint(1 - share, unity),
        const EnvelopePoint(1, 0),
      ]);

  /// Quiet through the middle of the clip, full at both ends, for a layer
  /// that makes room for a voice.
  static VolumeEnvelope dip({double level = 0.3}) =>
      VolumeEnvelope(<EnvelopePoint>[
        const EnvelopePoint(0, unity),
        const EnvelopePoint(0.2, unity),
        EnvelopePoint(0.3, level),
        EnvelopePoint(0.7, level),
        const EnvelopePoint(0.8, unity),
        const EnvelopePoint(1, unity),
      ]);

  /// The points in order, first at the start and last at the end.
  final List<EnvelopePoint> points;

  bool get isEmpty => points.isEmpty;

  /// True when every point sits at the resting level, so the envelope has no
  /// effect and does not need to reach the filter graph.
  bool get isFlat =>
      isEmpty ||
      points.every((EnvelopePoint p) => (p.level - unity).abs() < 0.001);

  bool get canAddPoint => points.length < maxPoints;

  /// Whether the point at [index] can be removed. The two ends cannot: they
  /// are what pin the shape to the start and end of the clip.
  bool canRemoveAt(int index) => index > 0 && index < points.length - 1;

  /// The eased blend between two points, 0 at the first and 1 at the second.
  static double ease(double t) {
    final double x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  /// The level at [position] along the clip.
  double levelAt(double position) {
    if (points.isEmpty) {
      return unity;
    }
    if (position <= points.first.position) {
      return points.first.level;
    }
    for (int i = 0; i < points.length - 1; i++) {
      final EnvelopePoint a = points[i];
      final EnvelopePoint b = points[i + 1];
      if (position <= b.position) {
        final double span = b.position - a.position;
        if (span <= 0) {
          return b.level;
        }
        return a.level +
            (b.level - a.level) * ease((position - a.position) / span);
      }
    }
    return points.last.level;
  }

  /// The same shape with a new point at [position], and where it landed.
  ///
  /// Returns this shape and null when the point cannot be added: the shape
  /// is full, or the spot is too close to an existing point or the ends.
  (VolumeEnvelope, int?) withPointAdded(double position, double level) {
    if (!canAddPoint) {
      return (this, null);
    }
    final double at = position.clamp(0.0, 1.0);
    int index = points.length;
    for (int i = 0; i < points.length; i++) {
      if ((points[i].position - at).abs() < minGap) {
        return (this, null);
      }
      if (points[i].position > at) {
        index = i;
        break;
      }
    }
    if (index == 0 || index == points.length) {
      return (this, null);
    }
    final List<EnvelopePoint> next = List<EnvelopePoint>.of(points)
      ..insert(index, EnvelopePoint(at, _clampLevel(level)));
    return (VolumeEnvelope(next), index);
  }

  /// The same shape with the point at [index] moved.
  ///
  /// A point stays between its neighbours, so dragging never reorders the
  /// shape, and the two ends only move up and down.
  VolumeEnvelope withPointMoved(int index, double position, double level) {
    if (index < 0 || index >= points.length) {
      return this;
    }
    final double at;
    if (index == 0) {
      at = 0;
    } else if (index == points.length - 1) {
      at = 1;
    } else {
      final double low = points[index - 1].position + minGap;
      final double high = points[index + 1].position - minGap;
      at = high < low ? points[index].position : position.clamp(low, high);
    }
    final List<EnvelopePoint> next = List<EnvelopePoint>.of(points);
    next[index] = EnvelopePoint(at, _clampLevel(level));
    return VolumeEnvelope(next);
  }

  /// The same shape without the point at [index]. The ends stay.
  VolumeEnvelope withPointRemoved(int index) {
    if (!canRemoveAt(index)) {
      return this;
    }
    return VolumeEnvelope(List<EnvelopePoint>.of(points)..removeAt(index));
  }

  static double _clampLevel(double level) => level.clamp(0.0, maxLevel);

  @override
  List<Object?> get props => <Object?>[points];
}
