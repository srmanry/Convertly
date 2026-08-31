/// How hard the denoiser is pushed.
///
/// The pair of numbers is what FFmpeg's `afftdn` filter takes: how much noise
/// to subtract, and the level below which audio is treated as noise. Pushing
/// either too far starts eating the music itself, so the strong preset stops
/// well short of the filter's maximum.
enum NoiseStrength {
  light(label: 'Light', reductionDb: 6, floorDb: -35),
  medium(label: 'Medium', reductionDb: 12, floorDb: -28),
  strong(label: 'Strong', reductionDb: 24, floorDb: -20);

  const NoiseStrength({
    required this.label,
    required this.reductionDb,
    required this.floorDb,
  });

  /// Noise reduction in dB. `afftdn` accepts 0.01 to 97.
  final int reductionDb;

  /// Noise floor in dB. `afftdn` accepts -80 to -20.
  final int floorDb;

  final String label;
}
