import 'package:convertly/features/converter/presentation/widgets/clip_timeline_strip.dart';
import 'package:convertly/core/i18n/app_translations.dart';
import 'package:convertly/core/widgets/neon_backdrop.dart';
import 'package:convertly/features/converter/domain/entities/mix_track.dart';
import 'package:convertly/features/converter/presentation/controllers/timeline_preview_controller.dart';
import 'package:convertly/core/enums/tool_mode.dart';
import 'package:convertly/core/services/output_directory_service.dart';
import 'package:convertly/core/services/ffmpeg_service.dart';
import 'package:convertly/core/services/waveform_service.dart';
import 'package:convertly/features/converter/presentation/controllers/trim_waveform_controller.dart';
import 'package:convertly/features/converter/presentation/controllers/trim_preview_controller.dart';
import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/core/types/result.dart';
import 'package:convertly/features/converter/domain/entities/conversion_request.dart';
import 'package:convertly/features/converter/domain/entities/conversion_result.dart';
import 'package:convertly/features/converter/domain/entities/media_info.dart';
import 'package:convertly/features/converter/domain/repositories/conversion_repository.dart';
import 'package:convertly/features/converter/domain/repositories/media_repository.dart';
import 'package:convertly/features/converter/domain/usecases/convert_media.dart';
import 'package:convertly/features/converter/domain/usecases/pick_media.dart';
import 'package:convertly/features/converter/presentation/controllers/converter_controller.dart';
import 'package:convertly/features/converter/presentation/pages/converter_page.dart';
import 'package:convertly/features/files/domain/entities/media_file.dart';
import 'package:convertly/features/files/domain/repositories/media_library_repository.dart';
import 'package:convertly/features/files/domain/usecases/media_library_usecases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

MediaFile _file(int id, String name) => MediaFile(
  id: id,
  name: name,
  originalName: name,
  path: '/library/$name',
  type: MediaFileType.audio,
  format: 'mp3',
  sizeInBytes: id * 1024,
  createdAt: DateTime(2026, 9, id),
  sourceType: MediaSourceType.audioConvert,
  duration: Duration(seconds: id * 10),
);

class _StaticWaveforms extends WaveformService {
  _StaticWaveforms() : super(FfmpegService(), OutputDirectoryService());

  @override
  Future<List<double>?> peaksFor(String source) async => List.filled(80, 0.6);
}

class _MediaRepository implements MediaRepository {
  @override
  Future<Result<MediaInfo>> inspect(String path) async =>
      Result<MediaInfo>.success(
        MediaInfo(
          path: path,
          name: path.split('/').last,
          sizeInBytes: 1024,
          extension: 'mp3',
          hasAudio: true,
          hasVideo: false,
          duration: const Duration(seconds: 30),
        ),
      );

  @override
  Future<Result<MediaInfo?>> pickAudio() async =>
      const Result<MediaInfo?>.success(null);

  @override
  Future<Result<List<MediaInfo>>> pickAudioFiles() async =>
      const Result<List<MediaInfo>>.success(<MediaInfo>[]);

  @override
  Future<Result<MediaInfo?>> pickVideo() async =>
      const Result<MediaInfo?>.success(null);
}

class _LibraryRepository implements MediaLibraryRepository {
  _LibraryRepository(this.files);

  final List<MediaFile> files;

  @override
  Future<Result<List<MediaFile>>> getAll() async =>
      Result<List<MediaFile>>.success(files);

  @override
  Future<Result<MediaFile>> add(MediaFile file) async =>
      Result<MediaFile>.success(file);

  @override
  Future<Result<void>> delete(MediaFile file) => throw UnimplementedError();

  @override
  Future<Result<int>> deleteMany(List<MediaFile> files) =>
      throw UnimplementedError();

  @override
  Future<Result<int>> pruneMissing() => throw UnimplementedError();

  @override
  Future<Result<MediaFile>> rename(MediaFile file, String newName) =>
      throw UnimplementedError();
}

class _ConversionRepository implements ConversionRepository {
  @override
  Future<void> cancel() async {}

  @override
  Future<Result<ConversionResult>> convert(
    ConversionRequest request, {
    void Function(double progress)? onProgress,
  }) => throw UnimplementedError();

