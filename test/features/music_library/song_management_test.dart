import 'package:convertly/core/routes/app_routes.dart';
import 'package:convertly/core/services/storage_service.dart';
import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/features/music_library/domain/entities/song.dart';
import 'package:convertly/features/music_library/domain/usecases/music_library_usecases.dart';
import 'package:convertly/features/music_library/presentation/controllers/music_library_controller.dart';
import 'package:convertly/features/music_library/presentation/pages/music_library_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'music_library_test.dart' show FakeMusicRepository, song;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeMusicRepository repository;
  late StorageService storage;

  MusicLibraryController controllerFor() => MusicLibraryController(
    GetDeviceSongs(repository),
    GetAppSongs(repository),
    EnsureDevicePermission(repository),
    renameSong: RenameSong(repository),
    deleteSong: DeleteSong(repository),
    storage: storage,
  );

  setUp(() async {
    repository = FakeMusicRepository()..granted = true;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    storage = await StorageService.init();
  });
  tearDown(Get.reset);

  test(
    'favourites survive a new controller and combine both sources',
    () async {
      final Song phone = song('Same title', SongSource.phone);
      final Song app = song('Same title', SongSource.app);
      repository
        ..device = <Song>[phone]
        ..app = <Song>[app, song('Other', SongSource.app)];
      final MusicLibraryController first = controllerFor();
      await first.load();
      await first.toggleFavourite(phone);
      await first.toggleFavourite(app);

      final MusicLibraryController restored = controllerFor();
      await restored.load();
      restored.setTab(SongTab.favourites);
      expect(restored.visibleSongs.map((Song value) => value.id), <String>[
        phone.id,
        app.id,
      ]);
      restored.setQuery('same');
      expect(restored.visibleSongs, hasLength(2));
      await restored.toggleFavourite(phone);
      expect(restored.visibleSongs.single.id, app.id);
    },
  );

  test(
    'rename preserves favourite identity and delete clears it from storage',
    () async {
      final Song original = song('Original', SongSource.app);
      repository.app = <Song>[original];
      final MusicLibraryController controller = controllerFor();
      await controller.load();
      await controller.toggleFavourite(original);
      controller.setTab(SongTab.favourites);

      expect(await controller.rename(original, 'Renamed'), isTrue);
      final Song renamed = controller.visibleSongs.single;
      expect(renamed.title, 'Renamed.mp3');
      expect(controller.isFavourite(renamed), isTrue);
      expect(await controller.delete(renamed), isTrue);
      expect(controller.visibleSongs, isEmpty);
      expect(controllerFor().favouriteIds, isEmpty);
    },
  );

  test(
    'declining Android edit or delete leaves the song and favourite intact',
    () async {
      final Song original = song('Original', SongSource.phone);
      repository
        ..device = <Song>[original]
        ..allowEdit = false;
      final MusicLibraryController controller = controllerFor();
      await controller.load();
      await controller.toggleFavourite(original);

      expect(await controller.rename(original, 'Changed'), isFalse);
      expect(await controller.delete(original), isFalse);
      expect(controller.deviceSongs.single.title, 'Original');
      expect(controller.isFavourite(original), isTrue);
      expect(controller.errorMessage.value, isEmpty);
    },
  );

  Future<MusicLibraryController> pumpLibrary(
    WidgetTester tester, {
    Size size = const Size(360, 780),
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    addTearDown(tester.view.reset);
    final MusicLibraryController controller = Get.put(controllerFor());
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark,
        home: const MusicLibraryPage(),
        getPages: <GetPage<dynamic>>[
          GetPage<dynamic>(
            name: AppRoutes.audioPlayer,
            page: () => const Scaffold(body: Text('Player')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets(
    'long press offers actions and favourites plays only its own queue',
    (WidgetTester tester) async {
      repository.device = <Song>[
        song('One', SongSource.phone),
        song('Two', SongSource.phone),
        song('Other', SongSource.phone),
      ];
      final MusicLibraryController controller = await pumpLibrary(tester);
      await tester.longPress(find.text('One'));
      await tester.pumpAndSettle();
      for (final String text in <String>[
        'Rename',
        'Delete',
        'Add to favourites',
        'File details',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      // A song the device index found is already on the phone, and its
      // content URI is not something the share sheet can open as a file.
      expect(find.text('Save to phone'), findsNothing);
      expect(find.text('Share'), findsNothing);
      await tester.tap(find.text('Add to favourites'));
      await tester.pumpAndSettle();
      await controller.toggleFavourite(repository.device[1]);
      await tester.tap(find.text('Favourites'));
      await tester.pumpAndSettle();
      expect(find.text('Other'), findsNothing);

      await tester.tap(find.byTooltip('Play all'));
      await tester.pumpAndSettle();
      final Map<String, Object> arguments =
          Get.arguments as Map<String, Object>;
      expect(arguments['index'], 0);
      expect(arguments['queue'], <Map<String, String>>[
        <String, String>{'path': '/music/One.mp3', 'title': 'One'},
        <String, String>{'path': '/music/Two.mp3', 'title': 'Two'},
      ]);
    },
  );

  testWidgets('app file details show the recorded conversion date', (
    WidgetTester tester,
  ) async {
    repository.app = <Song>[
      Song(
        id: 'app:1',
        title: 'Converted.mp3',
        path: '/music/converted.mp3',
        source: SongSource.app,
        fileName: 'Converted.mp3',
        format: 'MP3',
        sizeInBytes: 2048,
        duration: const Duration(seconds: 33),
        createdAt: DateTime(2026, 10, 12, 10, 30),
      ),
    ];
    await pumpLibrary(tester);
    await tester.tap(find.text('In app'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Converted.mp3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('File details'));
    await tester.pumpAndSettle();
    expect(find.text('Created in this app'), findsOneWidget);
    expect(find.textContaining('October 12, 2026'), findsOneWidget);
    expect(find.text('MP3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a file this app made can be saved to the phone and shared', (
    WidgetTester tester,
  ) async {
    // The app's own folder is invisible to other apps and is cleared when the
    // app is uninstalled, so these two are the only way a finished track
    // leaves it.
    repository.app = <Song>[song('Converted.mp3', SongSource.app)];
    await pumpLibrary(tester);
    await tester.tap(find.text('In app'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Converted.mp3'));
    await tester.pumpAndSettle();

    expect(find.text('Save to phone'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('rename saves from the dialog and delete requires confirmation', (
    WidgetTester tester,
  ) async {
    repository.device = <Song>[song('Original', SongSource.phone)];
    await pumpLibrary(tester);
    await tester.longPress(find.text('Original'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Renamed');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Renamed.mp3'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.longPress(find.text('Renamed.mp3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.deletes, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.deletes, 0);
    expect(find.text('Renamed.mp3'), findsOneWidget);

    await tester.longPress(find.text('Renamed.mp3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.deletes, 1);
    expect(find.text('Renamed.mp3'), findsNothing);
  });

  testWidgets('three source tabs fit a small phone', (
    WidgetTester tester,
  ) async {
    await pumpLibrary(tester, size: const Size(320, 560));
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('In app'), findsOneWidget);
    expect(find.text('Favourites'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
