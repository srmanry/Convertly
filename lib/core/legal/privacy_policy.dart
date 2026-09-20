/// The privacy policy, as plain data.
///
/// Kept free of Flutter so one text feeds both the in-app page and the web
/// page generated for the store listing (`tool/generate_privacy_policy.dart`).
/// Edit the words here, then regenerate the web page; a test fails if the two
/// drift apart.
abstract final class PrivacyPolicy {
  static const String appName = 'AudioForge';

  /// Change this whenever the wording or the app's data practices change.
  static const String lastUpdatedDate = 'September 3, 2026';

  static const List<String> introParagraphs = <String>[
    '$appName ("we", "our", or "the app") is an offline media converter and '
        'audio toolkit that lets you extract, convert, trim, merge, mix, clean '
        'and play audio files directly on your device.',
    'We respect your privacy. Your media files never leave your device.',
  ];

  static const List<PolicySection> sections = <PolicySection>[
    PolicySection(
      title: '1. Information We Collect',
      paragraphs: <String>[
        '$appName does not ask you to create an account and does not collect '
            'personal information such as your name, email address, phone '
            'number, password, address, contacts or precise location.',
        'The app uses the Google Mobile Ads SDK described in Section 5. To '
            'serve and measure ads and detect fraudulent activity, the SDK '
            'may collect and share with Google your device advertising '
            'identifier, IP address, ad and app interactions, diagnostic '
            'information, and basic device and app information. This data is '
            'not linked to any identity we hold, because we hold none.',
      ],
    ),
    PolicySection(
      title: '2. Audio and Video Files',
      paragraphs: <String>[
        '$appName asks for permission to read audio files on your device so '
            'you can browse your music in the built-in player. Choosing a '
            'file for an editing tool uses Android\'s system file picker.',
        'Your files are processed entirely on your device. They are never '
            'uploaded to us or to anyone else. This applies to every tool in '
            'the app, including Video to Audio, Audio Converter, Audio Cutter, '
            'Audio Merger, Audio Mixer, Audio Timeline, Audio Compressor and '
            'Noise Remover.',
        'We do not inspect your files for any purpose beyond the on-device '
            'operation you request, and we never transmit their contents.',
      ],
    ),
    PolicySection(
      title: '3. Data Storage',
      paragraphs: <String>[
        'Converted files are saved in the app\'s own folder on your device. '
            'You may also choose to save a file to your device\'s public Music '
            'folder, where other apps can find it.',
        'Nothing is uploaded to a remote server. You can delete any file at '
            'any time, from inside the app or with your device\'s file manager.',
      ],
    ),
    PolicySection(
      title: '4. Internet and Network Usage',
      paragraphs: <String>[
        'All media processing works offline. No internet connection is needed '
            'to convert, trim, merge, mix, clean or play your files.',
        'The app uses the internet to manage consent and load advertisements. '
            'If you are offline, the app still works fully and simply shows '
            'no ads.',
      ],
    ),
    PolicySection(
      title: '5. Third-Party Services',
      paragraphs: <String>[
        '$appName shows advertisements through Google AdMob.',
        'To serve and measure ads and detect invalid activity, the Google '
            'Mobile Ads SDK may collect and share with Google your device\'s '
            'advertising identifier, IP address, ad and app interactions, '
            'diagnostic information, and basic device and app information. '
            'This is the only category of data sent from the app to an '
            'external service, and it is sent over an encrypted connection.',
        'AdMob has no access to your media files.',
        'You can learn how Google uses this data at: '
            'https://policies.google.com/technologies/partner-sites',
        'You can reset or delete your advertising ID, or turn off ad '
            'personalisation, in your device settings under Settings > '
            'Privacy > Ads.',
        'Where required by law, Google\'s consent message is shown before ads '
            'load. You can review or change your choice later from the app\'s '
            'Ad privacy settings.',
        'The app also offers an optional rewarded ad: if you choose to watch '
            'one, ads are hidden for a period of time. Watching it is entirely '
            'your choice and no feature of the app depends on it.',
      ],
    ),
    PolicySection(
      title: '6. Data Security',
      paragraphs: <String>[
        'Because processing happens on your device and your files are never '
            'uploaded, your content stays under your control. Data sent to '
            'the advertising service is transmitted over a secure, encrypted '
            'connection.',
        'No method of electronic storage is completely secure, so we '
            'recommend keeping backups of files that matter to you.',
      ],
    ),
    PolicySection(
      title: '7. Children\'s Privacy',
      paragraphs: <String>[
        '$appName is not directed at children under 13 and we do not knowingly '
            'collect personal information from them. The app contains '
            'advertising and is intended for a general audience aged 13 and '
            'over.',
      ],
    ),
    PolicySection(
      title: '8. Your Files and Your Control',
      paragraphs: <String>[
        'You keep control of the files you choose and the files the app '
            'creates. You can delete them at any time from within the app or '
            'with your device\'s file manager. Removing the app also removes '
            'the files kept in its own folder; anything you saved to your '
            'Music folder stays.',
      ],
    ),
    PolicySection(
      title: '9. Permissions We Request',
      bullets: <String>[
        'Read music and audio: to let you list the music already on your '
            'device in the built-in player. On Android 12 and older, Android '
            'calls this the storage permission; $appName uses it only to list '
            'audio in the Player. Choosing a file for a tool uses Android\'s '
            'system file picker and does not require broad file access.',
        'Save to the public Music folder (Android 9 and older only): requested '
            'only when you choose Save to phone.',
        'Internet and network state: to manage consent and load '
            'advertisements. Media processing remains offline.',
      ],
    ),
    PolicySection(
      title: '10. Changes to This Privacy Policy',
      paragraphs: <String>[
        'We may update this policy if the app\'s features or data practices '
            'change. Any change will be shown by updating the "Last Updated" '
            'date above.',
      ],
    ),
    PolicySection(
      title: '11. Contact Us',
      paragraphs: <String>[
        'If you have questions about this Privacy Policy or $appName, please '
            'use the support contact shown on our Google Play Store listing.',
      ],
    ),
  ];

  static const String footerTagline = 'Offline Media Converter & Audio Toolkit';
}

/// One headed part of the policy.
class PolicySection {
  const PolicySection({
    required this.title,
    this.paragraphs = const <String>[],
    this.bullets = const <String>[],
  });

  final String title;
  final List<String> paragraphs;
  final List<String> bullets;
}
