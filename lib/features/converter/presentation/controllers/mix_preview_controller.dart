import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/entities/media_info.dart';
import '../../domain/entities/volume_envelope.dart';
import '../../../../core/utils/playable_audio_source.dart';

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
///
/// A track's volume line is followed as it plays: many times a second each
/// player's level is set from the line at that moment, so a dip drawn at 1:12
/// is heard at 1:12, and moving a point while the preview runs is heard at
/// once.
class MixPreviewController extends GetxController {
  /// How often levels and playheads are brought up to date. Fine enough that
  /// a fade sounds smooth rather than stepped.
  static const Duration tick = Duration(milliseconds: 50);

  final List<AudioPlayer> _players = <AudioPlayer>[];
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];
  final List<Timer> _scheduledStarts = <Timer>[];

  /// Counts the timeline while the preview runs, so a clip that has not begun
  /// yet still shows the user that something is happening.
  Timer? _ticker;
  final Stopwatch _elapsed = Stopwatch();

  List<double> _volumes = const <double>[];
  List<VolumeEnvelope?> _envelopes = const <VolumeEnvelope?>[];
  List<Duration?> _lengths = const <Duration?>[];
  List<Duration> _starts = const <Duration>[];
  bool _loopLayers = false;

  /// What every level is divided by, so a boosted track fits what a player
  /// accepts without changing the balance. Fixed for a given mix, so levels
  /// do not pump as the lines rise and fall.
  double _headroom = 1;

  /// The level last sent to each player, so an unchanged level is not sent
  /// again twenty times a second.
  final List<double> _applied = <double>[];

  final List<ValueNotifier<double?>> _playheads = <ValueNotifier<double?>>[];

  /// Where the preview is along track [index], from 0 at its start to 1 at
  /// its end, or null while that track is not playing.
  ValueListenable<double?> playheadOf(int index) {
    while (_playheads.length <= index) {
      _playheads.add(ValueNotifier<double?>(null));
    }
    return _playheads[index];
  }

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
    List<VolumeEnvelope?> envelopes = const <VolumeEnvelope?>[],
  }) async {
    if (isPlaying.value || isPreparing.value) {
      await stop();
      return;
    }

    if (tracks.isEmpty) {
      errorMessage.value = 'Add a track to hear it.';
      return;
    }

    isPreparing.value = true;
    errorMessage.value = '';
    // Looping never ends on its own, so the main track has to end the preview.
    _endsWithMainTrack = endsWithMainTrack || loopLayers;
    _loopLayers = loopLayers;
    _starts = List<Duration>.of(starts);
    _lengths = <Duration?>[
      for (final MediaInfo track in tracks) track.duration,
    ];
    updateMix(volumes: volumes, envelopes: envelopes);

    try {
      await _load(tracks: tracks, loopLayers: loopLayers);

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
    required bool loopLayers,
  }) async {
    await _release();

    for (int index = 0; index < tracks.length; index++) {
      final AudioPlayer player = AudioPlayer();
      _players.add(player);

      // Only a layer repeats; the main track runs once and ends the preview.
      if (loopLayers && index > 0) {
        await player.setLoopMode(LoopMode.one);
      }
      final double level = _levelFor(index, Duration.zero);
      _applied.add(level);
      await player.setVolume(level);
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
    _ticker = Timer.periodic(tick, (_) => _onTick());
  }

  void _onTick() {
    final Duration elapsed = _elapsed.elapsed;
    // The clock on screen shows whole seconds, so it only needs a new value
    // when the second changes.
    if (elapsed.inSeconds != position.value.inSeconds) {
      position.value = elapsed;
    }

    for (int index = 0; index < _players.length; index++) {
      final AudioPlayer player = _players[index];
      final Duration start = index < _starts.length
          ? _starts[index]
          : Duration.zero;
      final Duration time = _trackTime(index, player, elapsed - start);

      final double level = _levelFor(index, time);
      if (index < _applied.length && (level - _applied[index]).abs() > 0.003) {
        _applied[index] = level;
        unawaited(player.setVolume(level));
      }

      final Duration? length = index < _lengths.length ? _lengths[index] : null;
      final bool running =
          elapsed >= start &&
          player.playing &&
          player.processingState != ProcessingState.completed;
      (playheadOf(index) as ValueNotifier<double?>).value =
          running && length != null && length > Duration.zero
          ? time.inMilliseconds / length.inMilliseconds
          : null;
    }
  }

  /// How far into its own line track [index] is.
  ///
  /// A repeating layer is measured on the running clock, because the export
  /// applies a line once across the whole repeating layer rather than again
  /// on every pass. Anything else follows its player, which also accounts for
  /// the moment it spent buffering.
  Duration _trackTime(int index, AudioPlayer player, Duration sinceStart) {
    if (_loopLayers && index > 0) {
      return sinceStart.isNegative ? Duration.zero : sinceStart;
    }
    return player.position;
  }

  double _levelFor(int index, Duration time) => previewLevel(
    volume: index < _volumes.length ? _volumes[index] : 1,
    envelope: index < _envelopes.length ? _envelopes[index] : null,
    length: index < _lengths.length ? _lengths[index] : null,
    time: time,
    headroom: _headroom,
  );

  /// Takes new slider levels and volume lines, playing or not.
  ///
  /// While the preview runs, the next tick applies them, so a point dragged
  /// under a finger is heard straight away.
  void updateMix({
    required List<double> volumes,
    required List<VolumeEnvelope?> envelopes,
  }) {
    _volumes = List<double>.of(volumes);
    _envelopes = List<VolumeEnvelope?>.of(envelopes);
    _headroom = headroomFor(_volumes, _envelopes);
    if (_players.isNotEmpty && !_elapsed.isRunning) {
      // Loaded but not yet ticking: set the starting levels directly.
      for (int index = 0; index < _players.length; index++) {
        unawaited(_players[index].setVolume(_levelFor(index, Duration.zero)));
      }
    }
  }

  /// The level a player should be at for track [volume] shaped by
  /// [envelope], [time] into a track [length] long.
  ///
  /// Past the end of the line the last point holds, which is what the export
  /// does. A track without a known length plays at its slider level.
  static double previewLevel({
    required double volume,
    required VolumeEnvelope? envelope,
    required Duration? length,
    required Duration time,
    required double headroom,
  }) {
    double shape = VolumeEnvelope.unity;
    if (envelope != null &&
        !envelope.isFlat &&
        length != null &&
        length > Duration.zero) {
      final double position = time.inMilliseconds / length.inMilliseconds;
      shape = envelope.levelAt(position.clamp(0.0, 1.0));
    }
    final double scale = headroom <= 0 ? 1 : headroom;
    return (volume * shape / scale).clamp(0.0, 1.0);
  }

  /// The loudest any track can get, and so what every level is divided by.
  ///
  /// A player treats 1.0 as full scale and will not push a track above it, so
  /// a mix containing a boosted track or a raised point is scaled down as a
  /// group. That keeps the balance between tracks, which is what the preview
  /// is for; the export applies the real gain and catches the peaks with a
  /// limiter.
  static double headroomFor(
    List<double> volumes,
    List<VolumeEnvelope?> envelopes,
  ) {
    double loudest = 1;
    for (int index = 0; index < volumes.length; index++) {
      final VolumeEnvelope? envelope = index < envelopes.length
          ? envelopes[index]
          : null;
      final double peak = envelope == null || envelope.isFlat
          ? VolumeEnvelope.unity
          : envelope.points.fold<double>(
              0,
              (double highest, EnvelopePoint point) =>
                  math.max(highest, point.level),
            );
      loudest = math.max(loudest, volumes[index] * peak);
    }
    return loudest;
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
    _applied.clear();
    for (final ValueNotifier<double?> playhead in _playheads) {
      playhead.value = null;
    }

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
    // The playheads are left for the collector rather than disposed: a lane
    // on the page that is closing may still be listening to one.
    unawaited(_release());
    super.onClose();
  }
}
