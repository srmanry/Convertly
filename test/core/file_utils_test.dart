import 'package:convertly/core/utils/file_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extensionOf', () {
    test('returns a lowercase extension', () {
      expect(FileUtils.extensionOf('/media/clip.MP4'), 'mp4');
    });

    test('returns empty when there is no usable extension', () {
      expect(FileUtils.extensionOf('/media/clip'), '');
      expect(FileUtils.extensionOf('/media/clip.'), '');
      expect(FileUtils.extensionOf('/media/.hidden'), '');
    });
  });

  group('baseNameWithoutExtension', () {
    test('strips directory and extension', () {
      expect(
        FileUtils.baseNameWithoutExtension('/media/my clip.mp4'),
        'my clip',
      );
    });

    test('keeps a name that has no extension', () {
      expect(FileUtils.baseNameWithoutExtension('/media/clip'), 'clip');
    });
  });

  group('sanitizeFileName', () {
    test('removes characters the filesystem rejects', () {
      expect(FileUtils.sanitizeFileName('my/song:name?'), 'mysongname');
    });

    test('collapses whitespace and trims', () {
      expect(FileUtils.sanitizeFileName('  my   song  '), 'my song');
    });

    test('refuses a name that has nothing usable left', () {
      expect(FileUtils.sanitizeFileName('///'), isNull);
      expect(FileUtils.sanitizeFileName('   '), isNull);
      expect(FileUtils.sanitizeFileName('...'), isNull);
    });

    test('does not produce a hidden file', () {
      expect(FileUtils.sanitizeFileName('.hidden'), 'hidden');
    });

    test('truncates an overlong name', () {
      final String? result = FileUtils.sanitizeFileName('a' * 500);

      expect(result, isNotNull);
      expect(result!.length, lessThanOrEqualTo(120));
    });
  });

  group('uniquePath', () {
    test('uses the plain name when nothing collides', () {
      final String path = FileUtils.uniquePath(
        directory: '/out',
        baseName: 'song',
        extension: 'mp3',
        exists: (_) => false,
      );

      expect(path, '/out/song.mp3');
    });

    test('appends an incrementing suffix on collision', () {
      final Set<String> taken = <String>{'/out/song.mp3', '/out/song_1.mp3'};

      final String path = FileUtils.uniquePath(
        directory: '/out',
        baseName: 'song',
        extension: 'mp3',
        exists: taken.contains,
      );

      expect(path, '/out/song_2.mp3');
    });

    test('does not double the separator when the directory ends with one', () {
      final String path = FileUtils.uniquePath(
        directory: '/out/',
        baseName: 'song',
        extension: 'mp3',
        exists: (_) => false,
      );

      expect(path, '/out/song.mp3');
    });
  });
}
