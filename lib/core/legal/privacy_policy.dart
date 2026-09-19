/// The privacy policy, as plain data.
///
/// Kept free of Flutter so one text feeds both the in-app page and the web
/// page generated for the store listing (`tool/generate_privacy_policy.dart`).
/// Edit the words here, then regenerate the web page; a test fails if the two
/// drift apart.
abstract final class PrivacyPolicy {
  static const String appName = 'AudioForge';

  /// When this wording took effect. Change it whenever the text changes.
  static const String effectiveDate = 'September 19, 2026';

  /// Where questions go. Left empty on purpose: the contact section is then
  /// left out, and people reach the developer through the email address on
  /// the store listing instead.
  static const String contactEmail = '';

  static const String intro =
      '$appName is a media converter and audio toolkit. This policy explains '
      'what the app does and does not do with your information. In short: '
      'there is no account, your files never leave your phone, and the only '
      'outside service is Google AdMob, which shows the ads.';

  static const List<PolicySection> sections = <PolicySection>[
    PolicySection(
      title: 'Information we do not collect',
      paragraphs: <String>[
        'We do not ask you to sign up or log in. We do not collect your name, '
            'email address, phone number, contacts or location, and we do not '
            'run our own servers that receive anything from the app.',
      ],
    ),
    PolicySection(
      title: 'Your files',
      paragraphs: <String>[
        'Audio and video files you choose are converted, cut, merged, mixed '
            'or cleaned entirely on your device. They are never uploaded to '
            'us or to any other server.',
        'Finished files are saved in the app\'s own folder on your phone. If '
            'you tap "Save to phone", a copy is placed in Music / '
            '$appName. You can delete them yourself at any time, and '
            'uninstalling the app removes the copies kept in its own folder.',
      ],
    ),
    PolicySection(
      title: 'Permissions',
      paragraphs: <String>[
        'Music and audio (or "storage" on Android 12 and older) is used only '
            'so the Player tab can list the songs already on your phone. That '
            'list is read on the device and is not sent anywhere.',
        'Choosing a file to convert uses Android\'s own file picker and needs '
            'no permission from us.',
      ],
    ),
    PolicySection(
      title: 'Information kept on your device',
      paragraphs: <String>[
        'The app remembers your default format and quality, a list of the '
            'files it has converted, and how many ad-free conversions you '
            'have left. This stays on your phone and is removed when you '
            'uninstall the app or clear its data.',
      ],
    ),
    PolicySection(
      title: 'Advertising',
      paragraphs: <String>[
        '$appName is free and shows ads through Google AdMob. To show and '
            'measure ads and to prevent fraud, AdMob may collect and use '
            'information such as your device\'s advertising ID, IP address, '
            'device and app details, and how you interact with an ad. Ads '
            'may be personalised or not, depending on your choices and '
            'where you live. We do not receive this information.',
        'You can watch an optional rewarded video to skip ads for a few '
            'conversions.',
        'To learn how Google uses data from apps that use its services, see '
            'https://policies.google.com/technologies/partner-sites and '
            'Google\'s Privacy Policy at https://policies.google.com/privacy. '
            'You can reset your advertising ID or turn off ad '
            'personalisation in your phone\'s Settings under Privacy > Ads.',
      ],
    ),
    PolicySection(
      title: 'Your choices in Europe and the UK',
      paragraphs: <String>[
        'If you are in the European Economic Area, the United Kingdom or '
            'Switzerland, the app shows a consent message from Google before '
            'any ads load. You can change your answer later from Settings > '
            'Ad privacy settings, which appears where the law requires it.',
      ],
    ),
    PolicySection(
      title: 'Children',
      paragraphs: <String>[
        '$appName is not directed to children under 13, and we do not '
            'knowingly collect information from children.',
      ],
    ),
    PolicySection(
      title: 'Changes to this policy',
      paragraphs: <String>[
        'If the app\'s handling of information changes, this page will be '
            'updated and the date above changed.',
      ],
    ),
  ];
}

/// One headed part of the policy.
class PolicySection {
  const PolicySection({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;
}
