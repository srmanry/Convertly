import 'dart:async';

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/media_info.dart';
import '../../domain/entities/mix_track.dart';
import 'playable_audio_source.dart';

/// Plays the clips straight through, in order, before they are exported.
///
/// One player holding a playlist rather than a player per clip: the platform
/// moves from one item to the next itself, which is what makes the join
/// seamless. Starting each clip on a timer would leave an audible hole or an
/// overlap at every boundary.
class TimelinePreviewController extends GetxController {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  final RxBool isPlaying = false.obs;
  final RxBool isPreparing = false.obs;
  final RxString errorMessage = ''.obs;

  /// Clip currently sounding, so the strip can highlight it.
  final RxInt currentClip = 0.obs;

  /// How far into the whole track playback has reached.
  final Rx<Duration> position = Duration.zero.obs;

  /// Where each clip begins, used to turn a position within one clip into a
  /// position along the whole track.
  List<Duration> _clipStarts = <Duration>[];

  /// What is currently loaded, so replaying an unchanged track does not
  /// reload it. The selection is part of the identity: retrimming a clip has
  /// to produce a new playlist, not reuse the old one.
  List<String> _loadedKeys = <String>[];

  @override
  void onInit() {
    super.onInit();
    _subscriptions.addAll(<StreamSubscription<Object?>>[
      _player.currentIndexStream.listen((int? index) {
        if (index != null) {
          currentClip.value = index;
        }
      }),
      _player.positionStream.listen((Duration value) {
        // positionStream reports a position inside the current clip, so the
        // clip's own start has to be added to place it on the whole track.
        final int index = currentClip.value;
        final Duration start = index < _clipStarts.length
            ? _clipStarts[index]
            : Duration.zero;
        position.value = start + value;
      }),
      _player.playerStateStream.listen((PlayerState state) {
        if (state.processingState == ProcessingState.completed) {
          unawaited(stop());
        }
      }),
    ]);
  }

  /// Builds the playlist that plays [sources] as the track describes them.
  ///
  /// A trimmed clip becomes a [ClippingAudioSource], so the playlist holds
  /// only the parts that were selected. Handing over the whole files instead
  /// would play every clip end to end regardless of what was chosen.
  static List<AudioSource> playlistFor(
    List<MediaInfo> sources,
    List<MixTrack> tracks,
  ) {
    return <AudioSource>[
      for (int index = 0; index < sources.length; index++)
        _clipSource(
          sources[index],
          index < tracks.length ? tracks[index] : const MixTrack(),
        ),
    ];
  }

  static AudioSource _clipSource(MediaInfo source, MixTrack track) {
    final UriAudioSource whole = playableAudioSource(source.playableSource);
    if (!track.isTrimmed) {
      return whole;
    }
    return ClippingAudioSource(
      child: whole,
      start: track.trimStart,
      end: track.trimEnd,
    );
  }

  /// Identity of one clip, selection included.
  static String _keyFor(MediaInfo source, MixTrack track) =>
      '${source.playableSource}|${track.trimStart}|${track.trimEnd}';

  /// Plays the whole track from the beginning, or stops if already playing.
  Future<void> toggle({
    required List<MediaInfo> clips,
    required List<MixTrack> tracks,
  }) async {
    if (isPlaying.value || isPreparing.value) {
      await stop();
      return;
    }

    if (clips.isEmpty) {
      errorMessage.value = 'Add a clip to hear the track.';
      return;
    }

    isPreparing.value = true;
    errorMessage.value = '';
    _clipStarts = <Duration>[
      for (int index = 0; index < clips.length; index++)
        index < tracks.length ? tracks[index].start : Duration.zero,
    ];

    try {
      final List<String> keys = <String>[
        for (int index = 0; index < clips.length; index++)
          _keyFor(
            clips[index],
            index < tracks.length ? tracks[index] : const MixTrack(),
          ),
      ];

      if (!_sameKeys(keys)) {
        await _player.setAudioSources(playlistFor(clips, tracks));
        _loadedKeys = keys;
      }

      await _player.seek(Duration.zero, index: 0);
      isPlaying.value = true;
      // play() completes only when the playlist ends, so it is not awaited.
      unawaited(_player.play());
    } catch (error) {
      _loadedKeys = <String>[];
      errorMessage.value = 'These clips could not be played.';
      isPlaying.value = false;
    } finally {
      isPreparing.value = false;
    }
  }

  bool _sameKeys(List<String> keys) {
    if (keys.length != _loadedKeys.length) {
      return false;
    }
    for (int index = 0; index < keys.length; index++) {
      if (keys[index] != _loadedKeys[index]) {
        return false;
      }
    }
    return true;
  }

  Future<void> stop() async {
    isPlaying.value = false;
    position.value = Duration.zero;
    currentClip.value = 0;
    await _player.pause();
    await _player.seek(Duration.zero, index: 0);
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
