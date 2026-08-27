import 'package:convertly/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Formatters.fileSize', () {
    test('formats bytes without a decimal', () {
      expect(Formatters.fileSize(0), '0 B');
      expect(Formatters.fileSize(512), '512 B');
    });

    test('steps up through binary units', () {
      expect(Formatters.fileSize(1024), '1.0 KB');
      expect(Formatters.fileSize(1024 * 1024), '1.0 MB');
      expect(Formatters.fileSize(1024 * 1024 * 1024), '1.0 GB');
    });

    test('drops the decimal once the value reaches three digits', () {
      expect(Formatters.fileSize(105 * 1024 * 1024), '105 MB');
    });

    test('treats a negative size as empty rather than throwing', () {
      expect(Formatters.fileSize(-1), '0 B');
    });
  });

  group('Formatters.duration', () {
    test('formats under an hour as m:ss', () {
      expect(Formatters.duration(const Duration(seconds: 5)), '0:05');
      expect(
        Formatters.duration(const Duration(minutes: 3, seconds: 7)),
        '3:07',
      );
    });

    test('formats an hour or more as h:mm:ss', () {
      expect(
        Formatters.duration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    test('handles zero and negative durations', () {
      expect(Formatters.duration(Duration.zero), '0:00');
      expect(Formatters.duration(const Duration(seconds: -5)), '0:00');
    });
  });

  test('Formatters.date renders a short readable date', () {
    expect(Formatters.date(DateTime(2026, 8, 26)), '26 Aug 2026');
    expect(Formatters.date(DateTime(2026)), '1 Jan 2026');
  });
}
