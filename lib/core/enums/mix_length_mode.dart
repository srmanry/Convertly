/// How long a mixed export runs for.
///
/// The value maps straight onto FFmpeg's `amix` `duration` option, which is
/// what decides when the mix stops rather than any length we calculate here.
enum MixLengthMode {
  mainTrack(label: 'Main track', ffmpegDuration: 'first'),
  longestTrack(label: 'Longest track', ffmpegDuration: 'longest');

  const MixLengthMode({required this.label, required this.ffmpegDuration});

  final String label;
  final String ffmpegDuration;
}
