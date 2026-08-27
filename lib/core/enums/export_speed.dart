/// Playback speeds an export can be rendered at.
///
/// The same set the built-in player offers, so what the user previews is what
/// the exported file sounds like. FFmpeg's `atempo` filter accepts 0.5 to 2.0
/// in a single pass, which is exactly the range offered here.
enum ExportSpeed {
  half(0.5),
  threeQuarter(0.75),
  normal(1),
  oneAndQuarter(1.25),
  oneAndHalf(1.5),
  double_(2);

  const ExportSpeed(this.value);

  final double value;

  bool get isNormal => value == 1;

  /// `1x`, `1.5x`, `0.75x`.
  String get label {
    final String number = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
    return '${number}x';
  }

  static ExportSpeed fromValue(double value) {
    return ExportSpeed.values.firstWhere(
      (ExportSpeed speed) => speed.value == value,
      orElse: () => ExportSpeed.normal,
    );
  }
}
