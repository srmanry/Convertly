import 'dart:async';

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/media_info.dart';
import 'playable_audio_source.dart';

/// Plays the arrangement so it can be heard before it is exported.
///
/// One player per track rather than a rendered file: FFmpeg would have to
/// encode the whole thing before a single second could be heard, and the
/// balance between tracks is exactly what the user is still adjusting. Playing
/// them live means dragging a volume slider is audible immediately.
///
/// Each track is started when the timeline reaches its own start point, so a
/// clip placed at 0:41 is silent until then. The starts are scheduled rather
/// than sample-locked, so this shows the arrangement and the balance rather
/// than the exact finished timing. The export renders the real thing.
class MixPreviewController extends GetxController {
  final List<AudioPlayer> _players = <AudioPlayer>[];
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];
  final List<Timer> _scheduledStarts = <Timer>[];

  /// Counts the timeline while the preview runs, so a clip that has not begun
  /// yet still shows the user that something is happening.
  Timer? _ticker;
  final Stopwatch _elapsed = Stopwatch();

  final RxBool isPlaying = false.obs;
  final RxBool isPreparing = false.obs;
  final Rx<Duration> position = Duration.zero.obs;
  final RxString errorMessage = ''.obs;

  /// True while the main track alone decides when the preview ends.
  bool _endsWithMainTrack = true;

  /// Starts the mix, or stops it if it is already playing.
  Future<void> toggle({
    required List<MediaInfo> tracks,
    required List<double> volumes,
    required List<Duration> starts,
    required bool loopLayers,
    required bool endsWithMainTrack,
  }) async {
    if (isPlaying.value || isPreparing.value) {
      await stop();
      return;
    }

    if (tracks.length < 2) {
      errorMessage.value = 'Add a second track to hear them together.';
      return;
    }

    isPreparing.value = true;
    errorMessage.value = '';
    // Looping never ends on its own, so the main track has to end the preview.
    _endsWithMainTrack = endsWithMainTrack || loopLayers;

    try {
      await _load(tracks: tracks, volumes: volumes, loopLayers: loopLayers);

      isPlaying.value = true;
      _startTicker();

      for (int index = 0; index < _players.length; index++) {
        final AudioPlayer player = _players[index];
        final Duration start = index < starts.length
            ? starts[index]
            : Duration.zero;

        // play() completes only when that track finishes, so awaiting it here
        // would start each track after the previous one had ended.
        if (start <= Duration.zero) {
          unawaited(player.play());
        } else {
          _scheduledStarts.add(
            Timer(start, () {
              if (isPlaying.value) {
                unawaited(player.play());
              }
            }),
          );
        }
      }
    } catch (error) {
      await _release();
      errorMessage.value = 'These tracks could not be played together.';
    } finally {
      isPreparing.value = false;
    }
  }

  Future<void> _load({
    required List<MediaInfo> tracks,
    required List<double> volumes,
    required bool loopLayers,
  }) async {
    await _release();

    final List<double> levels = previewVolumes(volumes);

    for (int index = 0; index < tracks.length; index++) {
      final AudioPlayer player = AudioPlayer();
      _players.add(player);

      // Only a layer repeats; the main track runs once and ends the preview.
      if (loopLayers && index > 0) {
        await player.setLoopMode(LoopMode.one);
      }
      await player.setVolume(index < levels.length ? levels[index] : 1);
      await player.setAudioSource(
        playableAudioSource(tracks[index].playableSource),
      );

      final int position = index;
      _subscriptions.add(
        player.playerStateStream.listen((PlayerState state) {
          if (state.processingState == ProcessingState.completed) {
            _onTrackFinished(position);
          }
        }),
      );
    }
  }

  void _onTrackFinished(int index) {
    if (!isPlaying.value) {
      return;
    }
    if (_endsWithMainTrack) {
      if (index == 0) {
        unawaited(stop());
      }
      return;
    }
    // Otherwise the preview runs until every track has had its turn. A clip
    // still waiting for its start point has not finished, so a pending timer
    // keeps the preview alive until it has played.
    if (_scheduledStarts.any((Timer timer) => timer.isActive)) {
      return;
    }
    final bool allDone = _players.every(
      (AudioPlayer player) =>
          player.processingState == ProcessingState.completed,
    );
    if (allDone) {
      unawaited(stop());
    }
  }

  void _startTicker() {
    _elapsed
      ..reset()
      ..start();
    position.value = Duration.zero;
    _ticker = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => position.value = _elapsed.elapsed,
    );
  }

  /// Applies new levels to a preview that is already playing.
  ///
  /// This is what makes the sliders useful: the balance changes under the
  /// user's finger instead of only in the exported file.
  Future<void> applyVolumes(List<double> volumes) async {
    if (_players.isEmpty) {
      return;
    }
    final List<double> levels = previewVolumes(volumes);
    for (int index = 0; index < _players.length; index++) {
      await _players[index].setVolume(
        index < levels.length ? levels[index] : 1,
      );
    }
  }

  /// Track levels scaled into the range a player accepts.
  ///
  /// A player treats 1.0 as full scale and will not push a track above it, so
  /// a mix containing a boosted layer is scaled down as a group. That keeps
  /// the balance between tracks, which is what the preview is for; the export
  /// applies the real gain and catches the peaks with a limiter.
  static List<double> previewVolumes(List<double> volumes) {
    final double loudest = volumes.fold<double>(
      1,
      (double highest, double volume) => volume > highest ? volume : highest,
    );
    return <double>[
      for (final double volume in volumes) (volume / loudest).clamp(0.0, 1.0),
    ];
  }

  Future<void> stop() async {
    isPlaying.value = false;
    position.value = Duration.zero;
    await _release();
  }

  Future<void> _release() async {
    _ticker?.cancel();
    _ticker = null;
    _elapsed
      ..stop()
      ..reset();

    // A pending start must not fire a player that is about to be disposed.
    for (final Timer timer in _scheduledStarts) {
      timer.cancel();
    }
    _scheduledStarts.clear();

    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    for (final AudioPlayer player in _players) {
      await player.dispose();
    }
    _players.clear();
  }

  @override
  void onClose() {
    unawaited(_release());
    super.onClose();
  }
}
