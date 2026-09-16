import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/features/converter/domain/entities/volume_envelope.dart';
import 'package:convertly/features/converter/presentation/widgets/volume_lane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VolumeEnvelope', () {
    test('a fresh shape is two resting points and changes nothing', () {
      const VolumeEnvelope flat = VolumeEnvelope.flat;

      expect(flat.points, hasLength(2));
      expect(flat.points.first.position, 0);
      expect(flat.points.last.position, 1);
      expect(flat.isFlat, isTrue);
    });

    test('adding a point in the middle keeps the points in order', () {
      final (VolumeEnvelope shaped, int? index) = VolumeEnvelope.flat
          .withPointAdded(0.4, 0.3);

      expect(index, 1);
      expect(shaped.points.map((EnvelopePoint p) => p.position), <double>[
        0,
        0.4,
        1,
      ]);
      expect(shaped.isFlat, isFalse);
    });

    test('a point is not added on top of another one', () {
      final (VolumeEnvelope once, _) = VolumeEnvelope.flat.withPointAdded(
        0.5,
        0.3,
      );

      final (VolumeEnvelope twice, int? index) = once.withPointAdded(
        0.505,
        0.8,
      );

      expect(index, isNull);
      expect(twice, once);
    });

    test('a track holds only so many points', () {
      VolumeEnvelope shape = VolumeEnvelope.flat;
      for (int i = 1; i < 40; i++) {
        (shape, _) = shape.withPointAdded(i / 40, 0.5);
      }

      expect(shape.points, hasLength(VolumeEnvelope.maxPoints));
      expect(shape.canAddPoint, isFalse);
    });

    test('a dragged point stays between its neighbours', () {
      final VolumeEnvelope shape = VolumeEnvelope(const <EnvelopePoint>[
        EnvelopePoint(0, 1),
        EnvelopePoint(0.3, 1),
        EnvelopePoint(0.6, 1),
        EnvelopePoint(1, 1),
      ]);

      final VolumeEnvelope moved = shape.withPointMoved(1, 0.9, 0.5);

      expect(moved.points[1].position, lessThan(0.6));
      expect(moved.points[1].level, 0.5);
    });

    test('the end points only move up and down', () {
      final VolumeEnvelope moved = VolumeEnvelope.flat
          .withPointMoved(0, 0.5, 0.2)
          .withPointMoved(1, 0.2, 1.5);

      expect(moved.points.first, const EnvelopePoint(0, 0.2));
      expect(moved.points.last, const EnvelopePoint(1, 1.5));
    });

    test('a level cannot go past the loudest or below silence', () {
      final VolumeEnvelope moved = VolumeEnvelope.flat
          .withPointMoved(0, 0, 9)
          .withPointMoved(1, 1, -3);

      expect(moved.points.first.level, VolumeEnvelope.maxLevel);
      expect(moved.points.last.level, 0);
    });

    test('middle points can be removed, the ends cannot', () {
      final (VolumeEnvelope shaped, _) = VolumeEnvelope.flat.withPointAdded(
        0.5,
        0.2,
      );

      expect(shaped.withPointRemoved(1), VolumeEnvelope.flat);
      expect(shaped.withPointRemoved(0), shaped);
      expect(shaped.withPointRemoved(2), shaped);
    });

    test('the level eases between points without overshooting', () {
      final VolumeEnvelope ramp = VolumeEnvelope(const <EnvelopePoint>[
        EnvelopePoint(0, 0),
        EnvelopePoint(1, 1),
      ]);

      expect(ramp.levelAt(0), 0);
      expect(ramp.levelAt(0.5), closeTo(0.5, 0.0001));
      expect(ramp.levelAt(1), 1);
      // Slow at the start, like a fade should be.
      expect(ramp.levelAt(0.1), lessThan(0.1));
      for (int i = 0; i <= 100; i++) {
        expect(ramp.levelAt(i / 100), inInclusiveRange(0, 1));
      }
    });

    test('the fades start and end where their names say', () {
      final VolumeEnvelope fadeIn = VolumeEnvelope.fadeIn();
      final VolumeEnvelope fadeOut = VolumeEnvelope.fadeOut();

      expect(fadeIn.levelAt(0), 0);
      expect(fadeIn.levelAt(1), VolumeEnvelope.unity);
      expect(fadeOut.levelAt(0), VolumeEnvelope.unity);
      expect(fadeOut.levelAt(1), 0);
      expect(VolumeEnvelope.dip().levelAt(0.5), lessThan(VolumeEnvelope.unity));
    });

    test('changing a shape leaves the original alone', () {
      const VolumeEnvelope original = VolumeEnvelope.flat;

      original.withPointAdded(0.5, 0.1);
      original.withPointMoved(0, 0, 0.1);

      expect(original.points, hasLength(2));
      expect(original.isFlat, isTrue);
    });
  });

  group('VolumeLane', () {
    late VolumeEnvelope current;
    late int changes;

    Widget lane({Widget Function(Widget)? wrap}) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final Widget child = VolumeLane(
            envelope: current,
            length: const Duration(seconds: 100),
            onChanged: (VolumeEnvelope next) => setState(() {
              current = next;
              changes++;
            }),
          );
          return wrap == null ? child : wrap(child);
        },
      );
    }

    Future<void> pump(
      WidgetTester tester, {
      VolumeEnvelope envelope = VolumeEnvelope.flat,
      Widget Function(Widget)? wrap,
    }) async {
      current = envelope;
      changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SizedBox(
              width: 332,
              child: wrap == null
                  ? SingleChildScrollView(child: lane())
                  : lane(wrap: wrap),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// The drawing area inside the lane, matching its padding.
    Rect areaOf(WidgetTester tester) {
      // The lane is the first painter inside it; the chips below have their own.
      final Rect box = tester.getRect(
        find
            .descendant(
              of: find.byType(VolumeLane),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      return Rect.fromLTRB(
        box.left + VolumeLane.padLeft,
        box.top + VolumeLane.padY,
        box.right - VolumeLane.padRight,
        box.bottom - VolumeLane.padY,
      );
    }

    testWidgets('tapping the lane adds a point there', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      final Rect area = areaOf(tester);

      await tester.tapAt(Offset(area.center.dx, area.bottom - 10));
      await tester.pumpAndSettle();

      expect(current.points, hasLength(3));
      expect(current.points[1].position, closeTo(0.5, 0.02));
      expect(current.points[1].level, lessThan(VolumeEnvelope.unity));
      // The new point is selected, so it can be deleted straight away.
      expect(find.byTooltip('Delete point'), findsOneWidget);
    });

    testWidgets('dragging a point up makes it louder', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        envelope: VolumeEnvelope(const <EnvelopePoint>[
          EnvelopePoint(0, 1),
          EnvelopePoint(0.5, 1),
          EnvelopePoint(1, 1),
        ]),
      );
      final Rect area = areaOf(tester);
      final Offset point = Offset(area.center.dx, area.center.dy);

      final TestGesture gesture = await tester.startGesture(point);
      for (int step = 0; step < 8; step++) {
        await gesture.moveBy(const Offset(0, -5));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(current.points[1].level, greaterThan(VolumeEnvelope.unity));
      expect(current.points, hasLength(3));
    });

    testWidgets('scrolling past the lane does not change the shape', (
      WidgetTester tester,
    ) async {
      final ScrollController scroll = ScrollController();
      addTearDown(scroll.dispose);
      await pump(
        tester,
        wrap: (Widget child) => SizedBox(
          height: 400,
          child: ListView(
            controller: scroll,
            children: <Widget>[child, const SizedBox(height: 1000)],
          ),
        ),
      );
      final Rect area = areaOf(tester);

      // Away from both end points, which is where a thumb scrolls.
      await tester.dragFrom(
        Offset(area.center.dx, area.center.dy + 20),
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();

      expect(changes, 0);
      expect(scroll.offset, greaterThan(0));
    });

    testWidgets('a selected point can be deleted', (WidgetTester tester) async {
      await pump(tester);
      final Rect area = areaOf(tester);
      await tester.tapAt(Offset(area.center.dx, area.top + 10));
      await tester.pumpAndSettle();
      expect(current.points, hasLength(3));

      await tester.tap(find.byTooltip('Delete point'));
      await tester.pumpAndSettle();

      expect(current.points, hasLength(2));
      expect(find.byTooltip('Delete point'), findsNothing);
    });

    testWidgets('the ends cannot be deleted', (WidgetTester tester) async {
      await pump(tester);
      final Rect area = areaOf(tester);

      // Press and release on the start point selects it.
      await tester.tapAt(Offset(area.left, area.center.dy));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Delete point'), findsNothing);
      expect(current.points, hasLength(2));
    });

    testWidgets('the + and − buttons step a point by 5%', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        envelope: VolumeEnvelope(const <EnvelopePoint>[
          EnvelopePoint(0, 1),
          EnvelopePoint(0.5, 0.4),
          EnvelopePoint(1, 1),
        ]),
      );
      final Rect area = areaOf(tester);
      // 40% sits at a fifth of the way up the lane.
      await tester.tapAt(
        Offset(area.center.dx, area.bottom - area.height * 0.2),
      );
      await tester.pumpAndSettle();
      expect(find.text('40%'), findsWidgets);

      await tester.tap(find.byTooltip('Louder'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Louder'));
      await tester.pumpAndSettle();
      expect(current.points[1].level, closeTo(0.5, 0.0001));

      await tester.tap(find.byTooltip('Quieter'));
      await tester.pumpAndSettle();
      expect(current.points[1].level, closeTo(0.45, 0.0001));
      // Position is left alone: the buttons only change how loud.
      expect(current.points[1].position, 0.5);
    });

    testWidgets('tapping the selected point again lets it go', (
      WidgetTester tester,
    ) async {
      await pump(tester);
      final Rect area = areaOf(tester);
      final Offset start = Offset(area.left, area.center.dy);

      await tester.tapAt(start);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Louder'), findsOneWidget);

      await tester.tapAt(start);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Louder'), findsNothing);
      expect(
        find.textContaining('Tap the line to add a point'),
        findsOneWidget,
      );
    });

    testWidgets('the track length is written under the lane', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('1:40'), findsOneWidget);
    });
  });
}
