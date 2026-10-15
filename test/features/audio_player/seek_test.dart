import 'dart:async';

import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/features/audio_player/domain/entities/player_track.dart';
import 'package:convertly/features/audio_player/presentation/controllers/audio_player_controller.dart';
import 'package:convertly/features/audio_player/presentation/pages/audio_player_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

class _SeekPlayer implements AudioPlayer {
  final StreamController<Duration> positions =
      StreamController<Duration>.broadcast();
  final List<Duration?> seeks = <Duration?>[];
  final List<Uri> loaded = <Uri>[];
  Completer<void>? seekGate;

  @override
  Stream<Duration> get positionStream => positions.stream;
  @override
  Stream<Duration?> get durationStream => const Stream<Duration?>.empty();
  @override
  Stream<PlayerState> get playerStateStream =>
      const Stream<PlayerState>.empty();
  @override
  bool get playing => false;

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    loaded.add((source as UriAudioSource).uri);
    return const Duration(minutes: 4);
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    seeks.add(position);
    await seekGate?.future;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> dispose() => positions.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _SeekPlayer player;
  late AudioPlayerController controller;

  Future<void> open(WidgetTester tester, {bool showPage = false}) async {
    player = _SeekPlayer();
    controller = AudioPlayerController(
      queue: const <PlayerTrack>[
        PlayerTrack(path: '/music/a.mp3', title: 'A'),
        PlayerTrack(path: '/music/b.mp3', title: 'B'),
      ],
      player: player,
      resolvePath: (String path) async => path,
    );
    if (showPage) {
      Get.put(controller);
      addTearDown(Get.reset);
      await tester.pumpWidget(
        GetMaterialApp(theme: AppTheme.dark, home: const AudioPlayerPage()),
      );
    } else {
      controller.onInit();
      addTearDown(controller.onClose);
    }
    await tester.pump();
  }

  testWidgets('old playback updates cannot pull back an in-flight seek', (
    WidgetTester tester,
  ) async {
    await open(tester);
    player.seekGate = Completer<void>();
    final Future<void> seek = controller.seek(const Duration(seconds: 90));
    expect(controller.position.value, const Duration(seconds: 90));

    player.positions.add(const Duration(seconds: 4));
    await tester.pump();
    expect(controller.position.value, const Duration(seconds: 90));

    player.seekGate!.complete();
    await seek;
    player.positions.add(const Duration(seconds: 91));
    await tester.pump();
    expect(controller.position.value, const Duration(seconds: 91));
  });

  testWidgets('rapid taps serialize seeks and keep only the latest target', (
    WidgetTester tester,
  ) async {
    await open(tester);
    player.seekGate = Completer<void>();
    final Future<void> first = controller.seek(const Duration(seconds: 60));
    final Future<void> middle = controller.seek(const Duration(seconds: 80));
    final Future<void> last = controller.seek(const Duration(seconds: 100));
    expect(player.seeks, <Duration>[const Duration(seconds: 60)]);
    expect(controller.position.value, const Duration(seconds: 100));

    player.seekGate!.complete();
    await Future.wait(<Future<void>>[first, middle, last]);
    expect(player.seeks, <Duration>[
      const Duration(seconds: 60),
      const Duration(seconds: 100),
    ]);
    expect(controller.position.value, const Duration(seconds: 100));
  });

  testWidgets('changing tracks waits for the previous seek to finish', (
    WidgetTester tester,
  ) async {
    await open(tester);
    player.seekGate = Completer<void>();
    final Future<void> seek = controller.seek(const Duration(seconds: 60));
    final Future<void> next = controller.next();
    await tester.pump();
    expect(player.loaded, hasLength(1));

    player.seekGate!.complete();
    await Future.wait(<Future<void>>[seek, next]);
    expect(controller.index.value, 1);
    expect(controller.position.value, Duration.zero);
  });

  testWidgets(
    'drag follows the finger despite playback updates, seeking once',
    (WidgetTester tester) async {
      await open(tester, showPage: true);
      final Finder slider = find.byType(Slider);
      final Rect bounds = tester.getRect(slider);
      final TestGesture gesture = await tester.startGesture(
        Offset(bounds.left + 30, bounds.center.dy),
      );
      await gesture.moveTo(Offset(bounds.center.dx, bounds.center.dy));
      await tester.pump();
      final double draggedValue = tester.widget<Slider>(slider).value;
      expect(draggedValue, greaterThan(60000));
      expect(player.seeks, isEmpty);

      player.positions.add(const Duration(seconds: 5));
      await tester.pump();
      expect(tester.widget<Slider>(slider).value, draggedValue);

      await gesture.up();
      await tester.pump();
      expect(player.seeks, <Duration>[
        Duration(milliseconds: draggedValue.round()),
      ]);
      expect(tester.widget<Slider>(slider).value, closeTo(draggedValue, 1));
    },
  );

  testWidgets('tapping the seek bar moves immediately without snapping back', (
    WidgetTester tester,
  ) async {
    await open(tester, showPage: true);
    player.seekGate = Completer<void>();
    final Finder slider = find.byType(Slider);
    await tester.tapAt(tester.getCenter(slider));
    await tester.pump();
    final double tappedValue = tester.widget<Slider>(slider).value;
    expect(tappedValue, greaterThan(60000));
    expect(player.seeks, hasLength(1));

    player.positions.add(const Duration(seconds: 4));
    await tester.pump();
    expect(tester.widget<Slider>(slider).value, tappedValue);
    player.seekGate!.complete();
    await tester.pump();
  });
}
