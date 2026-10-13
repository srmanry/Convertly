import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_constants.dart';
import '../constants/app_dimens.dart';
import '../i18n/translation_keys.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';

/// Draws a first frame immediately and bounds each startup wait.
class AppStartup extends StatefulWidget {
  const AppStartup({required this.initialize, required this.ready, super.key});

  /// How long the logo is held on screen, even once the app is ready.
  ///
  /// A deliberate wait, asked for so the mark is seen rather than flashed
  /// past: startup finishes in well under this on a current phone. Set it to
  /// [Duration.zero] to open as soon as the app is ready.
  static const Duration minimumShow = Duration(seconds: 4);

  /// One breath of the waiting logo, out and back.
  ///
  /// Slow enough to read as breathing rather than as a throbbing spinner.
  static const Duration pulsePeriod = Duration(milliseconds: 900);

  /// How far the breath carries the logo either side of its resting size.
  ///
  /// Small on purpose: this is a sign of life under a fixed logo, not an
  /// animation drawing attention to itself.
  static const double pulseScale = 0.06;

  /// How long the logo takes to clear away once the app is ready.
  ///
  /// Short on purpose. The app is already built and painted underneath before
  /// this runs, so the time is spent revealing it rather than waiting for it;
  /// stretched any further it would be an animation the user sits through.
  static const Duration revealDuration = Duration(milliseconds: 420);

  /// How long startup may take before the retry screen replaces the logo.
  ///
  /// Generous on purpose. This is a last resort for work that has genuinely
  /// stuck, not a judgement on a slow phone: measured on a mid-range device,
  /// startup reads storage and registers services in about four seconds in a
  /// debug build, and a weaker phone takes longer still. A bound near that
  /// figure turned an ordinary slow start into an error screen for someone
  /// whose app was about to open.
  static const Duration maximumWait = Duration(seconds: 20);

  /// The whole budget: the deliberate hold plus the work it is covering.
  static Duration get maximumShow => maximumWait + minimumShow;

  final Future<void> Function() initialize;
  final Widget ready;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> with TickerProviderStateMixin {
  Future<void>? _initialization;
  late Future<void> _attempt;

  /// Drives the hand-off from the logo to the app underneath.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: AppStartup.revealDuration,
  );

  /// Breathes the logo while there is still work to wait for.
  ///
  /// Something that moves says the app is working; a logo sitting perfectly
  /// still is what a frozen app looks like.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppStartup.pulsePeriod,
  );

  /// True once the logo has finished clearing out of the way, after which it
  /// is dropped from the tree entirely rather than left sitting invisible
  /// over the app.
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _reveal.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _revealed = true);
      }
    });
    _start();
  }

  /// Keeps the breathing running only while something is actually being
  /// waited for.
  ///
  /// Driven from the build rather than set once: a retry goes back to
  /// waiting, and a controller left repeating is work the device pays for
  /// with nothing on screen to show for it.
  void _breatheWhile(bool waiting) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pulse.isAnimating == waiting) {
        return;
      }
      if (waiting) {
        _pulse.repeat(reverse: true);
      } else {
        _pulse.stop();
      }
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _start() {
    // Keep an in-flight initialization after a timeout. Retry waits for that
    // same work rather than registering dependencies twice.
    _initialization ??= Future<void>.sync(widget.initialize).then(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        _initialization = null;
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
    // The logo is held for its full time even when the work finishes early.
    // eagerError so a failure is shown at once: there is no reason to make
    // someone watch a logo before telling them it did not start.
    _attempt = Future.wait<void>(<Future<void>>[
      _initialization!,
      Future<void>.delayed(AppStartup.minimumShow),
    ], eagerError: true).timeout(AppStartup.maximumShow);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _attempt,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        final bool ready =
            snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError;

        _breatheWhile(!ready && !snapshot.hasError);

        if (ready) {
          // The app is built and painted first; the logo then clears away
          // from on top of it. Starting the animation from here rather than
          // from the future's callback means it never runs before the frame
          // it is revealing exists.
          if (!_reveal.isAnimating && !_revealed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _reveal.forward();
              }
            });
          }

          // The app keeps this exact place in the tree once the logo is gone:
          // only the overlay above it comes and goes. Returning it unwrapped
          // instead moved it, which to Flutter is a different widget in a
          // different slot — the whole app was torn down and rebuilt, taking
          // its router and every registered controller with it, and the
          // rebuild storm that followed locked the app up on launch.
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                widget.ready,
                // Dropped entirely once it has faded: an invisible layer left
                // on top would swallow the first tap. Nothing here is
                // tappable while it lasts.
                if (!_revealed)
                  IgnorePointer(child: _RevealingLogo(animation: _reveal)),
              ],
            ),
          );
        }

        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: Scaffold(
            backgroundColor: AppTheme.dark.colorScheme.surface,
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.pagePadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _BreathingLogo(
                        animation: _pulse,
                        // Stopped once there is nothing left to wait for:
                        // breathing under an error message would suggest the
                        // app was still trying.
                        still: snapshot.hasError,
                      ),
                      if (snapshot.hasError) ...<Widget>[
                        const SizedBox(height: AppDimens.spaceXl),
                        Text(K.startupFailed.tr, textAlign: TextAlign.center),
                        const SizedBox(height: AppDimens.spaceLg),
                        FilledButton(
                          onPressed: () => setState(_start),
                          child: Text(K.tryAgain.tr),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The startup logo on its way out: it swells and fades, letting the app
/// through from underneath.
///
/// The same mark the native splash drew, in the same place, so the hand-off
/// from the system's screen to this one is not visible — only the leaving is.
class _RevealingLogo extends StatelessWidget {
  const _RevealingLogo({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    // The backdrop goes first and fastest: by the time the logo has grown,
    // the app behind it is already in plain sight.
    final Animation<double> backdrop = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.1, 0.65, curve: Curves.easeOut),
    );
    final Animation<double> logoFade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.25, 1, curve: Curves.easeOut),
    );
    // Accelerating rather than easing out, so the logo looks pulled towards
    // the viewer and off the screen instead of drifting to a halt.
    final Animation<double> growth = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInCubic,
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          // Fully gone at the end, and cheap to skip once it is.
          opacity: 1 - logoFade.value,
          child: ColoredBox(
            color: AppTheme.dark.colorScheme.surface.withValues(
              alpha: 1 - backdrop.value,
            ),
            child: Center(
              child: Transform.scale(scale: 1 + growth.value * 7, child: child),
            ),
          ),
        );
      },
      child: const AppLogo(size: 112),
    );
  }
}

/// The startup logo, breathing gently while the app is still getting ready.
class _BreathingLogo extends StatelessWidget {
  const _BreathingLogo({required this.animation, required this.still});

  final Animation<double> animation;
  final bool still;

  @override
  Widget build(BuildContext context) {
    const Widget logo = AppLogo(size: 112);
    if (still) {
      return logo;
    }

    final Animation<double> breath = CurvedAnimation(
      parent: animation,
      // Eased at both ends so the logo slows into each turn rather than
      // snapping back, which is what makes it read as breathing.
      curve: Curves.easeInOut,
    );

    return AnimatedBuilder(
      animation: breath,
      builder: (BuildContext context, Widget? child) => Transform.scale(
        // Centred on its resting size, so it grows and shrinks by the same
        // amount instead of only ever swelling.
        scale: 1 + (breath.value - 0.5) * 2 * AppStartup.pulseScale,
        child: child,
      ),
      child: logo,
    );
  }
}
