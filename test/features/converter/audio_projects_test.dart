import 'dart:async';
import 'dart:io';

import 'package:convertly/core/enums/audio_format.dart';
import 'package:convertly/core/enums/audio_quality.dart';
import 'package:convertly/core/enums/export_speed.dart';
import 'package:convertly/core/enums/mix_length_mode.dart';
import 'package:convertly/core/enums/tool_mode.dart';
import 'package:convertly/core/errors/failure.dart';
import 'package:convertly/core/i18n/app_translations.dart';
import 'package:convertly/core/services/output_directory_service.dart';
import 'package:convertly/core/services/storage_service.dart';
import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/core/types/result.dart';
import 'package:convertly/features/converter/data/audio_project_store.dart';
import 'package:convertly/features/converter/domain/entities/audio_project.dart';
import 'package:convertly/features/converter/domain/entities/conversion_request.dart';
import 'package:convertly/features/converter/domain/entities/conversion_result.dart';
import 'package:convertly/features/converter/domain/entities/media_info.dart';
import 'package:convertly/features/converter/domain/entities/volume_envelope.dart';
import 'package:convertly/features/converter/domain/usecases/convert_media.dart';
import 'package:convertly/features/converter/domain/usecases/pick_media.dart';
import 'package:convertly/features/converter/presentation/controllers/converter_controller.dart';
import 'package:convertly/features/converter/presentation/controllers/mix_preview_controller.dart';
import 'package:convertly/features/converter/presentation/pages/converter_page.dart';
import 'package:convertly/features/converter/presentation/widgets/audio_project_panel.dart';
import 'package:convertly/features/files/domain/usecases/media_library_usecases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mixer_controller_test.dart' as fixtures;

class _Directories extends OutputDirectoryService {
  _Directories(this.directory);
  final Directory directory;
  @override
  Future<Directory> resolve() async => directory;
}

