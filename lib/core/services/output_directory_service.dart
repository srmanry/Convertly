import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

/// Resolves where converted files are written.
///
/// Uses the app-specific external directory, which is readable by file
/// managers and needs no runtime permission under scoped storage. The path is
/// resolved at call time rather than stored, so it stays valid across
/// reinstalls and OS storage changes.
class OutputDirectoryService {
  Directory? _cached;

  /// Directory for finished output, created if it does not exist.
  Future<Directory> resolve() async {
    final Directory? cached = _cached;
    if (cached != null && cached.existsSync()) {
      return cached;
    }

    // getExternalStorageDirectory is Android-only and can return null; the
    // documents directory is a valid fallback on every platform.
    final Directory base =
        await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();

    final Directory output = Directory(
      '${base.path}${Platform.pathSeparator}${AppConstants.outputFolderName}',
    );

    if (!output.existsSync()) {
      await output.create(recursive: true);
    }

    _cached = output;
    return output;
  }

  /// Scratch directory for intermediate files, e.g. merge concat lists.
  Future<Directory> resolveTemp() async {
    final Directory base = await getTemporaryDirectory();
    final Directory temp = Directory(
      '${base.path}${Platform.pathSeparator}convertly_work',
    );
    if (!temp.existsSync()) {
      await temp.create(recursive: true);
    }
    return temp;
  }

  /// Removes intermediate files left behind by earlier runs (spec §25).
  Future<void> clearTemp() async {
    final Directory temp = await resolveTemp();
    if (!temp.existsSync()) {
      return;
    }
    await for (final FileSystemEntity entity in temp.list()) {
      try {
        await entity.delete(recursive: true);
      } on FileSystemException {
        // A file still held open by the player is skipped rather than fatal.
        continue;
      }
    }
  }

  /// Free space is not queryable without a platform channel, so callers get a
  /// best-effort check by attempting the write itself.
  Future<bool> canWrite() async {
    try {
      final Directory output = await resolve();
      final File probe = File(
        '${output.path}${Platform.pathSeparator}.write_check',
      );
      await probe.writeAsString('');
      await probe.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }
}
