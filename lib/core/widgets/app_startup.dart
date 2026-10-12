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

  /// How long startup may take before the retry screen replaces the logo.
  ///
  /// Generous on purpose. This is a last resort for work that has genuinely
  /// stuck, not a judgement on a slow phone: measured on a mid-range device,
  /// startup reads storage and registers services in about four seconds in a
  /// debug build, and a weaker phone takes longer still. A bound near that
  /// figure turned an ordinary slow start into an error screen for someone
  /// whose app was about to open.
  static const Duration maximumWait = Duration(seconds: 20);

  final Future<void> Function() initialize;
  final Widget ready;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  Future<void>? _initialization;
  late Future<void> _attempt;

  @override
  void initState() {
    super.initState();
    _start();
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
    _attempt = _initialization!.timeout(AppStartup.maximumWait);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _attempt,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return widget.ready;
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
                      const AppLogo(size: 112),
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
