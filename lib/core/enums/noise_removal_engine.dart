import 'package:get/get.dart';

import '../i18n/translation_keys.dart';

/// The implementation used to clean a recording.
///
/// [ai] is deliberately not ready until a real model-backed processor is
/// wired into the conversion repository. Keeping that state explicit stops
/// the existing FFmpeg filters from being presented as AI processing.
enum NoiseRemovalEngine {
  normal(
    labelKey: K.cleanupEngineNormal,
    descriptionKey: K.cleanupEngineNormalDesc,
    isReady: true,
  ),
  ai(
    labelKey: K.cleanupEngineAi,
    descriptionKey: K.cleanupEngineAiDesc,
    isReady: false,
  );

  const NoiseRemovalEngine({
    required this.labelKey,
    required this.descriptionKey,
    required this.isReady,
  });

  final String labelKey;
  final String descriptionKey;

  /// False while this engine has no processor/model behind it.
  final bool isReady;

  String get label => labelKey.tr;
  String get description => descriptionKey.tr;
}
