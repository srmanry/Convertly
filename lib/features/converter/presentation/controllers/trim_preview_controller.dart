import 'dart:async';

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import 'playable_audio_source.dart';

/// Plays just the selected section, at the chosen export speed.
///
/// Kept separate from [ConverterController] so the player and its
/// subscriptions have a clear lifetime and are released on close.
class TrimPreviewController extends GetxController {
  final AudioPlayer _player = AudioPlayer();

  final RxBool isPlaying = false.obs;
  final RxBool isPreparing = false.obs;

  /// Identifies what is being previewed, so a screen showing several clips can
  /// tell which row the running preview belongs to. Empty when nothing plays.
  final RxString playingTag = ''.obs;

  /// Which row [errorMessage] belongs to, so a failure is reported against the
  /// clip that could not play rather than against all of them.
  final RxString errorTag = ''.obs;
  final Rx<Duration> position = Duration.zero.obs;
  final RxString errorMessage = ''.obs;

  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  /// Source currently loaded, so re-previewing the same file does not reload.
  String? _loadedSource;

  @override
  void onInit() {
    super.onInit();
    _subscriptions.addAll(<StreamSubscription<Object?>>[
      _player.positionStream.listen((Duration value) => position.value = value),
      _player.playerStateStream.listen((PlayerState state) {
        isPlaying.value = state.playing;
        if (state.processingState == ProcessingState.completed) {
          unawaited(stop());
        }
      }),
    ]);
  }

  /// Plays [start] to [end] of [source] at [speed], or stops if already playing.
  Future<void> toggle({
    required String source,
    required Duration start,
    required Duration end,
    required double speed,
    String tag = '',
  }) async {
    // Tapping the row that is playing stops it; tapping a different row
    // switches to that one rather than doing nothing.
    if (isPlaying.value) {
      final bool sameRow = playingTag.value == tag;
      await stop();
      if (sameRow) {
        return;
      }
    }

    if (end <= start) {
      errorMessage.value = 'Select a section longer than zero seconds.';
      return;
    }

    isPreparing.value = true;
    errorMessage.value = '';
    errorTag.value = '';

    try {
      // setClip bounds playback to the selection, so the preview matches the
      // exported range without cutting a temporary file first.
      if (_loadedSource != source) {
        await _player.setAudioSource(playableAudioSource(source));
        _loadedSource = source;
      }
      await _player.setClip(start: start, end: end);
      await _player.setSpeed(speed);
      // setClip rebases the selection to zero, so the clip runs from 0 to
      // (end - start). Seeking to the selection's position in the source
      // would land past the end of any clip that does not start at zero, and
      // playback would finish before a sound came out.
      await _player.seek(Duration.zero);
      playingTag.value = tag;
      await _player.play();
    } catch (error) {
      _loadedSource = null;
      errorMessage.value = 'This section could not be played.';
      errorTag.value = tag;
      playingTag.value = '';
    } finally {
      isPreparing.value = false;
    }
  }

  Future<void> stop() async {
    await _player.pause();
    // Back to the start of the selection, which is zero on the clipped source.
    await _player.seek(Duration.zero);
    isPlaying.value = false;
    playingTag.value = '';
  }

  @override
  void onClose() {
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _player.dispose();
    super.onClose();
  }
}
