import 'package:convertly/core/services/share_service.dart';
import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/core/types/result.dart';
import 'package:convertly/features/files/domain/entities/media_file.dart';
import 'package:convertly/features/files/domain/repositories/media_library_repository.dart';
import 'package:convertly/features/files/domain/usecases/media_library_usecases.dart';
import 'package:convertly/features/files/presentation/controllers/files_controller.dart';
import 'package:convertly/features/files/presentation/pages/files_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

MediaFile _file(int id, String name) => MediaFile(
  id: id,
  name: name,
  originalName: 'source_$id.mp4',
  path: '/out/$name',
  type: MediaFileType.audio,
  format: 'MP3',
  sizeInBytes: 1024,
  createdAt: DateTime(2026, 8, id),
  sourceType: MediaSourceType.videoToAudio,
);

class _Repo implements MediaLibraryRepository {
  _Repo(this.stored);

  final List<MediaFile> stored;

  @override
  Future<Result<List<MediaFile>>> getAll() async =>
      Result<List<MediaFile>>.success(List<MediaFile>.from(stored));

  @override
  Future<Result<MediaFile>> add(MediaFile file) async =>
      Result<MediaFile>.success(file);

  @override
  Future<Result<MediaFile>> rename(MediaFile file, String newName) async =>
      Result<MediaFile>.success(file.copyWith(name: newName));

  @override
  Future<Result<void>> delete(MediaFile file) async =>
      const Result<void>.success(null);

  @override
  Future<Result<int>> deleteMany(List<MediaFile> files) async =>
      Result<int>.success(files.length);

  @override
  Future<Result<int>> pruneMissing() async => const Result<int>.success(0);
}

void main() {
  late FilesController controller;
  late _Repo repo;

  setUp(() async {
    repo = _Repo(<MediaFile>[
      _file(1, 'Summer Song.mp3'),
      _file(2, 'winter mix.mp3'),
    ]);
    controller = Get.put(
      FilesController(
        GetMediaFiles(repo),
        RenameMediaFile(repo),
        DeleteMediaFile(repo),
        DeleteMediaFiles(repo),
        PruneMissingMediaFiles(repo),
        ShareService(),
      ),
    );
    await controller.load(pruneMissing: false);
  });

  tearDown(Get.reset);

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.dark, home: const FilesPage()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('details carry what the row no longer shows', (
    WidgetTester tester,
  ) async {
    // Format, size and length left the row so it would not be a wall of
    // figures that read the same for every conversion; they have to still be
    // reachable somewhere.
    await pumpPage(tester);
    // The menu's action type is private to the page, so the button is found
    // by its icon rather than by the type it carries.
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('File details'));
    await tester.pumpAndSettle();

    expect(find.text('Size'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Format'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
  });

  testWidgets('two files from one source are told apart by tool and time', (
    WidgetTester tester,
  ) async {
    // The reported bug: running a tool twice on the same track left rows
    // that looked identical — same name, same size, same length, same day —
    // with no way to tell which tool made them or which came first.
    repo.stored
      ..clear()
      ..addAll(<MediaFile>[
        MediaFile(
          id: 10,
          name: 'A very long track name that the list has to cut_audio.mp3',
          originalName: 'clip.mp4',
          path: '/out/a.mp3',
          type: MediaFileType.audio,
          format: 'MP3',
          sizeInBytes: 4096,
          createdAt: DateTime(2026, 10, 13, 9, 37),
          sourceType: MediaSourceType.cut,
        ),
        MediaFile(
          id: 11,
          name: 'A very long track name that the list has to cut_cleaned.mp3',
          originalName: 'clip.mp4',
          path: '/out/b.mp3',
          type: MediaFileType.audio,
          format: 'MP3',
          sizeInBytes: 4096,
          createdAt: DateTime(2026, 10, 13, 9, 41),
          sourceType: MediaSourceType.cleanup,
        ),
      ]);
    await controller.load(pruneMissing: false);
    await pumpPage(tester);

    expect(find.textContaining('Audio Cutter'), findsOneWidget);
    expect(find.textContaining('Noise Remover'), findsOneWidget);
    expect(find.textContaining('09:37'), findsOneWidget);
    expect(find.textContaining('09:41'), findsOneWidget);
  });

  testWidgets('the search box is not in the body until the icon is tapped', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.text('My Files'), findsOneWidget);
  });

  testWidgets('the icon opens a box under the app bar, and closes it again', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    // The title stays: the box is not in the app bar.
    expect(find.text('My Files'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(TextField)).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy),
    );

    await tester.enterText(find.byType(TextField), 'summer');
    await tester.pumpAndSettle();
    expect(find.text('Summer Song.mp3'), findsOneWidget);
    expect(find.text('winter mix.mp3'), findsNothing);

    await tester.tap(find.byIcon(Icons.search_off_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('winter mix.mp3'), findsOneWidget);
  });

  testWidgets('rename closes cleanly and keeps the extension separate', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    final Finder firstFile = find.widgetWithText(ListTile, 'Summer Song.mp3');
    await tester.tap(
      find.descendant(of: firstFile, matching: find.byIcon(Icons.more_vert)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'Summer Song');
    expect(field.decoration?.suffixText, '.mp3');

    await tester.enterText(find.byType(TextField), 'Road Trip');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Rename file'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
