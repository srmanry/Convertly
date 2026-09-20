import 'dart:async';

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/player_track.dart';

import '../../../../core/utils/playable_audio_source.dart';
import '../../../../core/i18n/translation_keys.dart';

/// Playback speeds offered in the player.
const List<double> kPlaybackSpeeds = <double>[0.5, 0.75, 1, 1.25, 1.5, 2];

/// Wraps a [AudioPlayer] for a queue of files.
///
/// The queue is whatever list the user opened the player from, so stepping to
/// the next track lands on what they saw underneath the one they tapped. A
/// single file is simply a queue of one, and the skip controls stand down.
///
/// The player and every stream subscription are released in [onClose], so
/// leaving the screen frees the native decoder (spec §25).
class AudioPlayerController extends GetxController {
  AudioPlayerController({required List<PlayerTrack> queue, int startIndex = 0})
    : queue = List<PlayerTrack>.unmodifiable(queue) {
    index.value = queue.isEmpty ? 0 : startIndex.clamp(0, queue.length - 1);
  }

  final List<PlayerTrack> queue;

  /// Which track of [queue] is loaded.
  final RxInt index = 0.obs;

  PlayerTrack? get currentTrack =>
      queue.isEmpty ? null : queue[index.value.clamp(0, queue.length - 1)];

  String get path => currentTrack?.path ?? '';

  String get title => currentTrack?.title ?? K.audio.tr;

  bool get hasPrevious => queue.length > 1 && index.value > 0;

  bool get hasNext => queue.length > 1 && index.value < queue.length - 1;

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
      // Not setFilePath: songs from the phone's music index arrive as
      // content:// URIs, and handing one of those to setFilePath looks for a
      // file literally named "content://..." and fails.
      final Duration? loaded = await _player.setAudioSource(
        playableAudioSource(path),
      );
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

  /// Moves to the next track, keeping playing if it already was.
  Future<void> next() => _openAt(index.value + 1);

  /// Goes back a track — or restarts this one.
  ///
  /// Restarting when the track is already under way is what every music player
  /// does, and it is the reason a mis-tapped previous does not lose the user's
  /// place in a long recording.
  Future<void> previous() async {
    if (position.value > const Duration(seconds: 3) || !hasPrevious) {
      await seek(Duration.zero);
      return;
    }
    await _openAt(index.value - 1);
  }

  Future<void> _openAt(int target) async {
    if (target < 0 || target >= queue.length || target == index.value) {
      return;
    }

    // Carry the playing state across: someone who taps next while listening
    // wants the next track playing, not cued up and silent.
    final bool wasPlaying = isPlaying.value;

    await _player.pause();
    index.value = target;
    position.value = Duration.zero;
    duration.value = Duration.zero;
    await _load();

    if (wasPlaying && errorMessage.value.isEmpty) {
      // play()'s future completes when playback ends, not when it starts.
      unawaited(_player.play());
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
