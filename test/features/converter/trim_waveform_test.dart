import 'package:convertly/features/converter/presentation/widgets/trim_waveform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

const Duration kTotal = Duration(seconds: 100);

const double kWidth = 400;

/// The drawable track, once the waveform's end margins are taken off.
const double kTrack = kWidth - TrimWaveform.edgeInset * 2;

/// Where a moment in the track falls, in pixels from the widget's left edge.
double xFor(double seconds) =>
    TrimWaveform.edgeInset + seconds / kTotal.inSeconds * kTrack;

void main() {
  late Duration start;
  late Duration end;

  Future<void> pumpWaveform(
    WidgetTester tester, {
    Duration from = Duration.zero,
    Duration to = kTotal,
    List<double> peaks = const <double>[],
  }) async {
    start = from;
    end = to;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: kWidth,
              height: 100,
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return TrimWaveform(
                    peaks: peaks,
                    total: kTotal,
                    start: start,
                    end: end,
                    onChanged: (Duration s, Duration e) => setState(() {
                      start = s;
                      end = e;
                    }),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Drags from [fromSeconds] to [toSeconds] along the waveform.
  Future<void> dragFromTo(
    WidgetTester tester,
    double fromSeconds,
    double toSeconds,
  ) async {
    final Offset origin = tester.getTopLeft(find.byType(TrimWaveform));
    final TestGesture gesture = await tester.startGesture(
      origin + Offset(xFor(fromSeconds), 50),
    );
    await tester.pump();
    await gesture.moveTo(origin + Offset(xFor(toSeconds), 50));
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  testWidgets('dragging the left handle moves the start', (
    WidgetTester tester,
  ) async {
    await pumpWaveform(tester);

    await dragFromTo(tester, 0, 20);

    expect(start.inSeconds, 20);
    expect(end, kTotal, reason: 'the far handle must not follow');
  });

  testWidgets('dragging the right handle moves the end', (
    WidgetTester tester,
  ) async {
    await pumpWaveform(tester);

    await dragFromTo(tester, 100, 70);

    expect(end.inSeconds, 70);
    expect(start, Duration.zero);
  });

  testWidgets('the grab picks whichever handle is nearer', (
    WidgetTester tester,
  ) async {
    await pumpWaveform(
      tester,
      from: const Duration(seconds: 20),
      to: const Duration(seconds: 80),
    );

    // 25s is within reach of the start handle and far from the end one.
    await dragFromTo(tester, 25, 40);

    expect(start.inSeconds, 40);
    expect(end.inSeconds, 80);
  });

  testWidgets('a drag that starts away from both handles changes nothing', (
    WidgetTester tester,
  ) async {
    await pumpWaveform(
      tester,
      from: const Duration(seconds: 20),
      to: const Duration(seconds: 80),
    );

    // Mid-selection, well outside either grab radius.
    await dragFromTo(tester, 50, 60);

    expect(start.inSeconds, 20);
    expect(end.inSeconds, 80);
  });

  testWidgets('the start cannot be pushed through the end', (
    WidgetTester tester,
  ) async {
    await pumpWaveform(tester, to: const Duration(seconds: 30));

    await dragFromTo(tester, 0, 90);

    expect(
      start,
      const Duration(seconds: 30) - TrimWaveform.minimumSelection,
      reason: 'a selection always keeps the minimum length',
    );
    expect(end.inSeconds, 30);
  });

  testWidgets('the end cannot be pushed through the start', (
    WidgetTester tester,
  ) async {
    await pumpWaveform(tester, from: const Duration(seconds: 60));

    await dragFromTo(tester, 100, 10);

    expect(end, const Duration(seconds: 60) + TrimWaveform.minimumSelection);
    expect(start.inSeconds, 60);
  });

  testWidgets('dragging past the left edge clamps to the start of the track', (
    WidgetTester tester,
  ) async {
    await pumpWaveform(tester, from: const Duration(seconds: 30));

    await dragFromTo(tester, 30, -40);

    expect(start, Duration.zero);
  });

  testWidgets('dragging past the right edge clamps to the end of the track', (
    WidgetTester tester,
  ) async {
    await pumpWaveform(tester, to: const Duration(seconds: 70));

    await dragFromTo(tester, 70, 140);

    expect(end, kTotal);
  });

  testWidgets('a zero-length track does not crash or move the handles', (
    WidgetTester tester,
  ) async {
    start = Duration.zero;
    end = Duration.zero;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: kWidth,
            height: 100,
            child: TrimWaveform(
              peaks: const <double>[],
              total: Duration.zero,
              start: Duration.zero,
              end: Duration.zero,
              onChanged: (Duration s, Duration e) {
                start = s;
                end = e;
              },
            ),
          ),
        ),
      ),
    );

    await dragFromTo(tester, 0, 50);

    expect(start, Duration.zero);
    expect(end, Duration.zero);
  });

  testWidgets('renders with real peaks without overflowing', (
    WidgetTester tester,
  ) async {
    await pumpWaveform(
      tester,
      peaks: List<double>.generate(220, (int i) => (i % 10) / 10),
    );

    expect(tester.takeException(), isNull);
  });

  group('playback', () {
    testWidgets('the playhead sweeps on between position reports', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: kWidth,
              height: 100,
              child: TrimWaveform(
                peaks: List<double>.filled(60, 0.5),
                total: kTotal,
                start: Duration.zero,
                end: kTotal,
                playhead: const Duration(seconds: 10),
                isPlaying: true,
                onChanged: (Duration s, Duration e) {},
              ),
            ),
          ),
        ),
      );

      // Frames keep coming while the player stays quiet, which is the whole
      // point of the sweep.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
    });

    testWidgets('a playing waveform leaves no ticker behind', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: kWidth,
              height: 100,
              child: TrimWaveform(
                peaks: const <double>[],
                total: kTotal,
                start: Duration.zero,
                end: kTotal,
                playhead: Duration.zero,
                isPlaying: true,
                onChanged: (Duration s, Duration e) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Replacing the widget must dispose the ticker; a leaked one fails the
      // test rather than quietly burning frames in the app.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      expect(tester.takeException(), isNull);
    });

    testWidgets('a decoding track animates while it waits', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: kWidth,
              height: 100,
              child: TrimWaveform(
                peaks: const <double>[],
                isLoading: true,
                total: kTotal,
                start: Duration.zero,
                end: kTotal,
                onChanged: (Duration s, Duration e) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        tester.binding.hasScheduledFrame,
        isTrue,
        reason: 'the placeholder keeps asking for frames while it runs',
      );

      // Let it settle so the ticker does not outlive the test.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });

    testWidgets('the placeholder stops once the decode lands', (
      WidgetTester tester,
    ) async {
      Widget build({required bool loading, required List<double> peaks}) =>
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: kWidth,
                height: 100,
                child: TrimWaveform(
                  peaks: peaks,
                  isLoading: loading,
                  total: kTotal,
                  start: Duration.zero,
                  end: kTotal,
                  onChanged: (Duration s, Duration e) {},
                ),
              ),
            ),
          );

      await tester.pumpWidget(build(loading: true, peaks: const <double>[]));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(
        build(loading: false, peaks: List<double>.filled(40, 0.6)),
      );

      // pumpAndSettle would time out if the ticker were still running, so
      // this is what proves the animation actually stands down.
      await tester.pumpAndSettle();

      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('stopping playback puts the sweep away', (
      WidgetTester tester,
    ) async {
      Widget build({required bool playing}) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: kWidth,
            height: 100,
            child: TrimWaveform(
              peaks: List<double>.filled(60, 0.5),
              total: kTotal,
              start: Duration.zero,
              end: kTotal,
              playhead: playing ? const Duration(seconds: 10) : null,
              isPlaying: playing,
              onChanged: (Duration s, Duration e) {},
            ),
          ),
        ),
      );

      await tester.pumpWidget(build(playing: true));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(build(playing: false));
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('screen readers can move each handle', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await pumpWaveform(
      tester,
      from: const Duration(seconds: 20),
      to: const Duration(seconds: 80),
    );

    tester.semantics.performAction(
      find.semantics.byLabel('Selection start'),
      SemanticsAction.increase,
    );
    await tester.pump();

    expect(
      start.inSeconds,
      greaterThan(20),
      reason: 'increase must move the start handle forward',
    );

    semantics.dispose();
  });
}
