import 'package:get/get.dart';

import '../../../../core/enums/tool_mode.dart';
import '../../../../core/services/ffmpeg_service.dart';
import '../../../../core/services/output_directory_service.dart';
import '../../../files/domain/repositories/media_library_repository.dart';
import '../../../files/domain/usecases/media_library_usecases.dart';
import '../../data/datasources/media_picker_datasource.dart';
import '../../data/repositories/conversion_repository_impl.dart';
import '../../data/repositories/media_repository_impl.dart';
import '../../domain/repositories/conversion_repository.dart';
import '../../domain/repositories/media_repository.dart';
import '../../domain/usecases/convert_media.dart';
import '../../domain/usecases/pick_media.dart';
import '../controllers/converter_controller.dart';
import '../controllers/mix_preview_controller.dart';
import '../controllers/timeline_preview_controller.dart';
import '../controllers/trim_preview_controller.dart';

class ConverterBinding extends Bindings {
  @override
  void dependencies() {
    final ToolMode mode = Get.arguments is ToolMode
        ? Get.arguments as ToolMode
        : ToolMode.audioConvert;

    final MediaRepository mediaRepository = MediaRepositoryImpl(
      const MediaPickerDataSourceImpl(),
      Get.find<FfmpegService>(),
    );
    final ConversionRepository conversionRepository = ConversionRepositoryImpl(
      Get.find<FfmpegService>(),
      Get.find<OutputDirectoryService>(),
    );

    // The cutter previews its selection; the timeline previews the selection
    // on each of its clips. Same player, same job.
    if ((mode.supportsTrim || mode.isTimeline) &&
        !Get.isRegistered<TrimPreviewController>()) {
      Get.lazyPut<TrimPreviewController>(TrimPreviewController.new);
    }

    // The two previews work differently: the mixer sounds its clips together,
    // the timeline runs them straight through as one playlist.
    if (mode.isMix && !Get.isRegistered<MixPreviewController>()) {
      Get.lazyPut<MixPreviewController>(MixPreviewController.new);
    }

    if (mode.isTimeline && !Get.isRegistered<TimelinePreviewController>()) {
      Get.lazyPut<TimelinePreviewController>(TimelinePreviewController.new);
    }

    Get.lazyPut<ConverterController>(
      () => ConverterController(
        mode,
        PickVideo(mediaRepository),
        PickAudio(mediaRepository),
        PickAudioFiles(mediaRepository),
        ConvertMedia(conversionRepository),
        CancelConversion(conversionRepository),
        AddMediaFile(Get.find<MediaLibraryRepository>()),
        Get.find<OutputDirectoryService>(),
        GetMediaFiles(Get.find<MediaLibraryRepository>()),
        InspectMedia(mediaRepository),
      ),
    );
  }
}
