import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/features/converter/domain/entities/volume_envelope.dart';
import 'package:convertly/features/converter/presentation/widgets/volume_lane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VolumeEnvelope', () {
    test('a fresh shape leaves every point at the resting level', () {
      final VolumeEnvelope flat = VolumeEnvelope.flat;

      expect(flat.levels, hasLength(VolumeEnvelope.resolution));
      expect(flat.levels, everyElement(VolumeEnvelope.unity));
      expect(flat.isFlat, isTrue);
    });

    test('moving one point makes the shape count', () {
      final VolumeEnvelope shaped = VolumeEnvelope.flat.withLevelAt(10, 0.3);

      expect(shaped.isFlat, isFalse);
      expect(shaped.levelAt(10), 0.3);
      // Its neighbours are untouched: one touch moves one point.
      expect(shaped.levelAt(9), VolumeEnvelope.unity);
    });

    test('a point cannot be pushed past the loudest allowed', () {
      expect(
        VolumeEnvelope.flat.withLevelAt(0, 9).levelAt(0),
        VolumeEnvelope.maxLevel,
      );
      expect(VolumeEnvelope.flat.withLevelAt(0, -3).levelAt(0), 0);
    });

    test('a point outside the shape is ignored rather than added', () {
      final VolumeEnvelope flat = VolumeEnvelope.flat;

      expect(flat.withLevelAt(999, 0.5), flat);
      expect(flat.withLevelAt(-1, 0.5), flat);
    });

    test('changing a point leaves the original alone', () {
      final VolumeEnvelope original = VolumeEnvelope.flat;

      original.withLevelAt(5, 0.1);

      expect(original.levelAt(5), VolumeEnvelope.unity);
    });
  });

  group('VolumeLane', () {
    late List<(int, double)> changes;

    Future<void> pumpLane(WidgetTester tester, {double widthFactor = 1}) async {
      changes = <(int, double)>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: VolumeLane(
                envelope: VolumeEnvelope.flat,
                widthFactor: widthFactor,
                onPointChanged: (int point, double level) =>
                    changes.add((point, level)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('touching near the top asks for a louder point', (
      WidgetTester tester,
    ) async {
      await pumpLane(tester);
      final Rect lane = tester.getRect(find.byType(CustomPaint).last);

      await tester.tapAt(Offset(lane.center.dx, lane.top + 4));
      await tester.pumpAndSettle();

      expect(changes, isNotEmpty);
      expect(changes.last.$2, greaterThan(VolumeEnvelope.unity));
    });

    testWidgets('touching near the bottom asks for a quieter point', (
      WidgetTester tester,
    ) async {
      await pumpLane(tester);
      final Rect lane = tester.getRect(find.byType(CustomPaint).last);

      await tester.tapAt(Offset(lane.center.dx, lane.bottom - 4));
      await tester.pumpAndSettle();

      expect(changes.last.$2, lessThan(VolumeEnvelope.unity));
    });

    testWidgets('dragging across draws through the points it passes', (
      WidgetTester tester,
    ) async {
      await pumpLane(tester);
      final Rect lane = tester.getRect(find.byType(CustomPaint).last);

      // One gesture has to shape a whole dip, not a single point, so the
      // drag is stepped the way a finger moving across the lane would be.
      final TestGesture gesture = await tester.startGesture(
        Offset(lane.left + 8, lane.center.dy),
      );
      for (int step = 0; step < 10; step++) {
        await gesture.moveBy(const Offset(25, -4));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      final Set<int> touched = changes.map((c) => c.$1).toSet();
      expect(touched.length, greaterThan(3));
    });

    testWidgets('a shorter track fills less of the row', (
      WidgetTester tester,
    ) async {
      await pumpLane(tester, widthFactor: 0.5);
      final Rect lane = tester.getRect(find.byType(CustomPaint).last);

      // Length has to be visible as length, not stretched to match the rest.
      expect(lane.width, closeTo(150, 2));
    });
  });
}
