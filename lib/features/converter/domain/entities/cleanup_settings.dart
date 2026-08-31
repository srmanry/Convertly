import 'package:equatable/equatable.dart';

import '../../../../core/enums/cleanup_mode.dart';
import '../../../../core/enums/noise_strength.dart';

/// What the noise remover should strip out of a track.
class CleanupSettings extends Equatable {
  const CleanupSettings({
    required this.mode,
    this.strength = NoiseStrength.medium,
  });

  final CleanupMode mode;

  /// Ignored by modes where [CleanupMode.usesStrength] is false.
  final NoiseStrength strength;

  @override
  List<Object?> get props => <Object?>[mode, strength];
}
