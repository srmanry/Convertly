import 'dart:io';

/// Path and filename helpers.
///
/// Kept free of Flutter and plugin imports so they can be unit tested without
/// a widget binding.
abstract final class FileUtils {
  /// Characters Android's filesystem rejects or that break shell quoting.
  static final RegExp _illegalCharacters = RegExp(r'[<>:"/\\|?*\x00-\x1F]');
  static final RegExp _repeatedWhitespace = RegExp(r'\s+');

  static const int _maxBaseNameLength = 120;

  /// Lowercase extension without the dot, or an empty string when absent.
  static String extensionOf(String path) {
    final String name = basename(path);
    final int dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) {
      return '';
    }
    return name.substring(dot + 1).toLowerCase();
  }

  /// Final path segment, including any extension.
  static String basename(String path) {
    final int separator = path.lastIndexOf(Platform.pathSeparator);
    return separator == -1 ? path : path.substring(separator + 1);
  }

  /// Filename without its extension.
  static String baseNameWithoutExtension(String path) {
    final String name = basename(path);
    final int dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  /// Strips characters that are illegal in a filename and trims the result to
  /// a length the filesystem accepts.
  ///
  /// Returns `null` when nothing usable remains, so callers can reject the name
  /// rather than silently writing to a surprising path.
  static String? sanitizeFileName(String input) {
    final String cleaned = input
        .replaceAll(_illegalCharacters, '')
        .replaceAll(_repeatedWhitespace, ' ')
        .trim()
        // A leading dot would create a hidden file; trailing dots are invalid.
        .replaceAll(RegExp(r'^\.+|\.+$'), '')
        .trim();

    if (cleaned.isEmpty) {
      return null;
    }

    return cleaned.length <= _maxBaseNameLength
        ? cleaned
        : cleaned.substring(0, _maxBaseNameLength).trim();
  }

  /// Builds a collision-free path inside [directory].
  ///
  /// `song.mp3` becomes `song_1.mp3`, then `song_2.mp3`, matching the spec's
  /// naming rule. [exists] is injectable so the logic is testable without
  /// touching the filesystem.
  static String uniquePath({
    required String directory,
    required String baseName,
    required String extension,
    bool Function(String path)? exists,
  }) {
    final bool Function(String path) check =
        exists ?? (String path) => File(path).existsSync();

    String candidate = _join(directory, '$baseName.$extension');
    int suffix = 0;

    while (check(candidate)) {
      suffix++;
      candidate = _join(directory, '${baseName}_$suffix.$extension');
    }

    return candidate;
  }

  static String _join(String directory, String name) {
    final String separator = Platform.pathSeparator;
    return directory.endsWith(separator)
        ? '$directory$name'
        : '$directory$separator$name';
  }
}
