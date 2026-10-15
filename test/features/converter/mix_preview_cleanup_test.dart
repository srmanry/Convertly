import 'dart:async';

import 'package:convertly/features/converter/domain/entities/media_info.dart';
import 'package:convertly/features/converter/presentation/controllers/mix_preview_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

class _Player implements AudioPlayer {
  _Player(Future<void> cancelled) {
    states = StreamController<PlayerState>(onCancel: () => cancelled);
  }

  late final StreamController<PlayerState> states;
  int disposals = 0;
  @override
  bool playing = false;
  @override
  Stream<PlayerState> get playerStateStream => states.stream;
  @override
  Duration get position => Duration.zero;
  @override
  ProcessingState get processingState => ProcessingState.ready;
  @override
  Future<void> setVolume(double value) async {}
  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async => const Duration(seconds: 30);
  @override
  Future<void> play() async {
    playing = true;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await states.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'stopping and closing together cancel and dispose each player once',
    () async {
      final Completer<void> cancelled = Completer<void>();
      final List<_Player> players = <_Player>[];
      final MixPreviewController controller = MixPreviewController(
        createPlayer: () {
          final _Player player = _Player(cancelled.future);
          players.add(player);
          return player;
        },
      );
      await controller.toggle(
        tracks: <MediaInfo>[
          for (int index = 0; index < 2; index++)
            MediaInfo(
              path: '/music/$index.mp3',
              name: '$index.mp3',
              sizeInBytes: 10,
              extension: 'mp3',
              hasAudio: true,
              hasVideo: false,
              duration: const Duration(seconds: 30),
            ),
        ],
        volumes: const <double>[1, 0.6],
        starts: const <Duration>[Duration.zero, Duration.zero],
        loopLayers: false,
        endsWithMainTrack: false,
      );
      expect(controller.isPlaying.value, isTrue);
      final Future<void> stopping = controller.stop();
      controller.onClose();
      cancelled.complete();
      await stopping;
      expect(controller.isPlaying.value, isFalse);
      expect(players.map((_Player player) => player.disposals), <int>[1, 1]);
    },
  );
}
