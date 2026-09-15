import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/ads_service.dart';

/// Asks before playing the rewarded ad that makes the next files ad-free.
///
/// A rewarded ad has to be the user's choice, never sprung on them, so the
/// video only plays after they tap to watch it. Saying no costs nothing but
/// the reward: the file converts either way. Resolves to whether they agreed.
Future<bool> showRewardPrompt() async {
  final bool? agreed = await Get.dialog<bool>(
    AlertDialog(
      icon: const Icon(Icons.play_circle_outline_rounded),
      title: const Text('Watch a short video'),
      content: const Text(
        'Watch one short video to make this file and the next '
        '${AdsService.adFreeExportsReward - 1} without ads. Your file keeps '
        'converting while you watch.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Get.back<bool>(result: false),
          child: const Text('No thanks'),
        ),
        FilledButton(
          onPressed: () => Get.back<bool>(result: true),
          child: const Text('Watch video'),
        ),
      ],
    ),
  );
  return agreed ?? false;
}
