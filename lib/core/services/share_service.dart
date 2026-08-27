import 'dart:io';

import 'package:share_plus/share_plus.dart';

/// Hands a file to the Android share sheet.
///
/// Isolated so the rest of the app does not depend on the sharing plugin.
class ShareService {
  /// Returns false when the file is gone, so callers can tell the user rather
  /// than opening an empty share sheet.
  Future<bool> shareFile(String path, {String? subject}) async {
    if (!File(path).existsSync()) {
      return false;
    }

    await SharePlus.instance.share(
      ShareParams(files: <XFile>[XFile(path)], subject: subject),
    );
    return true;
  }
}
