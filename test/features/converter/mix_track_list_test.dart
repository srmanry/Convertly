import 'package:convertly/core/theme/app_colors.dart';
import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/features/converter/domain/entities/media_info.dart';
import 'package:convertly/features/converter/domain/entities/volume_envelope.dart';
import 'package:convertly/features/converter/presentation/widgets/mix_track_list.dart';
import 'package:convertly/features/converter/presentation/widgets/volume_lane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MediaInfo _track(String name, int seconds) => MediaInfo(
  path: '/music/$name.mp3',
  name: '$name.mp3',
  sizeInBytes: 1000,
  extension: 'mp3',
  hasAudio: true,
  hasVideo: false,
  duration: Duration(seconds: seconds),
);

void main() {
  late int toggles;
  late int? removed;

  Future<void> pumpMixer(WidgetTester tester, {bool playing = false}) async {
    toggles = 0;
    removed = null;
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ValueNotifier<double?> playhead = ValueNotifier<double?>(
      playing ? 0.4 : null,
    );
    addTearDown(playhead.dispose);

    // Laid out the way the converter page lays it out, in the real theme:
    // a scrolling list above a pinned button.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    MixTrackList(
                      sources: <MediaInfo>[_track('a', 285), _track('b', 96)],
                      volumes: const <double>[1, 0.6],
                      starts: const <Duration>[Duration.zero, Duration.zero],
                      onVolumeChanged: (_, _) {},
                      envelopes: <VolumeEnvelope>[
                        VolumeEnvelope.fadeIn(),
                        VolumeEnvelope.flat,
                      ],
                      onEnvelopeChanged: (_, _) {},
                      onEnvelopeCleared: (_) {},
                      playheadOf: (_) => playhead,
                      isPreviewPlaying: playing,
                      onPreviewToggle: () => toggles++,
                      onRemove: (int i) => removed = i,
                      onReorder: (_, _) {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('every track shows its volume line in the app theme', (
    WidgetTester tester,
  ) async {
    await pumpMixer(tester);

    // The theme makes filled buttons full width; one in a row with a title
    // used to throw during layout and leave the whole mixer blank.
    expect(tester.takeException(), isNull);
    expect(find.byType(VolumeLane), findsNWidgets(2));
    // Each card names the track's role and shows its place in the mix. The
    // role already says which track this is, so no number is repeated
    // alongside it.
    expect(find.text('Main track'), findsOneWidget);
    expect(find.text('Layer 2'), findsOneWidget);
    expect(find.text('1'), findsNothing);
    expect(find.text('2'), findsNothing);
  });

  testWidgets('remove sits at the card corner, clear of Preview and Reset', (
    WidgetTester tester,
  ) async {
    await pumpMixer(tester);

    await tester.tap(find.byTooltip('Remove').first);
    await tester.pump();

    expect(removed, 0);
  });

  testWidgets('the Preview button beside a lane starts the preview', (
    WidgetTester tester,
  ) async {
    await pumpMixer(tester);

    await tester.tap(find.text('Preview').first);
    await tester.pump();

    expect(toggles, 1);
  });

  testWidgets('a playing preview offers Stop and draws without error', (
    WidgetTester tester,
  ) async {
    await pumpMixer(tester, playing: true);

    expect(tester.takeException(), isNull);
    expect(find.text('Stop'), findsNWidgets(2));
  });

  testWidgets('a shaped track offers a reset, a flat one does not', (
    WidgetTester tester,
  ) async {
    await pumpMixer(tester);

    expect(find.byTooltip('Reset to 100%'), findsOneWidget);
  });

  testWidgets('a selected point shows its controls without error', (
    WidgetTester tester,
  ) async {
    await pumpMixer(tester);
    final Rect lane = tester.getRect(
      find
          .descendant(
            of: find.byType(VolumeLane).first,
            matching: find.byType(CustomPaint),
          )
          .first,
    );

    // The fade-in's last point sits at 100% on the right-hand end.
    await tester.tapAt(
      Offset(lane.right - VolumeLane.padRight, lane.center.dy),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Louder'), findsOneWidget);
    expect(find.byTooltip('Quieter'), findsOneWidget);
  });

  testWidgets('each track reads as its own colour, cycled from the app '
      "palette", (WidgetTester tester) async {
    await pumpMixer(tester);

    final List<Color> colors = tester
        .widgetList<VolumeLane>(find.byType(VolumeLane))
        .map((VolumeLane lane) => lane.accent)
        .whereType<Color>()
        .toList();

    expect(colors, hasLength(2));
    expect(colors[0], AppColors.mixTrackAccents[0]);
    expect(colors[1], AppColors.mixTrackAccents[1]);
    expect(colors[0], isNot(colors[1]));
  });
}
