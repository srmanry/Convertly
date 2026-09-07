import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards where ads are allowed to appear.
///
/// Placement is a product decision that is easy to undo by accident: someone
/// adding a banner to a working screen would not see anything break. Reading
/// the source is crude, but it is the only thing that notices.
void main() {
  const String bannerWidget = 'BannerAdView';
  const String nativeWidget = 'NativeAdTile';

  String read(String path) => File(path).readAsStringSync();

  bool carriesAnAd(String path) {
    final String source = read(path);
    return source.contains(bannerWidget) || source.contains(nativeWidget);
  }

  group('screens that must stay clear of ads', () {
    test('the converter setup screen shows no ad', () {
      // Trim sliders, volume lanes and clip rows are precise, crowded
      // controls; an ad among them invites the mis-taps AdMob penalises.
      expect(
        carriesAnAd(
          'lib/features/converter/presentation/pages/converter_page.dart',
        ),
        isFalse,
      );
    });

    test('onboarding shows no ad', () {
      // The first thing anyone sees, before they have got anything from the
      // app at all.
      expect(
        carriesAnAd(
          'lib/features/onboarding/presentation/pages/onboarding_page.dart',
        ),
        isFalse,
      );
    });

    test('the splash screen shows no ad', () {
      expect(
        carriesAnAd('lib/features/splash/presentation/pages/splash_page.dart'),
        isFalse,
      );
    });

    test('the result screen shows no banner or in-list ad', () {
      // It offers a rewarded ad when one is due, and nothing otherwise: a
      // finish should read as a finish.
      expect(
        carriesAnAd(
          'lib/features/converter/presentation/pages/conversion_result_page.dart',
        ),
        isFalse,
      );
    });
  });

  group('screens that carry an ad on purpose', () {
    test('the waiting screen does', () {
      expect(
        read(
          'lib/features/converter/presentation/pages/'
          'conversion_progress_view.dart',
        ),
        contains(bannerWidget),
      );
    });

    test('the player does', () {
      expect(
        read(
          'lib/features/audio_player/presentation/pages/'
          'audio_player_page.dart',
        ),
        contains(bannerWidget),
      );
    });

    test('the tab shell has one shared banner for secondary tabs', () {
      final String source = read(
        'lib/features/shell/presentation/pages/shell_page.dart',
      );

      expect(source, contains(bannerWidget));
      // One strip for all four tabs; a second would stack two banners.
      expect(bannerWidget.allMatches(source).length, 1);
    });

    test('home controls its banner beside Recent Files', () {
      expect(
        read('lib/features/home/presentation/pages/home_page.dart'),
        contains(bannerWidget),
      );
    });

    test('the files list does', () {
      expect(
        read('lib/features/files/presentation/pages/files_page.dart'),
        contains(nativeWidget),
      );
    });
  });
}
