import 'package:convertly/features/converter/domain/entities/media_info.dart';
import 'package:convertly/features/converter/domain/entities/mix_track.dart';
import 'package:convertly/features/converter/presentation/controllers/timeline_preview_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

MediaInfo clip(String name) => MediaInfo(
  path: '/in/$name.mp3',
  name: '$name.mp3',
  sizeInBytes: 1024,
  extension: 'mp3',
  hasAudio: true,
  hasVideo: false,
  duration: const Duration(minutes: 3),
  playbackUri: '/in/$name.mp3',
);

void main() {
  group('timeline preview playlist', () {
    test('a trimmed clip is bounded to its selection', () {
      final List<AudioSource> playlist = TimelinePreviewController.playlistFor(
        <MediaInfo>[clip('one')],
        const <MixTrack>[
          MixTrack(
            trimStart: Duration(seconds: 108),
            trimEnd: Duration(seconds: 172),
          ),
        ],
      );

      // Without this the preview plays the whole file and the clips run far
      // past the track they are supposed to make up.
      final ClippingAudioSource source = playlist.single as ClippingAudioSource;
      expect(source.start, const Duration(seconds: 108));
      expect(source.end, const Duration(seconds: 172));
    });

    test('an untrimmed clip is handed over whole', () {
      final List<AudioSource> playlist = TimelinePreviewController.playlistFor(
        <MediaInfo>[clip('one')],
        const <MixTrack>[MixTrack()],
      );

      expect(playlist.single, isA<UriAudioSource>());
      expect(playlist.single, isNot(isA<ClippingAudioSource>()));
    });

    test('a clip trimmed only at the start runs to the end of the file', () {
      final List<AudioSource> playlist = TimelinePreviewController.playlistFor(
        <MediaInfo>[clip('one')],
        const <MixTrack>[MixTrack(trimStart: Duration(seconds: 30))],
      );

      final ClippingAudioSource source = playlist.single as ClippingAudioSource;
      expect(source.start, const Duration(seconds: 30));
      expect(source.end, isNull);
    });

    test('every clip gets an entry, in order', () {
      final List<AudioSource> playlist = TimelinePreviewController.playlistFor(
        <MediaInfo>[clip('one'), clip('two'), clip('three')],
        const <MixTrack>[
          MixTrack(trimEnd: Duration(seconds: 10)),
          MixTrack(),
          MixTrack(trimStart: Duration(seconds: 5)),
        ],
      );

      expect(playlist, hasLength(3));
      expect(playlist[0], isA<ClippingAudioSource>());
      expect(playlist[1], isNot(isA<ClippingAudioSource>()));
      expect(playlist[2], isA<ClippingAudioSource>());
    });

    test('a clip with no matching track plays whole rather than crashing', () {
      final List<AudioSource> playlist = TimelinePreviewController.playlistFor(
        <MediaInfo>[clip('one'), clip('two')],
        const <MixTrack>[MixTrack()],
      );

      expect(playlist, hasLength(2));
      expect(playlist.last, isA<UriAudioSource>());
    });
  });
}
