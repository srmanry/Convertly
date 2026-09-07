import 'package:convertly/features/audio_player/domain/entities/player_track.dart';
import 'package:convertly/features/audio_player/presentation/bindings/audio_player_binding.dart';
import 'package:convertly/features/audio_player/presentation/controllers/audio_player_controller.dart';
import 'package:flutter_test/flutter_test.dart';

List<PlayerTrack> tracks(int count) => <PlayerTrack>[
  for (int i = 0; i < count; i++)
    PlayerTrack(path: '/music/$i.mp3', title: 'Song $i'),
];

void main() {
  // The controller builds a real AudioPlayer, which reaches for a platform
  // channel the moment it is constructed.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('queue position', () {
    test('opens on the track that was tapped', () {
      final AudioPlayerController controller = AudioPlayerController(
        queue: tracks(4),
        startIndex: 2,
      );

      expect(controller.index.value, 2);
      expect(controller.title, 'Song 2');
      expect(controller.path, '/music/2.mp3');
    });

    test('an index past the end lands on the last track, not out of range', () {
      final AudioPlayerController controller = AudioPlayerController(
        queue: tracks(3),
        startIndex: 99,
      );

      expect(controller.index.value, 2);
      expect(controller.title, 'Song 2');
    });

    test('a negative index lands on the first track', () {
      final AudioPlayerController controller = AudioPlayerController(
        queue: tracks(3),
        startIndex: -5,
      );

      expect(controller.index.value, 0);
    });

    test('an empty queue reports no track rather than throwing', () {
      final AudioPlayerController controller = AudioPlayerController(
        queue: const <PlayerTrack>[],
      );

      expect(controller.currentTrack, isNull);
      expect(controller.path, isEmpty);
      expect(controller.title, 'Audio');
      expect(controller.hasNext, isFalse);
      expect(controller.hasPrevious, isFalse);
    });
  });

  group('what the skip buttons are allowed to do', () {
    test('a single file can go neither way', () {
      final AudioPlayerController controller = AudioPlayerController(
        queue: tracks(1),
      );

      expect(controller.hasPrevious, isFalse);
      expect(controller.hasNext, isFalse);
    });

    test('the first track cannot go back, the last cannot go on', () {
      final AudioPlayerController first = AudioPlayerController(
        queue: tracks(3),
      );
      expect(first.hasPrevious, isFalse);
      expect(first.hasNext, isTrue);

      final AudioPlayerController last = AudioPlayerController(
        queue: tracks(3),
        startIndex: 2,
      );
      expect(last.hasPrevious, isTrue);
      expect(last.hasNext, isFalse);
    });
  });

  group('the binding reads route arguments', () {
    test('a queue of maps becomes a queue of tracks', () {
      final List<PlayerTrack> queue = AudioPlayerBinding.queueFrom(
        <Object?, Object?>{
          'queue': <Map<String, String>>[
            <String, String>{'path': '/a.mp3', 'title': 'A'},
            <String, String>{'path': '/b.mp3', 'title': 'B'},
          ],
          'index': 1,
        },
      );

      expect(queue, hasLength(2));
      expect(queue.last.title, 'B');
    });

    test('a lone path still opens, as a queue of one', () {
      final List<PlayerTrack> queue = AudioPlayerBinding.queueFrom(
        <Object?, Object?>{'path': '/only.mp3', 'title': 'Only'},
      );

      expect(queue, hasLength(1));
      expect(queue.single.title, 'Only');
    });

    test('junk entries are dropped, not opened blank', () {
      final List<PlayerTrack> queue = AudioPlayerBinding.queueFrom(
        <Object?, Object?>{
          'queue': <Object?>[
            <String, String>{'path': '/a.mp3', 'title': 'A'},
            'not a map',
            <String, String>{'title': 'no path'},
          ],
        },
      );

      expect(queue, hasLength(1));
      expect(queue.single.path, '/a.mp3');
    });

    test('an empty queue falls back to the single-track arguments', () {
      final List<PlayerTrack> queue = AudioPlayerBinding.queueFrom(
        <Object?, Object?>{
          'queue': <Object?>[],
          'path': '/fallback.mp3',
          'title': 'Fallback',
        },
      );

      expect(queue.single.path, '/fallback.mp3');
    });

    test('arguments with nothing playable give an empty queue', () {
      expect(AudioPlayerBinding.queueFrom(const <Object?, Object?>{}), isEmpty);
    });
  });

  group('PlayerTrack.fromArguments', () {
    test('reads a well-formed entry', () {
      final PlayerTrack? track = PlayerTrack.fromArguments(<String, String>{
        'path': '/a.mp3',
        'title': 'A',
      });

      expect(track, const PlayerTrack(path: '/a.mp3', title: 'A'));
    });

    test('an entry with no path is refused rather than opened blank', () {
      expect(PlayerTrack.fromArguments(<String, String>{'title': 'A'}), isNull);
      expect(
        PlayerTrack.fromArguments(<String, String>{'path': '', 'title': 'A'}),
        isNull,
      );
      expect(PlayerTrack.fromArguments('not a map'), isNull);
      expect(PlayerTrack.fromArguments(null), isNull);
    });

    test('a missing title falls back rather than showing nothing', () {
      final PlayerTrack? track = PlayerTrack.fromArguments(<String, String>{
        'path': '/a.mp3',
      });

      expect(track?.title, 'Audio');
    });
  });
}
