import 'dart:io';

import 'package:convertly/core/legal/privacy_policy.dart';
import 'package:convertly/features/settings/presentation/pages/privacy_policy_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/privacy_policy_html.dart';

void main() {
  test('the web page matches the in-app wording', () {
    // Regenerate with: dart run tool/generate_privacy_policy.dart
    final String onDisk = File('docs/privacy-policy.html').readAsStringSync();

    expect(onDisk, privacyPolicyHtml());
  });

  test('the policy says what a reviewer looks for', () {
    final String text = <String>[
      ...PrivacyPolicy.introParagraphs,
      for (final PolicySection s in PrivacyPolicy.sections) ...<String>[
        s.title,
        ...s.paragraphs,
        ...s.bullets,
      ],
    ].join('\n').toLowerCase();

    // Ads, the advertising id, children, and where files go are what the
    // store's data-safety review checks the policy against.
    expect(text, contains('admob'));
    expect(text, contains('advertising id'));
    expect(text, contains('children'));
    expect(text, contains('never uploaded'));
    expect(text, contains('policies.google.com'));
    expect(PrivacyPolicy.sections, hasLength(11));
    expect(PrivacyPolicy.lastUpdatedDate, 'September 3, 2026');
  });

  testWidgets('the page shows every section', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyPage()));

    for (final PolicySection section in PrivacyPolicy.sections) {
      expect(find.text(section.title), findsOneWidget);
    }
  });
}
