import 'package:convertly/core/enums/cleanup_mode.dart';
import 'package:convertly/core/enums/mix_length_mode.dart';
import 'package:convertly/core/enums/tool_mode.dart';
import 'package:convertly/core/services/output_directory_service.dart';
import 'package:convertly/core/types/result.dart';
import 'package:convertly/features/converter/domain/entities/media_info.dart';
import 'package:convertly/features/converter/domain/entities/mix_track.dart';
import 'package:convertly/features/converter/domain/repositories/conversion_repository.dart';
import 'package:convertly/features/converter/domain/repositories/media_repository.dart';
import 'package:convertly/features/converter/domain/entities/conversion_request.dart';
import 'package:convertly/features/converter/domain/entities/conversion_result.dart';
import 'package:convertly/features/converter/domain/usecases/convert_media.dart';
import 'package:convertly/features/converter/domain/usecases/pick_media.dart';
import 'package:convertly/features/converter/presentation/controllers/converter_controller.dart';
import 'package:convertly/features/converter/presentation/controllers/mix_preview_controller.dart';
import 'package:convertly/features/files/domain/entities/media_file.dart';
import 'package:convertly/features/files/domain/repositories/media_library_repository.dart';
import 'package:convertly/features/files/domain/usecases/media_library_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hands back whatever the test queued, so the controller's own bookkeeping is
/// what is under test rather than the picker or FFmpeg.
class FakeMediaRepository implements MediaRepository {
  List<MediaInfo> nextPick = <MediaInfo>[];

  @override
  Future<Result<List<MediaInfo>>> pickAudioFiles() async =>
      Result<List<MediaInfo>>.success(nextPick);

  @override
  Future<Result<MediaInfo?>> pickAudio() async =>
      Result<MediaInfo?>.success(nextPick.firstOrNull);

  @override
  Future<Result<MediaInfo?>> pickVideo() async =>
      Result<MediaInfo?>.success(nextPick.firstOrNull);

  @override
  Future<Result<MediaInfo>> inspect(String path) async =>
      Result<MediaInfo>.success(track(path));
}

class UnusedConversionRepository implements ConversionRepository {
  @override
  Future<Result<ConversionResult>> convert(
    ConversionRequest request, {
    void Function(double progress)? onProgress,
  }) => throw UnimplementedError();

  @override
  Future<void> cancel() async {}

  @override
  Future<Result<String>> resolveOutputDirectory() async =>
      const Result<String>.success('/out');
}

class UnusedLibraryRepository implements MediaLibraryRepository {
  @override
  Future<Result<List<MediaFile>>> getAll() async =>
      const Result<List<MediaFile>>.success(<MediaFile>[]);

  @override
  Future<Result<MediaFile>> add(MediaFile file) async =>
      Result<MediaFile>.success(file);

  @override
  Future<Result<MediaFile>> rename(MediaFile file, String newName) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> delete(MediaFile file) => throw UnimplementedError();

  @override
  Future<Result<int>> deleteMany(List<MediaFile> files) =>
      throw UnimplementedError();

  @override
  Future<Result<int>> pruneMissing() => throw UnimplementedError();
}

/// A readable stand-in for a picked file.
MediaInfo track(String name, {Duration? duration, int? channels}) {
  return MediaInfo(
    path: '/in/$name.mp3',
    name: '$name.mp3',
    sizeInBytes: 1024,
    extension: 'mp3',
    hasAudio: true,
    hasVideo: false,
    duration: duration,
    channels: channels,
  );
}

