import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/i18n/translation_keys.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/player_track.dart';

import '../../../../core/utils/playable_audio_source.dart';
import '../../../../core/services/output_directory_service.dart';

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
  AudioPlayerController({
    required List<PlayerTrack> queue,
    int startIndex = 0,
    AudioPlayer? player,
    Future<String> Function(String)? resolvePath,
  }) : queue = List<PlayerTrack>.unmodifiable(queue),
       _resolvePath =
           resolvePath ?? OutputDirectoryService().resolveExistingPath,
       _player = player ?? AudioPlayer() {
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

  final AudioPlayer _player;
  final Future<String> Function(String) _resolvePath;
  bool _switchingTracks = false;
  bool _handlingCompletion = false;
  Future<void>? _seekTask;
  Duration? _pendingSeek;

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
      _player.positionStream.listen((Duration value) {
        // Native events can still describe the old position during a seek.
        if (_seekTask == null && _pendingSeek == null) {
          position.value = value;
        }
      }),
      _player.durationStream.listen((Duration? value) {
        if (value != null) {
          duration.value = value;
        }
      }),
      _player.playerStateStream.listen((PlayerState state) {
        isPlaying.value = state.playing;
        if (state.processingState == ProcessingState.completed &&
            state.playing &&
            !isLoading.value &&
            !_switchingTracks &&
            !_handlingCompletion) {
          unawaited(_finishTrack());
        }
      }),
    ]);
  }

  Future<void> _finishTrack() async {
    // Pausing or loading can emit the completed state again. Handle each
    // ending once so those events cannot skip over another song.
    _handlingCompletion = true;
    try {
      if (hasNext) {
        await _openAt(index.value + 1, autoPlay: true);
      } else {
        isPlaying.value = false;
        await _player.pause();
        await _player.seek(Duration.zero);
      }
    } finally {
      _handlingCompletion = false;
    }
  }

  Future<void> _load() async {
    isLoading.value = true;
    try {
      // Not setFilePath: songs from the phone's music index arrive as
      // content:// URIs, and handing one of those to setFilePath looks for a
      // file literally named "content://..." and fails.
      final String source = await _resolvePath(path);
      if (isClosed) return;
      final Duration? loaded = await _player.setAudioSource(
        playableAudioSource(source),
      );
      if (loaded != null) {
        duration.value = loaded;
      }
      errorMessage.value = '';
    } catch (error) {
      // Covers a missing file and an unsupported or corrupt encoding alike.
      errorMessage.value = K.cannotPlayFile.tr;
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

  Future<void> _openAt(int target, {bool? autoPlay}) async {
    if (_switchingTracks ||
        isClosed ||
        target < 0 ||
        target >= queue.length ||
        target == index.value) {
      return;
    }

    // Carry the playing state across: someone who taps next while listening
    // wants the next track playing, not cued up and silent.
    final bool wasPlaying = autoPlay ?? isPlaying.value;
    _switchingTracks = true;
    try {
      await _seekTask;
      await _player.pause();
      if (isClosed) {
        return;
      }
      index.value = target;
      position.value = Duration.zero;
      duration.value = Duration.zero;
      await _load();

      if (!isClosed && wasPlaying && errorMessage.value.isEmpty) {
        // play()'s future completes when playback ends, not when it starts.
        unawaited(_player.play());
      }
    } finally {
      _switchingTracks = false;
    }
  }

  Future<void> seek(Duration target) {
    if (isClosed || _switchingTracks || isLoading.value) {
      return Future<void>.value();
    }
    final Duration total = duration.value;
    final Duration clamped = target < Duration.zero
        ? Duration.zero
        : (total > Duration.zero && target > total ? total : target);
    position.value = clamped;
    _pendingSeek = clamped;
    return _seekTask ??= _flushSeeks();
  }

  Future<void> _flushSeeks() async {
    try {
      while (_pendingSeek != null && !isClosed && !_switchingTracks) {
        final Duration target = _pendingSeek!;
        // Only one native seek at a time; newer taps replace the waiting one.
        await _player.seek(target);
        if (_pendingSeek == target) _pendingSeek = null;
      }
    } finally {
      _pendingSeek = null;
      _seekTask = null;
    }
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