  @override
  Future<Result<String>> resolveOutputDirectory() async =>
      const Result<String>.success('/out');
}

void main() {
  late _MediaRepository media;
  late _LibraryRepository library;

  setUp(() {
    media = _MediaRepository();
    library = _LibraryRepository(<MediaFile>[
      _file(1, 'Summer song.mp3'),
      _file(2, 'Winter mix.mp3'),
      _file(3, 'Rain sounds.mp3'),
    ]);
  });

  tearDown(Get.reset);

  ConverterController controllerFor(ToolMode mode) => ConverterController(
    mode,
    PickVideo(media),
    PickAudio(media),
    PickAudioFiles(media),
    ConvertMedia(_ConversionRepository()),
    CancelConversion(_ConversionRepository()),
    AddMediaFile(library),
    OutputDirectoryService(),
    GetMediaFiles(library),
    InspectMedia(media),
  );

  testWidgets('cutter shows bounds once and resets from the waveform header', (
    tester,
  ) async {
    final controller = controllerFor(ToolMode.cut);
    Get.put<ConverterController>(controller);
    Get.put<TrimPreviewController>(TrimPreviewController());
    controller.sources.assignAll(<MediaInfo>[
      const MediaInfo(
        path: '/music/song.mp3',
        name: 'Song.mp3',
        sizeInBytes: 1000,
        extension: 'mp3',
        hasAudio: true,
        hasVideo: false,
        duration: Duration(seconds: 166),
      ),
    ]);
    controller.setTrimRange(
      const Duration(seconds: 40),
      const Duration(seconds: 132),
    );
    Get.put<TrimWaveformController>(TrimWaveformController(_StaticWaveforms()));
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        theme: AppTheme.dark,
        home: const ConverterPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0:40'), findsOneWidget);
    expect(find.text('2:12'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Add from phone')).dy,
      tester.getCenter(find.text('Add from app')).dy,
    );
    expect(
      tester.getTopLeft(find.text('Reset')).dy,
      lessThan(tester.getTopLeft(find.text('Start')).dy),
    );
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(controller.trimStart.value, Duration.zero);
    expect(controller.trimEnd.value, const Duration(seconds: 166));
    expect(tester.takeException(), isNull);
  });

  Future<void> openPicker(
    WidgetTester tester,
    ConverterController controller,
  ) async {
    Get.put<ConverterController>(controller);
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.dark, home: const ConverterPage()),
    );
    await tester.pump();
    await tester.tap(find.text('Add from app'));
    await tester.pumpAndSettle();
  }

  testWidgets('timeline app picker is tall, searchable, and multi-selectable', (
    WidgetTester tester,
  ) async {
    await openPicker(tester, controllerFor(ToolMode.arrange));

    expect(
      find.byKey(const ValueKey<String>('library-search-field')),
      findsOne,
    );
    expect(
      tester.getTopLeft(find.byType(BottomSheet)).dy,
      lessThan(
        tester.view.physicalSize.height / tester.view.devicePixelRatio * .2,
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('library-search-field')),
      'winter',
    );
    await tester.pump();

    expect(find.text('Winter mix.mp3'), findsOne);
    expect(find.text('Summer song.mp3'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    await tester.tap(find.text('Summer song.mp3'));
    await tester.tap(find.text('Winter mix.mp3'));
    await tester.pump();

    expect(find.text('Add 2 files'), findsOne);
  });

  testWidgets('single-file tools keep only the latest selected file', (
    WidgetTester tester,
  ) async {
    final ConverterController controller = controllerFor(ToolMode.cut);
    Get.put<ConverterController>(controller);
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.dark, home: const ConverterPage()),
    );
    await tester.pump();
    await tester.tap(find.text('Add from app'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Summer song.mp3'));
    await tester.tap(find.text('Winter mix.mp3'));
    await tester.pump();

    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOne);
    expect(find.text('Add selected file'), findsOne);
  });

  test('a batch is inspected and appended in selection order', () async {
    final ConverterController controller = controllerFor(ToolMode.arrange);

    await controller.pickFromLibraryFiles(<MediaFile>[
      library.files[1],
      library.files[0],
    ]);

    expect(controller.sources.map((MediaInfo source) => source.name), <String>[
      'Winter mix.mp3',
      'Summer song.mp3',
    ]);
  });
  testWidgets(
    'timeline keeps export visible and updates its total after trimming',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final ConverterController controller = controllerFor(ToolMode.arrange);
      Get.put<ConverterController>(controller);
      Get.put<TimelinePreviewController>(TimelinePreviewController());
      controller.fileName.value = 'timeline_audio';
      controller.sources.assignAll(<MediaInfo>[
        MediaInfo(
          path: '/music/timeline_audio.mp3',
          name: 'timeline_audio.mp3',
          sizeInBytes: 24600000,
          extension: 'mp3',
          hasAudio: true,
          hasVideo: false,
          duration: const Duration(minutes: 17, seconds: 55),
        ),
        MediaInfo(
          path: '/music/song.mp3',
          name: 'SIMMBA_ Tere Bin _ Ranveer Singh.mp3',
          sizeInBytes: 4900000,
          extension: 'mp3',
          hasAudio: true,
          hasVideo: false,
          duration: const Duration(minutes: 3, seconds: 35),
        ),
      ]);
      controller.clips.assignAll(const <MixTrack>[
        MixTrack(length: Duration(minutes: 17, seconds: 55)),
        MixTrack(
          start: Duration(minutes: 17, seconds: 55),
          length: Duration(minutes: 3, seconds: 35),
        ),
      ]);
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en'),
          theme: AppTheme.dark,
          builder: (context, child) => NeonBackdrop(child: child!),
          home: const ConverterPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your clips · 2'), findsOneWidget);
      final clipsToggle = find.byKey(
        const ValueKey<String>('timeline-clips-toggle'),
      );
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
      await tester.tap(clipsToggle);
      await tester.pumpAndSettle();
      expect(find.byType(ReorderableDragStartListener), findsNothing);
      expect(find.text('Your clips · 2'), findsOneWidget);
      expect(find.text('Add from phone').hitTestable(), findsOneWidget);
      await tester.tap(clipsToggle);
      await tester.pumpAndSettle();
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Build Track'),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.text('Total length 21:30'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Build Track').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // Exercise the real scrolling page and controller, not just the list callback.
      final drag = await tester.startGesture(
        tester.getTopLeft(find.byType(ReorderableDragStartListener).first) +
            const Offset(100, 3),
      );
      for (int step = 0; step < 20; step++) {
        await drag.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await drag.up();
      await tester.pumpAndSettle();
      expect(
        controller.sources.first.name,
        'SIMMBA_ Tere Bin _ Ranveer Singh.mp3',
      );
      expect(
        controller.startOfTrack(1),
        const Duration(minutes: 3, seconds: 35),
      );
      expect(find.text('Total length 21:30'), findsOneWidget);
      expect(tester.takeException(), isNull);
      controller.reorderSources(1, 0);
      await tester.pumpAndSettle();

      controller.setClipTrim(0, Duration.zero, const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('Total length 4:05'), findsOneWidget);
      final ScrollableState pageScroll = tester.state(
        find.byType(Scrollable).first,
      );
      pageScroll.position.jumpTo(0);
      await tester.pumpAndSettle();
      // The waveform blocks also reorder the real sources and keep trims.
      final waveformDrag = await tester.startGesture(
        tester.getCenter(find.byKey(ClipTimelineStrip.blockKey(1))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await waveformDrag.moveTo(
        tester.getCenter(find.byKey(ClipTimelineStrip.blockKey(0))),
      );
      await tester.pump();
      await waveformDrag.up();
      await tester.pumpAndSettle();
      expect(
        controller.sources.first.name,
        'SIMMBA_ Tere Bin _ Ranveer Singh.mp3',
      );
      expect(controller.usedLengthOf(1), const Duration(seconds: 30));
      expect(
        controller.startOfTrack(1),
        const Duration(minutes: 3, seconds: 35),
      );
      expect(find.text('Total length 4:05'), findsOneWidget);
      expect(tester.takeException(), isNull);

      pageScroll.position.jumpTo(pageScroll.position.maxScrollExtent);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('File name'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('File name'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Build Track').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