class _Conversion extends fixtures.UnusedConversionRepository {
  Result<ConversionResult>? outcome;
  int calls = 0;
  @override
  Future<Result<ConversionResult>> convert(
    ConversionRequest request, {
    void Function(double progress)? onProgress,
  }) async {
    calls++;
    return outcome ??
        const Result<ConversionResult>.failure(ConversionFailure());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late StorageService storage;
  late AudioProjectStore store;
  late fixtures.FakeMediaRepository media;
  late _Conversion conversion;
  WidgetTester? activeTester;
  final List<ConverterController> controllers = <ConverterController>[];

  setUp(() async {
    activeTester = null;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    storage = StorageService(await SharedPreferences.getInstance());
    directory = await Directory.systemTemp.createTemp('audio_projects_test_');
    store = AudioProjectStore(
      storage,
      directory: () async => Directory('${directory.path}/projects'),
    );
    Get.put<AudioProjectStore>(store, permanent: true);
    media = fixtures.FakeMediaRepository();
    conversion = _Conversion();
    AppTranslations.install();
  });

  tearDown(() async {
    Future<void> cleanUp() async {
      for (final ConverterController controller in controllers) {
        await controller.saveProject();
        if (Get.isRegistered<ConverterController>() &&
            identical(Get.find<ConverterController>(), controller)) {
          Get.delete<ConverterController>(force: true);
        } else if (!controller.isClosed) {
          controller.onClose();
        }
      }
      controllers.clear();
      Get.reset();
      await directory.delete(recursive: true);
    }

    if (activeTester != null) {
      await activeTester!.runAsync(cleanUp);
    } else {
      await cleanUp();
    }
  });

  ConverterController controllerFor(ToolMode mode, {bool register = false}) {
    final fixtures.UnusedLibraryRepository library =
        fixtures.UnusedLibraryRepository();
    final ConverterController controller = ConverterController(
      mode,
      PickVideo(media),
      PickAudio(media),
      PickAudioFiles(media),
      ConvertMedia(conversion),
      CancelConversion(conversion),
      AddMediaFile(library),
      _Directories(directory),
      GetMediaFiles(library),
      InspectMedia(media),
    );
    if (register) {
      Get.put<ConverterController>(controller);
    } else {
      controller.onInit();
    }
    controllers.add(controller);
    return controller;
  }

  Future<void> pick(ConverterController controller) async {
    media.nextPick = <MediaInfo>[
      for (int index = 0; index < 2; index++)
        MediaInfo(
          path: (await File(
            '${directory.path}/source_$index.mp3',
          ).writeAsBytes(<int>[1, 2, 3, index])).path,
          name: 'source_$index.mp3',
          sizeInBytes: 4,
          extension: 'mp3',
          hasAudio: true,
          hasVideo: false,
          duration: Duration(seconds: 40 + index * 20),
        ),
    ];
    await controller.pickSource();
  }

  for (final ToolMode mode in <ToolMode>[ToolMode.arrange, ToolMode.mix]) {
    test(
      '$mode survives restart with inputs and all editing settings',
      () async {
        final ConverterController controller = controllerFor(mode);
        await pick(controller);
        if (mode.isTimeline) {
          controller.setClipTrim(
            0,
            const Duration(seconds: 5),
            const Duration(seconds: 25),
          );
        } else {
          controller.setTrackVolume(1, 0.3);
          controller.setEnvelope(1, VolumeEnvelope.dip());
          controller.setMixLength(MixLengthMode.mainTrack);
          controller.setLoopShorterTracks(true);
        }
        controller.reorderSources(1, 0);
        controller.setFileName('My saved work');
        controller.setFormat(AudioFormat.m4a);
        controller.setQuality(AudioQuality.kbps320);
        controller.setSpeed(ExportSpeed.oneAndHalf);
        expect(await controller.saveProject(), isTrue);
        final AudioProject saved = store.projects.single;
        final AudioProjectStore restarted = AudioProjectStore(
          storage,
          directory: () async => Directory('${directory.path}/projects'),
        );
        final AudioProject restored = restarted.projects.single;
        expect(restored.clips, controller.clips.toList());
        expect(
          restored.sources.map((MediaInfo source) => source.name),
          controller.sources.map((MediaInfo source) => source.name),
        );
        expect(restored.format, AudioFormat.m4a);
        expect(restored.quality, AudioQuality.kbps320);
        expect(restored.speed, ExportSpeed.oneAndHalf);
        expect(restored.mixLength, controller.mixLength.value);
        expect(restored.loopShorterTracks, controller.loopShorterTracks.value);
        expect(restored.fileName, 'My saved work');
        expect(restored.status, AudioProjectStatus.draft);
        for (final MediaInfo source in controller.sources) {
          await File(source.path).delete();
        }
        for (final MediaInfo source in restored.sources) {
          expect(await File(source.path).readAsBytes(), hasLength(4));
        }
        expect(await controller.openProject(saved), isTrue);
        expect(controller.clips, saved.clips);
        controller.setFileName('Updated work');
        expect(await controller.saveProject(), isTrue);
        expect(store.projects, hasLength(1));
        expect(store.projects.single.id, saved.id);
        expect(store.projects.single.fileName, 'Updated work');
      },
    );
  }

  test(
    'reopening a tool resumes its latest draft, keeping the tools separate',
    () async {
      final ConverterController timeline = controllerFor(ToolMode.arrange);
      await pick(timeline);
      timeline.setFileName('Timeline draft');
      await timeline.saveProject();
      final ConverterController mixer = controllerFor(ToolMode.mix);
      expect(mixer.sources, isEmpty);
      final ConverterController reopened = controllerFor(ToolMode.arrange);
      expect(reopened.fileName.value, 'Timeline draft');
      expect(reopened.sources, hasLength(2));
      expect(
        reopened.sources.first.path,
        store.projects.single.sources.first.path,
      );
    },
  );

  test(
    'cancelled work persists and editing it returns it to in progress',
    () async {
      final ConverterController controller = controllerFor(ToolMode.mix);
      await pick(controller);
      expect(await controller.cancelProject(), isTrue);
      expect(store.projects.single.status, AudioProjectStatus.cancelled);
      expect(controller.projectStatus.value, AudioProjectStatus.cancelled);
      expect(await controller.saveProject(), isTrue);
      expect(store.projects.single.status, AudioProjectStatus.cancelled);
      controller.setTrackVolume(0, 0.5);
      await controller.saveProject();
      expect(store.projects.single.status, AudioProjectStatus.draft);
    },
  );

  test('new work leaves the previous project intact', () async {
    final ConverterController controller = controllerFor(ToolMode.arrange);
    await pick(controller);
    controller.setFileName('First');
    await controller.newProject();
    expect(controller.sources, isEmpty);
    await pick(controller);
    controller.setFileName('Second');
    await controller.saveProject();
    expect(
      store.projects.map((AudioProject p) => p.fileName),
      containsAll(<String>['First', 'Second']),
    );
    expect(store.projects, hasLength(2));
  });

  test('other tools never create projects', () async {
    for (final ToolMode mode in ToolMode.values.where(
      (ToolMode mode) => !mode.combinesTracks,
    )) {
      final ConverterController controller = controllerFor(mode);
      await pick(controller);
      await controller.saveProject();
      expect(controller.supportsProjects, isFalse);
    }
    expect(store.projects, isEmpty);
  });

  test(
    'an existing editor enables projects from storage without losing clips',
    () async {
      Get.reset();
      final ConverterController controller = controllerFor(ToolMode.arrange);
      await pick(controller);
      controller.setClipTrim(
        0,
        const Duration(seconds: 5),
        const Duration(seconds: 20),
      );
      final sourcesBefore = controller.sources.toList();
      final clipsBefore = controller.clips.toList();
      expect(controller.projectStore, isNull);

      // Reproduce an app session started before project startup registration.
      Get.put<StorageService>(storage, permanent: true);
      controller.initializeProjects();
      expect(Get.isRegistered<AudioProjectStore>(), isTrue);
      expect(controller.sources.toList(), sourcesBefore);
      expect(controller.clips.toList(), clipsBefore);

      // Use the test directory for the store's actual input copies.
      Get.replace<AudioProjectStore>(store);
      controller.initializeProjects();
      controller.setFileName('Existing timeline');
      expect(controller.projectNeedsSave.value, isTrue);
      expect(await controller.saveProject(), isTrue);
      expect(store.projects.single.clips, clipsBefore);
      expect(store.projects.single.fileName, 'Existing timeline');
    },
  );

  test(
    'editing automatically saves a draft without an explicit save',
    () async {
      final Completer<void> saved = Completer<void>();
      final Worker watcher = ever(store.projects, (_) {
        if (store.projects.isNotEmpty && !saved.isCompleted) saved.complete();
      });
      final ConverterController controller = controllerFor(ToolMode.arrange);
      await pick(controller);
      controller.setFileName('Automatically saved');
      try {
        await saved.future.timeout(const Duration(seconds: 5));
        expect(store.projects.single.fileName, 'Automatically saved');
        expect(store.projects.single.status, AudioProjectStatus.draft);
        expect(store.projects.single.sources, hasLength(2));
      } finally {
        watcher.dispose();
      }
    },
  );

  test('later edits win when saving overlaps an input copy', () async {
    final Completer<void> copying = Completer<void>();
    final Completer<void> release = Completer<void>();
    int copies = 0;
    store = AudioProjectStore(
      storage,
      directory: () async => Directory('${directory.path}/projects'),
      copySource: (MediaInfo source, File target) async {
        copies++;
        if (!copying.isCompleted) copying.complete();
        await release.future;
        await File(source.path).copy(target.path);
      },
    );
    Get.replace<AudioProjectStore>(store);
    final ConverterController controller = controllerFor(ToolMode.mix);
    await pick(controller);
    final Future<bool> first = controller.saveProject();
    await copying.future;
    controller.setFileName('Latest edit');
    final Future<bool> second = controller.saveProject();
    release.complete();
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(store.projects.single.fileName, 'Latest edit');
    expect(copies, 2);
  });

  test(
    'a copy failure does not claim a save or replace the previous draft',
    () async {
      final ConverterController controller = controllerFor(ToolMode.arrange);
      await pick(controller);
      await controller.saveProject();
      final String previous = storage.readString(AudioProjectStore.storageKey)!;
      media.nextPick = <MediaInfo>[fixtures.track('missing')];
      await controller.pickSource();
      expect(await controller.saveProject(), isFalse);
      expect(controller.projectError.value, isNotEmpty);
      expect(storage.readString(AudioProjectStore.storageKey), previous);
      await controller.convert();
      expect(conversion.calls, 0);
      // Restore the saved snapshot so teardown can flush successfully.
      controller.removeSourceAt(controller.sources.length - 1);
      await controller.saveProject();
    },
  );

  test('a damaged index is retained rather than silently overwritten', () async {
    await storage.writeString(AudioProjectStore.storageKey, 'broken index');
    final AudioProjectStore damaged = AudioProjectStore(storage);
    expect(damaged.loadFailed, isTrue);
    final ConverterController controller = controllerFor(ToolMode.arrange);
    await pick(controller);
    await controller.saveProject();
    // Re-create the damaged index after making a valid snapshot to try saving.
    await storage.writeString(AudioProjectStore.storageKey, 'broken index');
    await expectLater(damaged.save(store.projects.single), throwsStateError);
    expect(storage.readString(AudioProjectStore.storageKey), 'broken index');
  });

  test(
    'failed exports remain in progress; cancelled exports are cancelled',
    () async {
      final ConverterController controller = controllerFor(ToolMode.mix);
      await pick(controller);
      await controller.convert();
      expect(store.projects.single.status, AudioProjectStatus.draft);
      controller.retry();
      conversion.outcome = const Result<ConversionResult>.failure(
        ConversionCancelled(),
      );
      await controller.convert();
      expect(store.projects.single.status, AudioProjectStatus.cancelled);
    },
  );

  test('successful export alone marks the project completed', () async {
    final ConverterController controller = controllerFor(ToolMode.mix);
    await pick(controller);
    conversion.outcome = const Result<ConversionResult>.success(
      ConversionResult(
        outputPath: '/out/finished.mp3',
        name: 'finished.mp3',
        sizeInBytes: 10,
        format: 'mp3',
      ),
    );
    Get.testMode = true;
    try {
      await controller.convert();
    } finally {
      Get.testMode = false;
    }
    expect(store.projects.single.status, AudioProjectStatus.completed);
    expect(store.projects.single.outputPath, '/out/finished.mp3');
  });

  testWidgets(
    'project panel and status filters fit a narrow screen with large text',
    (WidgetTester tester) async {
      activeTester = tester;
      final ConverterController controller = controllerFor(ToolMode.arrange);
      await tester.runAsync(() async {
        await pick(controller);
        await controller.saveProject();
      });
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('bn'),
          supportedLocales: AppTranslations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.dark,
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => Column(
                children: <Widget>[
                  AudioProjectPanel(
                    controller: controller,
                    onSaveLater: () {},
                    onCancel: () {},
                  ),
                  TextButton(
                    onPressed: () => showAudioProjects(context, controller),
                    child: const Text('Projects'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Projects'));
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Save for later leaves the editor and retains the draft', (
    WidgetTester tester,
  ) async {
    activeTester = tester;
    final ConverterController controller = controllerFor(
      ToolMode.mix,
      register: true,
    );
    Get.put<MixPreviewController>(MixPreviewController());
    await tester.runAsync(() async {
      await pick(controller);
      await controller.saveProject();
    });
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const ConverterPage()),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    expect(find.text('Save for later'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Save for later'));
    await tester.pumpAndSettle();
    expect(find.text('Open editor'), findsOneWidget);
    expect(find.text('Save for later'), findsNothing);
    expect(store.projects.single.status, AudioProjectStatus.draft);
    expect(store.projects.single.sources, hasLength(2));
    expect(tester.takeException(), isNull);
  });
}
