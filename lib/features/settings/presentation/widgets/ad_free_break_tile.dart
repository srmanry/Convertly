import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/services/ads_service.dart';
import 'settings_tile.dart';
import '../../../../core/i18n/translation_keys.dart';

/// Trades a couple of rewarded videos for a stretch with no ads at all.
///
/// The offer lives in settings rather than beside a conversion: it is a
/// choice about the whole app for the next few minutes, not about one file.
class AdFreeBreakTile extends StatefulWidget {
  const AdFreeBreakTile({super.key});

  @override
  State<AdFreeBreakTile> createState() => _AdFreeBreakTileState();
}

class _AdFreeBreakTileState extends State<AdFreeBreakTile> {
  final AdsService _ads = Get.find<AdsService>();

  /// Redraws the countdown while the stretch runs.
  ///
  /// The service reports when the stretch ends, not that a minute has
  /// passed, so the row has to keep its own beat to show the time falling.
  Timer? _ticker;
  bool _watching = false;

  @override
  void initState() {
    super.initState();
    _ads.breakEndsAt.addListener(_onBreakChanged);
    _syncTicker();
  }

  @override
  void dispose() {
    _ads.breakEndsAt.removeListener(_onBreakChanged);
    _ticker?.cancel();
    super.dispose();
  }

  void _onBreakChanged() {
    if (mounted) {
      setState(_syncTicker);
    }
  }

  void _syncTicker() {
    _ticker?.cancel();
    _ticker = null;
    if (!_ads.isOnAdFreeBreak) {
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 20), (Timer _) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _watch() async {
    if (_watching) {
      return;
    }

    if (!_ads.canOfferBreak) {
      _tell(K.adNoVideoReady.tr);
      return;
    }

    setState(() => _watching = true);
    final bool earned = await _ads.watchForAdFreeBreak();
    if (!mounted) {
      return;
    }
    setState(() => _watching = false);

    if (!earned) {
      _tell(K.adVideoMustFinish.tr);
      return;
    }

    _tell(
      _ads.isOnAdFreeBreak
          ? K.adBreakEarned.trParams(<String, String>{
              'minutes': _ads.breakDurationLabel,
            })
          : K.adBreakOneMore.trParams(<String, String>{
              'minutes': _ads.breakDurationLabel,
            }),
    );
  }

  void _tell(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _ads.adsWatchedTowardBreak,
      builder: (BuildContext context, int watched, _) {
        final bool onBreak = _ads.isOnAdFreeBreak;

        return SettingsTile(
          icon: onBreak
              ? Icons.timer_rounded
              : Icons.play_circle_outline_rounded,
          title: onBreak
              ? K.adBreakActive.trParams(<String, String>{
                  'time': _remainingLabel(),
                })
              : K.adBreakOffer.trParams(<String, String>{
                  'minutes': _ads.breakDurationLabel,
                }),
          subtitle: _subtitle(watched: watched, onBreak: onBreak),
          trailing: _watching
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _watching ? null : _watch,
        );
      },
    );
  }

  String _subtitle({required int watched, required bool onBreak}) {
    final int total = AdsService.adsPerBreak;
    if (onBreak) {
      return K.adBreakExtendHint.trParams(<String, String>{
        'minutes': _ads.breakDurationLabel,
      });
    }
    if (watched == 0) {
      return K.adBreakStartHint.trParams(<String, String>{
        'count': '$total',
        'minutes': _ads.breakDurationLabel,
      });
    }
    return K.adBreakProgressHint.trParams(<String, String>{
      'watched': '$watched',
      'total': '$total',
      'left': '${total - watched}',
    });
  }

  /// Whole minutes left, rounded up so the last stretch reads as a minute
  /// rather than as none.
  String _remainingLabel() {
    final Duration left = _ads.breakRemaining;
    if (left.inMinutes >= 1) {
      final int minutes =
          left.inSeconds ~/ 60 + (left.inSeconds % 60 > 0 ? 1 : 0);
      return K.adMinutes.trParams(<String, String>{'count': '$minutes'});
    }
    return K.adUnderAMinute.tr;
  }
}
