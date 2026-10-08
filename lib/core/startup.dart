import 'routes/app_routes.dart';

/// Where the app opens.
///
/// Decided before the first frame rather than on a screen of its own: the
/// native splash is already on display while this is worked out, so a second,
/// identical branding screen in Dart only adds waiting.
String startRoute({required bool onboardingCompleted}) =>
    onboardingCompleted ? AppRoutes.shell : AppRoutes.onboarding;
