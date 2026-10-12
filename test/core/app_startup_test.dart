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

    await tester.pump(AppStartup.maximumWait - const Duration(seconds: 10));
    expect(find.text('Try Again'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    await tester.pump();
    expect(attempts, 1);

    initialization.complete();
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
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Home ready'), findsOneWidget);
  });
}
