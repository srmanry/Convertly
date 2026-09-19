import 'dart:io';

import 'privacy_policy_html.dart';

/// Rewrites docs/privacy-policy.html from the wording in
/// lib/core/legal/privacy_policy.dart.
///
///     dart run tool/generate_privacy_policy.dart
void main() {
  File('docs/privacy-policy.html').writeAsStringSync(privacyPolicyHtml());
  stdout.writeln('Wrote docs/privacy-policy.html');
}
