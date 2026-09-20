import 'package:convertly/core/enums/tool_mode.dart';
import 'package:convertly/core/services/output_directory_service.dart';
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
    await tester.tap(find.text('App files'));
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
}
