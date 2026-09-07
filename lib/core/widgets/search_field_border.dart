import 'package:flutter/material.dart';

import '../constants/app_dimens.dart';

/// The rounded outline every search box uses.
///
/// Shared rather than written out at each call site: two search boxes shaped
/// differently is the kind of drift nobody notices until the screens sit side
/// by side.
OutlineInputBorder searchFieldBorder({BorderSide? side}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
    borderSide: side ?? BorderSide.none,
  );
}
