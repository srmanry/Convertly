import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_dimens.dart';
import '../../core/i18n/translation_keys.dart';

/// Asks before playing the rewarded ad that makes the next files ad-free.
///
/// A rewarded ad has to be the user's choice, never sprung on them, so the
/// video only plays after they tap to watch it. Saying no costs nothing but
/// the reward: the file converts either way. Resolves to whether they agreed.
Future<bool> showRewardPrompt() async {
  final bool? agreed = await Get.dialog<bool>(
    AlertDialog(
      icon: const Icon(Icons.play_circle_outline_rounded),
      title: Text(K.adWatchShortVideo.tr),
      content: Text(K.adRewardPromptMessage.tr),
      // Stacked by hand rather than left to the overflow bar, which could not
      // fit both on one line and dropped the quieter one onto a row of its
      // own, hard against the right edge, looking like a mistake.
      actions: <Widget>[
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Get.back<bool>(result: true),
                child: Text(K.adWatchVideo.tr),
              ),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            // Quieter than the offer, but never missing: a rewarded ad the
            // user cannot visibly decline is one they were made to watch.
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Get.back<bool>(result: false),
                child: Text(K.adNoThanks.tr),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return agreed ?? false;
}
