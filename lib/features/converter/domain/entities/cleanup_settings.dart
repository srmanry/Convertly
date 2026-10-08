import 'package:equatable/equatable.dart';

import '../../../../core/enums/cleanup_mode.dart';
import '../../../../core/enums/noise_strength.dart';
import '../../../../core/enums/noise_removal_engine.dart';

/// What the noise remover should strip out of a track.
class CleanupSettings extends Equatable {
  const CleanupSettings({
    required this.mode,
    this.strength = NoiseStrength.medium,
    this.engine = NoiseRemovalEngine.normal,
  });

  final CleanupMode mode;

  /// Ignored by modes where [CleanupMode.usesStrength] is false.
  final NoiseStrength strength;

  /// Chooses the processing implementation. AI requests remain unavailable
  /// until a model-backed service is connected to the conversion repository.
  final NoiseRemovalEngine engine;

  @override
  List<Object?> get props => <Object?>[mode, strength, engine];
}
