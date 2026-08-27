import 'dart:async';

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

/// Plays just the selected section, at the chosen export speed.
///
/// Kept separate from [ConverterController] so the player and its
/// subscriptions have a clear lifetime and are released on close.
class TrimPreviewController extends GetxController {
  final AudioPlayer _player = AudioPlayer();

  final RxBool isPlaying = false.obs;
  final RxBool isPreparing = false.obs;
  final Rx<Duration> position = Duration.zero.obs;
  final RxString errorMessage = ''.obs;

  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  /// Source currently loaded, so re-previewing the same file does not reload.
  String? _loadedSource;
  Duration _clipStart = Duration.zero;

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
  }) async {
    if (isPlaying.value) {
      await stop();
      return;
    }

    if (end <= start) {
      errorMessage.value = 'Select a section longer than zero seconds.';
      return;
    }

    isPreparing.value = true;
    errorMessage.value = '';

    try {
      // setClip bounds playback to the selection, so the preview matches the
      // exported range without cutting a temporary file first.
      if (_loadedSource != source) {
        await _player.setAudioSource(_resolveSource(source));
        _loadedSource = source;
      }
      await _player.setClip(start: start, end: end);
      _clipStart = start;
      await _player.setSpeed(speed);
      await _player.seek(start);
      await _player.play();
    } catch (error) {
      _loadedSource = null;
      errorMessage.value = 'This section could not be played.';
    } finally {
      isPreparing.value = false;
    }
  }

  /// A device pick is a `content://` URI; a library file is a real path.
  ///
  /// setClip requires exactly one UriAudioSource, which both factories return.
  AudioSource _resolveSource(String source) {
    final Uri? uri = Uri.tryParse(source);
    if (uri == null || !uri.hasScheme) {
      return AudioSource.file(source);
    }
    // A file:// URI must be converted back to a path rather than passed whole.
    if (uri.scheme == 'file') {
      return AudioSource.file(uri.toFilePath());
    }
    return AudioSource.uri(uri);
  }

  Future<void> stop() async {
    await _player.pause();
    await _player.seek(_clipStart);
    isPlaying.value = false;
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
