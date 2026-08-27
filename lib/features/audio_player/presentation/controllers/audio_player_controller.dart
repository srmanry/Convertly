import 'dart:async';

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

/// Playback speeds offered in the player.
const List<double> kPlaybackSpeeds = <double>[0.5, 0.75, 1, 1.25, 1.5, 2];

/// Wraps a [AudioPlayer] for one file.
///
/// The player and every stream subscription are released in [onClose], so
/// leaving the screen frees the native decoder (spec §25).
class AudioPlayerController extends GetxController {
  AudioPlayerController({required this.path, required this.title});

  final String path;
  final String title;

  final AudioPlayer _player = AudioPlayer();

  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> duration = Duration.zero.obs;
  final RxBool isPlaying = false.obs;
  final RxBool isLoading = true.obs;
  final RxDouble speed = 1.0.obs;
  final RxDouble volume = 1.0.obs;
  final RxString errorMessage = ''.obs;

  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  @override
  void onInit() {
    super.onInit();
    _listen();
    _load();
  }

  void _listen() {
    _subscriptions.addAll(<StreamSubscription<Object?>>[
      _player.positionStream.listen((Duration value) => position.value = value),
      _player.durationStream.listen((Duration? value) {
        if (value != null) {
          duration.value = value;
        }
      }),
      _player.playerStateStream.listen((PlayerState state) {
        isPlaying.value = state.playing;
        // Reset to the start so the play button works again after finishing.
        if (state.processingState == ProcessingState.completed) {
          isPlaying.value = false;
          _player.seek(Duration.zero);
          _player.pause();
        }
      }),
    ]);
  }

  Future<void> _load() async {
    isLoading.value = true;
    try {
      final Duration? loaded = await _player.setFilePath(path);
      if (loaded != null) {
        duration.value = loaded;
      }
      errorMessage.value = '';
    } catch (error) {
      // Covers a missing file and an unsupported or corrupt encoding alike.
      errorMessage.value = 'This file could not be played.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> togglePlay() async {
    if (errorMessage.value.isNotEmpty) {
      return;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seek(Duration target) async {
    final Duration total = duration.value;
    final Duration clamped = target < Duration.zero
        ? Duration.zero
        : (total > Duration.zero && target > total ? total : target);
    await _player.seek(clamped);
  }

  Future<void> skip(Duration offset) => seek(position.value + offset);

  Future<void> setSpeed(double value) async {
    speed.value = value;
    await _player.setSpeed(value);
  }

  Future<void> setVolume(double value) async {
    volume.value = value;
    await _player.setVolume(value);
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
