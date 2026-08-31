/// What the cleanup tool removes from a track.
///
/// None of these separate a mixed recording into stems — that needs a trained
/// model, which cannot run offline here. They are filter passes: two measure
/// and subtract noise, the third cancels whatever is common to both channels.
enum CleanupMode {
  backgroundNoise(
    label: 'Background noise',
    description: 'Removes hiss, hum and room noise sitting behind the audio.',
  ),
  voiceFocus(
    label: 'Voice focus',
    description: 'Keeps the speech range and drops what falls outside it.',
  ),
  removeVocals(
    label: 'Remove vocals',
    description:
        'Cancels the centre of a stereo mix, where lead vocals usually sit. '
        'Needs a stereo track and leaves some vocal bleed behind.',
  );

  const CleanupMode({required this.label, required this.description});

  final String label;
  final String description;

  /// Only the denoising modes read a strength; vocal cancelling has no dial.
  bool get usesStrength => this != CleanupMode.removeVocals;

  /// Cancelling the centre channel needs two channels to subtract.
  bool get requiresStereo => this == CleanupMode.removeVocals;
}
