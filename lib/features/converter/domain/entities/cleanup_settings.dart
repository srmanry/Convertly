import 'package:equatable/equatable.dart';

import '../../../../core/enums/cleanup_mode.dart';
import '../../../../core/enums/noise_strength.dart';

/// What the noise remover should strip out of a track.
class CleanupSettings extends Equatable {
  const CleanupSettings({
    required this.mode,
    this.strength = NoiseStrength.medium,
    this.aiModelPath,
  });

  final CleanupMode mode;

  /// Ignored by modes where [CleanupMode.usesStrength] is false.
  final NoiseStrength strength;

  /// Where the trained model sits on disk.
  ///
  /// Null when it could not be put there. There is one clean-up rather than a
  /// choice between two, so nothing was promised that a null breaks: the
  /// command builder falls back to the measured-profile filters.
  final String? aiModelPath;

  @override
  List<Object?> get props => <Object?>[mode, strength, aiModelPath];
}
