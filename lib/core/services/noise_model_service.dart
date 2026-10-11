import 'dart:io';

import 'package:flutter/services.dart';

import 'output_directory_service.dart';

/// Puts the noise-removal model somewhere FFmpeg can open it.
///
/// FFmpeg's `arnndn` filter takes a path on disk, and an asset inside the
/// APK is not that: it has to be written out once before the first clean-up
/// runs. The copy then stays, so later runs cost nothing.
class NoiseModelService {
  NoiseModelService(this._directories);

  final OutputDirectoryService _directories;

  /// The trained network the clean-up uses, shipped with the app.
  ///
  /// RNNoise, trained on speech. That is also its limit: it treats whatever
  /// does not sound like a voice as noise, which is why it is offered for
  /// recordings of people rather than for music.
  static const String assetPath = 'assets/models/sh.rnnn';

  /// Name of the copy on disk. Fixed, so a second run finds the first copy.
  static const String fileName = 'sh.rnnn';

  /// What a usable model file starts with, per FFmpeg's reader. A truncated
  /// or half-written copy fails this and is written again.
  static const String header = 'rnnoise-nu model file version';

  String? _resolved;

  /// The model's path on disk, or null when it could not be put there.
  ///
  /// Null is not an error the user should see: the clean-up falls back to the
  /// filters that need no model, which is a worse clean rather than none.
  Future<String?> resolvePath({AssetBundle? bundle}) async {
    final AssetBundle assets = bundle ?? rootBundle;
    final String? cached = _resolved;
    if (cached != null && File(cached).existsSync()) {
      return cached;
    }

    try {
      final Directory directory = await _directories.resolveTemp();
      final File file = File('${directory.path}/$fileName');

      if (!await _looksComplete(file)) {
        final ByteData data = await assets.load(assetPath);
        await file.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }

      _resolved = file.path;
      return file.path;
    } on Exception {
      return null;
    }
  }

  /// Whether [file] already holds a model, rather than nothing or the start
  /// of one a previous run was interrupted while writing.
  Future<bool> _looksComplete(File file) async {
    if (!file.existsSync()) {
      return false;
    }
    try {
      final RandomAccessFile handle = await file.open();
      try {
        final List<int> start = await handle.read(header.length);
        return String.fromCharCodes(start) == header;
      } finally {
        await handle.close();
      }
    } on FileSystemException {
      return false;
    }
  }
}
