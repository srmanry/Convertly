import 'dart:async';

import 'package:convertly/core/widgets/app_logo.dart';
import 'package:convertly/core/widgets/app_startup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Widget home = MaterialApp(home: Scaffold(body: Text('Home ready')));

  testWidgets('draws immediately and opens home without a minimum delay', (
    WidgetTester tester,
  ) async {
    final Completer<void> initialization = Completer<void>();
    await tester.pumpWidget(
      AppStartup(initialize: () => initialization.future, ready: home),
    );
    expect(find.byType(AppLogo), findsOneWidget);

    initialization.complete();
    await tester.pumpAndSettle();
    expect(find.text('Home ready'), findsOneWidget);
    expect(find.byType(AppLogo), findsNothing);
  });

  testWidgets('the app is built once and never torn down by the reveal', (
    WidgetTester tester,
  ) async {
    _CountingAppState.builds = 0;
    // The reported bug: the app froze just after the splash. The logo had
    // been returning the app to a different place in the tree once it
    // finished, which destroys it and builds it again — and with it the
    // router and every registered controller.
    final Completer<void> initialization = Completer<void>();
    await tester.pumpWidget(
      AppStartup(
        initialize: () => initialization.future,
        ready: const _CountingApp(),
      ),
    );

    initialization.complete();
    await tester.pump();
    await tester.pump(AppStartup.minimumShow + const Duration(seconds: 1));
    await tester.pump();
    await tester.pump();
    expect(_CountingAppState.builds, 1);

    await tester.pumpAndSettle();
    expect(find.text('App alive'), findsOneWidget);
    expect(_CountingAppState.builds, 1);
  });

  testWidgets('the logo clears away and leaves nothing over the app', (
    WidgetTester tester,
  ) async {
    final Completer<void> initialization = Completer<void>();
    await tester.pumpWidget(
      AppStartup(initialize: () => initialization.future, ready: home),
    );

    initialization.complete();
    await tester.pump();
    // Past the hold with a little to spare, then one frame for the build it
    // releases and another for the reveal that build starts.
    await tester.pump(AppStartup.minimumShow + const Duration(seconds: 1));
    await tester.pump();
    await tester.pump();

    // Mid-flight the app is already there, with the logo on its way out over
    // the top of it.
    await tester.pump(AppStartup.revealDuration ~/ 2);
    expect(find.text('Home ready'), findsOneWidget);
    expect(find.byType(AppLogo), findsOneWidget);

    // Once it is done the logo is gone from the tree, not merely invisible:
    // a transparent layer left behind would swallow the first tap.
    await tester.pumpAndSettle();
    expect(find.text('Home ready'), findsOneWidget);
    expect(find.byType(AppLogo), findsNothing);
  });

  testWidgets('a slow start is waited out, and retry reuses the pending work', (
    WidgetTester tester,
  ) async {
    final Completer<void> initialization = Completer<void>();
    int attempts = 0;
    await tester.pumpWidget(
      AppStartup(
        initialize: () {
          attempts++;
          return initialization.future;
        },
        ready: home,
      ),
    );

    // Five seconds used to be the whole budget. Startup alone measured
    // around four on a mid-range phone, so a slow one was shown an error
    // while its app was still opening normally.
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Try Again'), findsNothing);

    await tester.pump(AppStartup.maximumShow - const Duration(seconds: 10));
    expect(find.text('Try Again'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pump();
    expect(attempts, 1);

    initialization.complete();
    await tester.pump();
    // A delay schedules no frames, so pumpAndSettle cannot walk past the
    // hold on its own; the clock is advanced explicitly.
    await tester.pump(AppStartup.minimumShow);
    await tester.pumpAndSettle();
    expect(find.text('Home ready'), findsOneWidget);
  });

  testWidgets('an initialization failure can be retried successfully', (
    WidgetTester tester,
  ) async {
    int attempts = 0;
    await tester.pumpWidget(
      AppStartup(
        initialize: () async {
          if (++attempts == 1) {
            throw StateError('Storage unavailable');
          }
        },
        ready: home,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try Again'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pump();
    await tester.pump(AppStartup.minimumShow);
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Home ready'), findsOneWidget);
  });
}

/// Stands in for the real app, counting how often it is created from scratch.
class _CountingApp extends StatefulWidget {
  const _CountingApp();

  @override
  State<_CountingApp> createState() => _CountingAppState();
}

class _CountingAppState extends State<_CountingApp> {
  static int builds = 0;

  @override
  void initState() {
    super.initState();
    builds++;
  }

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(home: Scaffold(body: Text('App alive')));
}
