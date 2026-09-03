import 'package:convertly/core/errors/failure.dart';
import 'package:convertly/core/types/result.dart';
import 'package:convertly/features/music_library/data/datasources/device_audio_datasource.dart';
import 'package:convertly/features/music_library/domain/entities/song.dart';
import 'package:convertly/features/music_library/domain/repositories/music_library_repository.dart';
import 'package:convertly/features/music_library/domain/usecases/music_library_usecases.dart';
import 'package:convertly/features/music_library/presentation/controllers/music_library_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers whatever the test sets, so the controller is exercised without a
/// device media index.
class FakeMusicRepository implements MusicLibraryRepository {
  bool granted = false;
  bool grantOnRequest = false;
  int requests = 0;

  List<Song> device = <Song>[];
  List<Song> app = <Song>[];
  Failure? deviceFailure;

  @override
  Future<bool> hasDevicePermission() async => granted;

  @override
  Future<bool> requestDevicePermission() async {
    requests++;
    granted = grantOnRequest;
    return granted;
  }

  @override
  Future<Result<List<Song>>> deviceSongs() async {
    final Failure? failure = deviceFailure;
    if (failure != null) {
      return Result<List<Song>>.failure(failure);
    }
    return Result<List<Song>>.success(device);
  }

  @override
  Future<Result<List<Song>>> appSongs() async =>
      Result<List<Song>>.success(app);
}

Song song(String title, SongSource source, {String? artist}) => Song(
  id: '$source:$title',
  title: title,
  path: '/music/$title.mp3',
  source: source,
  artist: artist,
  duration: const Duration(minutes: 3),
);

void main() {
  deviceRowTests();

  late FakeMusicRepository repository;

  MusicLibraryController controllerFor() => MusicLibraryController(
    GetDeviceSongs(repository),
    GetAppSongs(repository),
    EnsureDevicePermission(repository),
  );

  setUp(() => repository = FakeMusicRepository());

  group('the two sources', () {
    test("the app's own files load without any permission", () async {
      repository.app = <Song>[song('converted', SongSource.app)];
      final MusicLibraryController controller = controllerFor();

      await controller.load();

      // Files the app made are its own; asking to read the device's music
      // must never be a condition for showing them.
      expect(controller.appSongs, hasLength(1));
      expect(repository.requests, 0);
    });

    test('device music appears once access is given', () async {
      repository
        ..grantOnRequest = true
        ..device = <Song>[song('phone song', SongSource.phone)];
      final MusicLibraryController controller = controllerFor();
      await controller.load();

      await controller.grantDeviceAccess();

      expect(controller.hasDeviceAccess.value, isTrue);
      expect(controller.deviceSongs, hasLength(1));
    });

    test('refusing leaves the app files usable', () async {
      repository
        ..grantOnRequest = false
        ..app = <Song>[song('converted', SongSource.app)];
      final MusicLibraryController controller = controllerFor();
      await controller.load();

      await controller.grantDeviceAccess();

      // A refusal is an answer, not a failure: nothing is reported as broken.
      expect(controller.hasDeviceAccess.value, isFalse);
      expect(controller.errorMessage.value, isEmpty);
      expect(controller.appSongs, hasLength(1));
    });

    test('the list follows the selected source', () async {
      repository
        ..granted = true
        ..device = <Song>[song('phone song', SongSource.phone)]
        ..app = <Song>[song('converted', SongSource.app)];
      final MusicLibraryController controller = controllerFor();
      await controller.load();

      controller.setTab(SongTab.phone);
      expect(controller.visibleSongs.single.title, 'phone song');

      controller.setTab(SongTab.app);
      expect(controller.visibleSongs.single.title, 'converted');
    });
  });

  group('searching', () {
    test('matches the title', () async {
      repository
        ..granted = true
        ..device = <Song>[
          song('Tere Bin', SongSource.phone),
          song('Sapna Dance', SongSource.phone),
        ];
      final MusicLibraryController controller = controllerFor();
      await controller.load();

      controller.setQuery('tere');

      expect(controller.visibleSongs.single.title, 'Tere Bin');
    });

    test('matches the artist too', () async {
      repository
        ..granted = true
        ..device = <Song>[
          song('One', SongSource.phone, artist: 'Arijit'),
          song('Two', SongSource.phone, artist: 'Shreya'),
        ];
      final MusicLibraryController controller = controllerFor();
      await controller.load();

      controller.setQuery('shreya');

      expect(controller.visibleSongs.single.title, 'Two');
    });

    test('an empty search shows everything again', () async {
      repository
        ..granted = true
        ..device = <Song>[song('One', SongSource.phone)];
      final MusicLibraryController controller = controllerFor();
      await controller.load();

      controller
        ..setQuery('nothing matches')
        ..setQuery('  ');

      expect(controller.visibleSongs, hasLength(1));
    });
  });

  group('Song', () {
    test('an unknown artist is not shown as text', () {
      // The device index writes this literally when a file has no tag.
      expect(song('a', SongSource.phone, artist: '<unknown>').subtitle, isNull);
      expect(song('a', SongSource.phone, artist: '  ').subtitle, isNull);
      expect(song('a', SongSource.phone, artist: 'Arijit').subtitle, 'Arijit');
    });
  });
}

// --- Reading the device's index ----------------------------------------------

/// The channel returns plain maps; these check the awkward rows, since a music
/// index is full of files with missing or empty tags.
void deviceRowTests() {
  group('a row from the device index', () {
    Map<Object?, Object?> row({
      Object? title = 'Tere Bin',
      Object? artist = 'Rahat',
      Object? durationMs = 210000,
      Object? sizeBytes = 5200000,
      String uri = 'content://media/external/audio/media/42',
    }) => <Object?, Object?>{
      'id': 42,
      'title': title,
      'artist': artist,
      'durationMs': durationMs,
      'sizeBytes': sizeBytes,
      'uri': uri,
    };

    test('a fully tagged row reads across', () {
      final Song song = DeviceAudioDataSourceImpl.fromRow(row());

      expect(song.title, 'Tere Bin');
      expect(song.subtitle, 'Rahat');
      expect(song.duration, const Duration(seconds: 210));
      expect(song.sizeInBytes, 5200000);
      expect(song.source, SongSource.phone);
    });

    test('the player is given the content uri, not a file path', () {
      // File paths are not reliably readable under scoped storage.
      expect(
        DeviceAudioDataSourceImpl.fromRow(row()).path,
        startsWith('content://'),
      );
    });

    test('an untagged file still shows something', () {
      expect(DeviceAudioDataSourceImpl.fromRow(row(title: null)).title, '42');
      expect(DeviceAudioDataSourceImpl.fromRow(row(title: '   ')).title, '42');
    });

    test('missing length and size are left unknown, not zero', () {
      final Song song = DeviceAudioDataSourceImpl.fromRow(
        row(durationMs: null, sizeBytes: null),
      );

      expect(song.duration, isNull);
      expect(song.sizeInBytes, isNull);
    });

    test('a missing artist shows no subtitle', () {
      expect(
        DeviceAudioDataSourceImpl.fromRow(row(artist: null)).subtitle,
        isNull,
      );
    });
  });
}
