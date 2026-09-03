import 'dart:io';

import 'package:flutter/services.dart';

/// Copies a file the app made into the phone's own Music folder.
///
/// The app writes its output to its private folder, which no other app can
/// see and which Android removes on uninstall. This is what puts a finished
/// track where a music player, a file manager or a messaging app will find
/// it, and where it survives the app being removed.
class MediaExportService {
  const MediaExportService([
    this._channel = const MethodChannel('convertly/device_audio'),
  ]);

  final MethodChannel _channel;

  bool get isSupported => Platform.isAndroid;

  /// Saves [path] to the phone as [name].
  ///
  /// Returns where it landed, or null when it could not be saved.
  Future<String?> saveToMusic({
    required String path,
    required String name,
  }) async {
    if (!isSupported) {
      return null;
    }
    try {
      return await _channel.invokeMethod<String>(
        'saveToMusic',
        <String, String>{'path': path, 'name': name},
      );
    } on PlatformException {
      // The message is technical; callers show their own.
      return null;
    }
  }
}
