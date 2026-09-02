import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/ads_service.dart';

/// Hides whatever it wraps while the user has earned quiet time.
///
/// The ad underneath stays loaded rather than being torn down, so it comes
/// straight back when the time is up instead of having to fetch a new one.
class AdFreeGate extends StatelessWidget {
  const AdFreeGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AdsService>()) {
      return child;
    }

    return ValueListenableBuilder<bool>(
      valueListenable: Get.find<AdsService>().isAdFree,
      builder: (BuildContext context, bool isAdFree, Widget? built) =>
          isAdFree ? const SizedBox.shrink() : built!,
      child: child,
    );
  }
}
