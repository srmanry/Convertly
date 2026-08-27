/// Formatting helpers shared by every screen that shows file metadata.
abstract final class Formatters {
  static const int _kilobyte = 1024;

  /// Human readable file size, e.g. `4.7 MB`.
  ///
  /// Uses binary units, matching what Android's own storage UI reports.
  static String fileSize(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }

    const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
    double size = bytes.toDouble();
    int unit = 0;

    while (size >= _kilobyte && unit < units.length - 1) {
      size /= _kilobyte;
      unit++;
    }

    // Bytes are always whole; larger units read better with one decimal.
    final String value = unit == 0
        ? size.toStringAsFixed(0)
        : size.toStringAsFixed(size >= 100 ? 0 : 1);

    return '$value ${units[unit]}';
  }

  /// Playback duration as `m:ss`, or `h:mm:ss` once past an hour.
  static String duration(Duration duration) {
    if (duration.isNegative) {
      return '0:00';
    }

    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);

    final String paddedSeconds = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:$paddedSeconds';
    }
    return '$minutes:$paddedSeconds';
  }

  /// Short date used in file lists, e.g. `26 Aug 2026`.
  static String date(DateTime dateTime) {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
  }
}
