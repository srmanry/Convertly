import 'dart:async';

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

/// A picker that stays open until the test lets it finish, standing in for a
/// large file that is still being copied in.
class _SlowMediaRepository implements MediaRepository {
  final Completer<Result<MediaInfo?>> gate = Completer<Result<MediaInfo?>>();

  @override
  Future<Result<MediaInfo?>> pickAudio() => gate.future;

  @override
  Future<Result<MediaInfo?>> pickVideo() => gate.future;

  @override
  Future<Result<List<MediaInfo>>> pickAudioFiles() =>
      throw UnimplementedError();

  @override
  Future<Result<MediaInfo>> inspect(String path) => throw UnimplementedError();
}

class _UnusedConversionRepository implements ConversionRepository {
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

class _EmptyLibraryRepository implements MediaLibraryRepository {
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

void main() {
  tearDown(Get.reset);

  testWidgets('a file being brought in shows upload progress, then it clears', (
    WidgetTester tester,
  ) async {
    final _SlowMediaRepository media = _SlowMediaRepository();
    final ConverterController controller = ConverterController(
      ToolMode.cut,
      PickVideo(media),
      PickAudio(media),
      PickAudioFiles(media),
      ConvertMedia(_UnusedConversionRepository()),
      CancelConversion(_UnusedConversionRepository()),
      AddMediaFile(_EmptyLibraryRepository()),
      OutputDirectoryService(),
      GetMediaFiles(_EmptyLibraryRepository()),
      InspectMedia(media),
    );
    Get.put<ConverterController>(controller);

    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.dark, home: const ConverterPage()),
    );
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);

    unawaited(controller.pickSource());
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Uploading file…'), findsOneWidget);

    media.gate.complete(const Result<MediaInfo?>.success(null));
    await tester.pump();
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
