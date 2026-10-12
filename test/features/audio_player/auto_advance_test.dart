import 'dart:async';

import 'package:convertly/features/audio_player/domain/entities/player_track.dart';
import 'package:convertly/features/audio_player/presentation/controllers/audio_player_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

/// Emits native player events without decoding files or using platform channels.
class _FakePlayer implements AudioPlayer {
  final StreamController<PlayerState> states =
      StreamController<PlayerState>.broadcast();
  final StreamController<Duration> positions =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> durations =
      StreamController<Duration?>.broadcast();
  final List<Uri> loaded = <Uri>[];
  final List<Duration?> seeks = <Duration?>[];
  @override
  ProcessingState processingState = ProcessingState.ready;
  int playCount = 0;
  bool failLoad = false;

  @override
  bool playing = false;

  @override
  Stream<PlayerState> get playerStateStream => states.stream;

  @override
  Stream<Duration> get positionStream => positions.stream;

  @override
  Stream<Duration?> get durationStream => durations.stream;

  void finish() {
    processingState = ProcessingState.completed;
    states.add(PlayerState(playing, processingState));
  }

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    loaded.add((source as UriAudioSource).uri);
    if (failLoad) {
      throw StateError('Unreadable file');
    }
    processingState = ProcessingState.ready;
    states.add(PlayerState(playing, processingState));
    return const Duration(seconds: 30);
  }

  @override
  Future<void> play() async {
    playing = true;
    playCount++;
    states.add(PlayerState(playing, processingState));
  }

  @override
  Future<void> pause() async {
    playing = false;
    states.add(PlayerState(playing, processingState));
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    seeks.add(position);
    processingState = ProcessingState.ready;
    positions.add(position ?? Duration.zero);
    states.add(PlayerState(playing, processingState));
  }

  @override
  Future<void> dispose() async {
    await states.close();
    await positions.close();
    await durations.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakePlayer player;
  late AudioPlayerController controller;

  Future<void> open(WidgetTester tester, {int count = 3, int start = 0}) async {
    player = _FakePlayer();
    controller = AudioPlayerController(
      queue: <PlayerTrack>[
        for (int i = 0; i < count; i++)
          PlayerTrack(path: '/music/$i.mp3', title: 'Song $i'),
      ],
      startIndex: start,
      player: player,
    );
    controller.onInit();
    addTearDown(controller.onClose);
    await tester.pump();
  }

  Future<void> play(WidgetTester tester) async {
    await controller.togglePlay();
    await tester.pump();
  }

  testWidgets('finishing a song loads and plays the next song automatically', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await play(tester);

    player.finish();
    await tester.pump();

    expect(controller.title, 'Song 1');
    expect(player.loaded.last.path, '/music/1.mp3');
    expect(player.playCount, 2);
    expect(controller.isPlaying.value, isTrue);
    expect(controller.position.value, Duration.zero);

    player.finish();
    await tester.pump();

    expect(controller.title, 'Song 2');
    expect(player.playCount, 3);
  });

  testWidgets('repeated completion events advance only one track', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await play(tester);

    player.finish();
    player.finish();
    await tester.pump();

    expect(controller.index.value, 1);
    expect(player.loaded, hasLength(2));
    expect(player.playCount, 2);
  });

  for (final int count in <int>[1, 3]) {
    testWidgets('the last song in a queue of $count stops and can replay', (
      WidgetTester tester,
    ) async {
      await open(tester, count: count, start: count - 1);
      await play(tester);

      player.finish();
      await tester.pump();

      expect(controller.index.value, count - 1);
      expect(controller.isPlaying.value, isFalse);
      expect(player.playing, isFalse);
      expect(player.seeks.last, Duration.zero);
      expect(player.loaded, hasLength(1));

      await play(tester);
      expect(controller.isPlaying.value, isTrue);
      expect(player.playCount, 2);
    });
  }

  testWidgets('manual next preserves both paused and playing states', (
    WidgetTester tester,
  ) async {
    await open(tester);

    await controller.next();
    await tester.pump();
    expect(controller.index.value, 1);
    expect(player.playing, isFalse);

    await play(tester);
    await controller.next();
    await tester.pump();
    expect(controller.index.value, 2);
    expect(player.playing, isTrue);
  });

  testWidgets('a paused completion event does not start another song', (
    WidgetTester tester,
  ) async {
    await open(tester);

    player.finish();
    await tester.pump();

    expect(controller.index.value, 0);
    expect(player.playCount, 0);
  });

  testWidgets('an unreadable next song reports an error and stays stopped', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await play(tester);
    player.failLoad = true;

    player.finish();
    await tester.pump();

    expect(controller.index.value, 1);
    expect(controller.errorMessage.value, isNotEmpty);
    expect(controller.isPlaying.value, isFalse);
    expect(player.playCount, 1);
  });
}
