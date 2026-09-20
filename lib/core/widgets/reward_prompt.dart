import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
      actions: <Widget>[
        TextButton(
          onPressed: () => Get.back<bool>(result: false),
          child: Text(K.adNoThanks.tr),
        ),
        FilledButton(
          onPressed: () => Get.back<bool>(result: true),
          child: Text(K.adWatchVideo.tr),
        ),
      ],
    ),
  );
  return agreed ?? false;
}
