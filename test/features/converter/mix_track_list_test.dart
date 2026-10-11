import 'package:convertly/core/theme/app_colors.dart';
import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/core/i18n/app_translations.dart';
import 'package:convertly/features/converter/domain/entities/media_info.dart';
import 'package:convertly/features/converter/domain/entities/volume_envelope.dart';
import 'package:convertly/features/converter/presentation/widgets/mix_track_list.dart';
import 'package:convertly/features/converter/presentation/widgets/source_summary_card.dart';
import 'package:convertly/features/converter/presentation/widgets/volume_lane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

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
  late List<int> previewed;
  late int? removed;

  tearDown(Get.reset);

  /// [playingTrack] is the track being heard on its own, if any.
  Future<void> pumpMixer(WidgetTester tester, {int? playingTrack}) async {
    previewed = <int>[];
    removed = null;
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ValueNotifier<double?> playhead = ValueNotifier<double?>(
      playingTrack != null ? 0.4 : null,
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
                      previewingTrack: playingTrack,
                      onTrackPreview: previewed.add,
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

  testWidgets('each track asks for itself, not for the whole mix', (
    WidgetTester tester,
  ) async {
    await pumpMixer(tester);

    await tester.tap(find.text('Preview').at(1));
    await tester.pump();

    // The second card asked about the second track. Pressing one track's
    // button used to start every track at once, which made the per-track
    // buttons and the Preview all button do the same thing.
    expect(previewed, <int>[1]);
  });

  testWidgets('only the track being heard shows Stop', (
    WidgetTester tester,
  ) async {
    await pumpMixer(tester, playingTrack: 1);

    expect(tester.takeException(), isNull);
    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
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

  testWidgets('timeline rows are compact and use a clear play control', (
    WidgetTester tester,
  ) async {
    const String longName =
        'A very long timeline track name that should stay on one line';
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark,
        translations: AppTranslations(),
        locale: const Locale('en'),
        home: Scaffold(
          body: MixTrackList(
            sources: <MediaInfo>[_track(longName, 90)],
            volumes: const <double>[1],
            starts: const <Duration>[Duration.zero],
            onVolumeChanged: null,
            showsPositions: true,
            trimRanges: const <(Duration, Duration)>[
              (Duration.zero, Duration(seconds: 90)),
            ],
            onTrimChanged: (_, _, _) {},
            onPreviewClip: (_) {},
            onRemove: (_) {},
            onReorder: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pump();

    final SourceSummaryCard summary = tester.widget<SourceSummaryCard>(
      find.byType(SourceSummaryCard),
    );
    final Text number = tester.widget<Text>(find.text('1'));

    expect(summary.titleMaxLines, 1);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
    expect(number.style?.color, Colors.white);
    expect(find.widgetWithText(FilledButton, 'Play'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