void main() {
  late FakeMediaRepository media;

  ConverterController controllerFor(ToolMode mode) {
    return ConverterController(
      mode,
      PickVideo(media),
      PickAudio(media),
      PickAudioFiles(media),
      ConvertMedia(UnusedConversionRepository()),
      CancelConversion(UnusedConversionRepository()),
      AddMediaFile(UnusedLibraryRepository()),
      OutputDirectoryService(),
      GetMediaFiles(UnusedLibraryRepository()),
      InspectMedia(media),
    );
  }

  /// Loads [names] into the controller through the picker.
  Future<ConverterController> mixerWith(List<String> names) async {
    final ConverterController controller = controllerFor(ToolMode.mix);
    media.nextPick = names.map((String name) => track(name)).toList();
    await controller.pickSource();
    return controller;
  }

  setUp(() => media = FakeMediaRepository());

  group('mixer track volumes', () {
    test(
      'the first track comes in untouched and later ones sit lower',
      () async {
        final ConverterController controller = await mixerWith(<String>[
          'song',
          'rain',
          'crowd',
        ]);

        expect(controller.clipAt(0).volume, 1);
        expect(
          controller.clips.skip(1).map((MixTrack c) => c.volume),
          everyElement(lessThan(1)),
        );
      },
    );

    test('there is exactly one volume per track', () async {
      final ConverterController controller = await mixerWith(<String>[
        'song',
        'rain',
      ]);

      expect(controller.clips, hasLength(controller.sources.length));
    });

    test('removing a track takes its volume with it', () async {
      final ConverterController controller = await mixerWith(<String>[
        'song',
        'rain',
        'crowd',
      ]);
      controller.setTrackVolume(2, 0.2);

      controller.removeSourceAt(1);

      expect(controller.sources.map((MediaInfo info) => info.name), <String>[
        'song.mp3',
        'crowd.mp3',
      ]);
      // The surviving track keeps its own level rather than inheriting the
      // one that used to sit at its new index.
      expect(controller.clipAt(1).volume, 0.2);
    });

    test('a reordered track carries its volume to the new position', () async {
      final ConverterController controller = await mixerWith(<String>[
        'song',
        'rain',
      ]);
      controller.setTrackVolume(1, 0.15);

      controller.reorderSources(1, 0);

      expect(controller.sources.first.name, 'rain.mp3');
      expect(controller.clipAt(0).volume, 0.15);
      expect(controller.clipAt(1).volume, 1);
    });

    test('files added later extend the list instead of replacing it', () async {
      final ConverterController controller = await mixerWith(<String>['song']);
      controller.setTrackVolume(0, 0.8);

      media.nextPick = <MediaInfo>[track('rain')];
      await controller.pickSource();

      expect(controller.clips, hasLength(2));
      expect(controller.clipAt(0).volume, 0.8);
    });

    test(
      'a single-input tool replaces its source rather than stacking',
      () async {
        final ConverterController controller = controllerFor(ToolMode.cleanup);
        media.nextPick = <MediaInfo>[track('song')];
        await controller.pickSource();
        media.nextPick = <MediaInfo>[track('other')];
        await controller.pickSource();

        expect(controller.sources, hasLength(1));
        expect(controller.clips, hasLength(1));
        expect(controller.sources.single.name, 'other.mp3');
      },
    );
  });

  group('mixer length', () {
    test('a mix runs as long as its longest track', () async {
      final ConverterController controller = controllerFor(ToolMode.mix);
      media.nextPick = <MediaInfo>[
        track('song', duration: const Duration(minutes: 3)),
        track('rain', duration: const Duration(minutes: 5)),
      ];
      await controller.pickSource();

      expect(controller.sourceDuration, const Duration(minutes: 5));
    });

    test('looping layers makes the main track set the length', () async {
      final ConverterController controller = controllerFor(ToolMode.mix);
      media.nextPick = <MediaInfo>[
        track('song', duration: const Duration(minutes: 3)),
        track('rain', duration: const Duration(minutes: 5)),
      ];
      await controller.pickSource();

      controller
        ..setMixLength(MixLengthMode.longestTrack)
        ..setLoopShorterTracks(true);

      expect(controller.sourceDuration, const Duration(minutes: 3));
    });
  });

  group('export gating', () {
    test('one track is not a mix', () async {
      final ConverterController controller = await mixerWith(<String>['song']);

      expect(controller.canConvert, isFalse);
    });

    test('a second track unlocks the export', () async {
      final ConverterController controller = await mixerWith(<String>[
        'song',
        'rain',
      ]);

      expect(controller.canConvert, isTrue);
    });

    test('vocal removal is blocked on a mono track', () async {
      final ConverterController controller = controllerFor(ToolMode.cleanup);
      media.nextPick = <MediaInfo>[track('voice', channels: 1)];
      await controller.pickSource();

      controller.setCleanupMode(CleanupMode.removeVocals);

      expect(controller.isCleanupUnsupported, isTrue);
      expect(controller.canConvert, isFalse);
    });

    test('vocal removal is allowed on a stereo track', () async {
      final ConverterController controller = controllerFor(ToolMode.cleanup);
      media.nextPick = <MediaInfo>[track('song', channels: 2)];
      await controller.pickSource();

      controller.setCleanupMode(CleanupMode.removeVocals);

      expect(controller.isCleanupUnsupported, isFalse);
      expect(controller.canConvert, isTrue);
    });

    test('an unknown channel count does not block the export', () async {
      final ConverterController controller = controllerFor(ToolMode.cleanup);
      media.nextPick = <MediaInfo>[track('song')];
      await controller.pickSource();

      controller.setCleanupMode(CleanupMode.removeVocals);

      expect(controller.isCleanupUnsupported, isFalse);
    });

    test('denoising is never blocked by the channel count', () async {
      final ConverterController controller = controllerFor(ToolMode.cleanup);
      media.nextPick = <MediaInfo>[track('voice', channels: 1)];
      await controller.pickSource();

      expect(controller.isCleanupUnsupported, isFalse);
      expect(controller.canConvert, isTrue);
    });
  });

  group('preview levels', () {
    test('levels at or below full scale are left alone', () {
      expect(
        MixPreviewController.previewVolumes(<double>[1, 0.6, 0.25]),
        <double>[1, 0.6, 0.25],
      );
    });

    test('a boosted layer scales the group instead of being clipped', () {
      // 200% cannot be played as-is, so everything drops by the same factor
      // and the balance the user set survives.
      expect(MixPreviewController.previewVolumes(<double>[1, 2]), <double>[
        0.5,
        1,
      ]);
    });

    test('relative balance is preserved through the scaling', () {
      final List<double> levels = MixPreviewController.previewVolumes(<double>[
        1.5,
        0.75,
      ]);

      expect(levels[0] / levels[1], closeTo(2, 0.0001));
    });

    test('every level stays inside what a player accepts', () {
      final List<double> levels = MixPreviewController.previewVolumes(<double>[
        0,
        0.4,
        1,
        2,
      ]);

      expect(levels, everyElement(inInclusiveRange(0, 1)));
    });

    test('a silent track stays silent', () {
      expect(MixPreviewController.previewVolumes(<double>[1, 0])[1], 0);
    });
  });

  group('Audio Timeline stays gapless', () {
    /// Loads clips of the given lengths into the timeline tool.
    Future<ConverterController> timelineWith(
      List<(String, Duration?)> clips,
    ) async {
      final ConverterController controller = controllerFor(ToolMode.arrange);
      media.nextPick = <MediaInfo>[
        for (final (String name, Duration? length) in clips)
          track(name, duration: length),
      ];
      await controller.pickSource();
      return controller;
    }

    /// The case this tool was built for: a 40s clip, then a 20s one.
    Future<ConverterController> twoClips() =>
        timelineWith(<(String, Duration?)>[
          ('one', const Duration(seconds: 40)),
          ('two', const Duration(seconds: 20)),
        ]);

    Future<ConverterController> threeClips() =>
        timelineWith(<(String, Duration?)>[
          ('one', const Duration(seconds: 40)),
          ('two', const Duration(seconds: 20)),
          ('three', const Duration(seconds: 15)),
        ]);

    test('a clip begins exactly where the previous one ends', () async {
      final ConverterController controller = await twoClips();

      expect(controller.clips.map((MixTrack c) => c.start), <Duration>[
        Duration.zero,
        const Duration(seconds: 40),
      ]);
      expect(controller.sourceDuration, const Duration(seconds: 60));
    });

    test('the total is the clips added up, with nothing in between', () async {
      final ConverterController controller = await threeClips();

      expect(controller.sourceDuration, const Duration(seconds: 75));
    });

    test('removing a clip closes the space it left', () async {
      final ConverterController controller = await threeClips();

      controller.removeSourceAt(0);

      // What was second now starts the track rather than waiting 40 seconds.
      expect(controller.clips.map((MixTrack c) => c.start), <Duration>[
        Duration.zero,
        const Duration(seconds: 20),
      ]);
      expect(controller.sourceDuration, const Duration(seconds: 35));
    });

    test('reordering leaves no hole where the clip used to be', () async {
      final ConverterController controller = await twoClips();

      controller.reorderSources(1, 0);

      expect(controller.sources.first.name, 'two.mp3');
      expect(controller.clips.map((MixTrack c) => c.start), <Duration>[
        Duration.zero,
        const Duration(seconds: 20),
      ]);
      expect(controller.sourceDuration, const Duration(seconds: 60));
    });

    test('a clip added later lands right after the last one', () async {
      final ConverterController controller = await twoClips();

      media.nextPick = <MediaInfo>[
        track('three', duration: const Duration(seconds: 15)),
      ];
      await controller.pickSource();

      expect(
        controller.startOfTrack(controller.clips.length - 1),
        const Duration(seconds: 60),
      );
    });

    test('no clip ever sits past the end of the one before it', () async {
      final ConverterController controller = await threeClips();

      for (int index = 1; index < controller.sources.length; index++) {
        final Duration previousEnd =
            controller.startOfTrack(index - 1) +
            controller.sources[index - 1].duration!;
        expect(controller.startOfTrack(index), previousEnd);
      }
    });

    test('a clip of unknown length does not shift the rest', () async {
      final ConverterController controller =
          await timelineWith(<(String, Duration?)>[
            ('one', const Duration(seconds: 30)),
            ('unknown', null),
            ('three', const Duration(seconds: 10)),
          ]);

      // An unmeasurable clip adds nothing to the running position, so what
      // follows still lines up against what could be measured.
      expect(controller.clips.map((MixTrack c) => c.start), <Duration>[
        Duration.zero,
        const Duration(seconds: 30),
        const Duration(seconds: 30),
      ]);
    });

    test('every clip comes in at full level', () async {
      final ConverterController controller = await twoClips();

      expect(controller.clips.map((MixTrack c) => c.volume), everyElement(1.0));
    });

    test('the export is named for the tool', () async {
      final ConverterController controller = await twoClips();

      expect(controller.canConvert, isTrue);
      expect(controller.fileName.value, 'timeline_audio');
    });
  });

  group('the mixer still stacks', () {
    test('clips all start together rather than in sequence', () async {
      final ConverterController controller = controllerFor(ToolMode.mix);
      media.nextPick = <MediaInfo>[
        track('song', duration: const Duration(seconds: 40)),
        track('rain', duration: const Duration(seconds: 20)),
      ];
      await controller.pickSource();

      expect(controller.clips.map((MixTrack c) => c.start), <Duration>[
        Duration.zero,
        Duration.zero,
      ]);
      // The layered mix is as long as its longest track, not their sum.
      expect(controller.sourceDuration, const Duration(seconds: 40));
    });

    test('a layer still comes in below the main track', () async {
      final ConverterController controller = controllerFor(ToolMode.mix);
      media.nextPick = <MediaInfo>[track('song'), track('rain')];
      await controller.pickSource();

      expect(controller.clipAt(0).volume, 1);
      expect(controller.clipAt(1).volume, lessThan(1));
    });
  });

  group('cutting a clip down', () {
    Future<ConverterController> twoClips() async {
      final ConverterController controller = controllerFor(ToolMode.arrange);
      media.nextPick = <MediaInfo>[
        track('one', duration: const Duration(seconds: 40)),
        track('two', duration: const Duration(seconds: 20)),
      ];
      await controller.pickSource();
      return controller;
    }

    test('a clip starts out whole', () async {
      final ConverterController controller = await twoClips();

      expect(controller.clipAt(0).isTrimmed, isFalse);
      expect(controller.trimRangeOf(0), (
        Duration.zero,
        const Duration(seconds: 40),
      ));
    });

    test('only the selected part takes up room on the timeline', () async {
      final ConverterController controller = await twoClips();

      // Keep 0:10 to 0:25 of the first clip: 15 seconds instead of 40.
      controller.setClipTrim(
        0,
        const Duration(seconds: 10),
        const Duration(seconds: 25),
      );

      expect(controller.usedLengthOf(0), const Duration(seconds: 15));
      expect(controller.sourceDuration, const Duration(seconds: 35));
    });

    test('trimming pulls the clips after it earlier', () async {
      final ConverterController controller = await twoClips();

      controller.setClipTrim(0, Duration.zero, const Duration(seconds: 10));

      // The second clip follows immediately: no silence is left behind.
      expect(controller.startOfTrack(1), const Duration(seconds: 10));
    });

    test('a selection cannot run past the end of the file', () async {
      final ConverterController controller = await twoClips();

      controller.setClipTrim(
        1,
        const Duration(seconds: 5),
        const Duration(minutes: 10),
      );

      expect(controller.trimRangeOf(1).$2, const Duration(seconds: 20));
    });

    test('an empty or inverted selection is refused', () async {
      final ConverterController controller = await twoClips();

      controller.setClipTrim(
        0,
        const Duration(seconds: 30),
        const Duration(seconds: 10),
      );

      // The clip keeps the selection it had rather than becoming unplayable.
      expect(controller.clipAt(0).isTrimmed, isFalse);
      expect(controller.usedLengthOf(0), const Duration(seconds: 40));
    });

    test('a negative start is pulled back to zero', () async {
      final ConverterController controller = await twoClips();

      controller.setClipTrim(
        0,
        const Duration(seconds: -5),
        const Duration(seconds: 10),
      );

      expect(controller.trimRangeOf(0).$1, Duration.zero);
    });

    test('a trimmed clip carries its selection through a reorder', () async {
      final ConverterController controller = await twoClips();
      controller.setClipTrim(
        0,
        const Duration(seconds: 10),
        const Duration(seconds: 25),
      );

      controller.reorderSources(0, 1);

      expect(controller.sources.last.name, 'one.mp3');
      expect(controller.usedLengthOf(1), const Duration(seconds: 15));
      // It now follows the 20-second clip that moved ahead of it.
      expect(controller.startOfTrack(1), const Duration(seconds: 20));
    });

    test('the export carries the selection, not the whole file', () async {
      final ConverterController controller = await twoClips();

      controller.setClipTrim(
        0,
        const Duration(seconds: 10),
        const Duration(seconds: 25),
      );

      final MixTrack clip = controller.clipAt(0);
      expect(clip.trimStart, const Duration(seconds: 10));
      expect(clip.trimEnd, const Duration(seconds: 25));
    });
  });
}
