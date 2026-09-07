import 'package:convertly/core/utils/playable_audio_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  group('playableAudioSource', () {
    test('a content:// uri is opened as a uri, not as a filename', () {
      // The bug this guards: songs from the phone's music index are
      // content:// uris, and opening one as a file path silently failed, so
      // nothing played.
      final UriAudioSource source = playableAudioSource(
        'content://media/external/audio/media/1234',
      );

      expect(source.uri.scheme, 'content');
      expect(
        source.uri.toString(),
        'content://media/external/audio/media/1234',
      );
    });

    test('a plain filesystem path is opened as a file', () {
      final UriAudioSource source = playableAudioSource('/storage/song.mp3');

      expect(source.uri.scheme, 'file');
      expect(source.uri.toFilePath(), '/storage/song.mp3');
    });

    test('a file:// uri is turned back into a path', () {
      // just_audio wants the path, not the whole uri, for a local file.
      final UriAudioSource source = playableAudioSource(
        'file:///var/mobile/track.m4a',
      );

      expect(source.uri.scheme, 'file');
      expect(source.uri.toFilePath(), '/var/mobile/track.m4a');
    });

    test('a path with spaces survives the round trip', () {
      final UriAudioSource source = playableAudioSource(
        '/storage/My Music/track 01.mp3',
      );

      expect(source.uri.toFilePath(), '/storage/My Music/track 01.mp3');
    });

    test('a Windows-style drive letter is not mistaken for a scheme', () {
      // "C:/..." parses as a uri with scheme "c"; treating it as a remote
      // source would break a perfectly ordinary path.
      final UriAudioSource source = playableAudioSource(
        r'/storage/emulated/0/Music/C major.mp3',
      );

      expect(source.uri.scheme, 'file');
    });

    test('an http uri is left alone for the player to stream', () {
      final UriAudioSource source = playableAudioSource(
        'https://example.com/clip.mp3',
      );

      expect(source.uri.scheme, 'https');
    });
  });
}
