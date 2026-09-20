import 'package:get/get.dart';

import '../i18n/translation_keys.dart';

/// What the cleanup tool removes from a track.
///
/// None of these separate a mixed recording into stems — that needs a trained
/// model, which cannot run offline here. They are filter passes: two measure
/// and subtract noise, the third cancels whatever is common to both channels.
enum CleanupMode {
  backgroundNoise(
    labelKey: K.cleanupNoiseTitle,
    descriptionKey: K.cleanupNoiseDesc,
  ),
  voiceFocus(
    labelKey: K.cleanupVoiceTitle,
    descriptionKey: K.cleanupVoiceDesc,
  ),
  removeVocals(
    labelKey: K.cleanupVocalsTitle,
    descriptionKey: K.cleanupVocalsDesc,
  );

  const CleanupMode({required this.labelKey, required this.descriptionKey});

  final String labelKey;
  final String descriptionKey;

  String get label => labelKey.tr;
  String get description => descriptionKey.tr;

  /// Only the denoising modes read a strength; vocal cancelling has no dial.
  bool get usesStrength => this != CleanupMode.removeVocals;

  /// Cancelling the centre channel needs two channels to subtract.
  bool get requiresStereo => this == CleanupMode.removeVocals;
}
