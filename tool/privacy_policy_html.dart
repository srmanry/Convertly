import 'package:convertly/core/legal/privacy_policy.dart';

/// The privacy policy as a standalone web page, for hosting and for the
/// store listing's privacy policy link.
String privacyPolicyHtml() {
  final StringBuffer out = StringBuffer()
    ..writeln('<!doctype html>')
    ..writeln('<html lang="en">')
    ..writeln('<head>')
    ..writeln('<meta charset="utf-8">')
    ..writeln(
      '<meta name="viewport" content="width=device-width, initial-scale=1">',
    )
    ..writeln('<title>${_e(PrivacyPolicy.appName)} Privacy Policy</title>')
    ..writeln('<style>')
    ..writeln(
      'body{font:16px/1.6 system-ui,sans-serif;max-width:42rem;'
      'margin:2rem auto;padding:0 1rem;color:#1c1b1f}',
    )
    ..writeln('h1{font-size:1.6rem}h2{font-size:1.15rem;margin-top:2rem}')
    ..writeln('.date{color:#666}')
    ..writeln('</style>')
    ..writeln('</head>')
    ..writeln('<body>')
    ..writeln('<h1>${_e(PrivacyPolicy.appName)} Privacy Policy</h1>')
    ..writeln('<p class="date">Effective ${_e(PrivacyPolicy.effectiveDate)}</p>')
    ..writeln('<p>${_link(PrivacyPolicy.intro)}</p>');

  for (final PolicySection section in PrivacyPolicy.sections) {
    out.writeln('<h2>${_e(section.title)}</h2>');
    for (final String paragraph in section.paragraphs) {
      out.writeln('<p>${_link(paragraph)}</p>');
    }
  }

  if (PrivacyPolicy.contactEmail.isNotEmpty) {
    out
      ..writeln('<h2>Contact</h2>')
      ..writeln(
        '<p>Questions about this policy: '
        '<a href="mailto:${_e(PrivacyPolicy.contactEmail)}">'
        '${_e(PrivacyPolicy.contactEmail)}</a></p>',
      );
  }

  out
    ..writeln('</body>')
    ..writeln('</html>');
  return out.toString();
}

String _e(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Escapes [text] and turns bare web addresses into links.
String _link(String text) => _e(text).replaceAllMapped(
  RegExp(r'https://[^\s<]+?(?=[.,]?(?:\s|$))'),
  (Match m) => '<a href="${m[0]}">${m[0]}</a>',
);
