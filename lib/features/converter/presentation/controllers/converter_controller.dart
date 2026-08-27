import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/enums/audio_format.dart';
import '../../../../core/enums/audio_quality.dart';
import '../../../../core/enums/compression_level.dart';
import '../../../../core/enums/export_speed.dart';
import '../../../../core/enums/tool_mode.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/output_directory_service.dart';
import '../../../../core/types/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../files/domain/entities/media_file.dart';
import '../../../files/domain/usecases/media_library_usecases.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
import '../../domain/entities/conversion_request.dart';
import '../../domain/entities/conversion_result.dart';
import '../../domain/entities/media_info.dart';
import '../../domain/usecases/convert_media.dart';
import '../../domain/usecases/pick_media.dart';
import 'trim_preview_controller.dart';

/// Where the user is in the conversion flow.
enum ConverterStage { configuring, converting, completed, failed }

/// Drives every conversion tool.
///
/// The tool only changes what is configured, so one controller serves all of
/// them and there is a single implementation of the conversion flow.
class ConverterController extends GetxController {
  ConverterController(
    this._mode,
    this._pickVideo,
    this._pickAudio,
    this._pickAudioFiles,
    this._convertMedia,
    this._cancelConversion,
    this._addMediaFile,
    this._outputDirectories,
    this._getMediaFiles,
    this._inspectMedia,
  );

  final ToolMode _mode;
  final PickVideo _pickVideo;
  final PickAudio _pickAudio;
  final PickAudioFiles _pickAudioFiles;
  final ConvertMedia _convertMedia;
  final CancelConversion _cancelConversion;
  final AddMediaFile _addMediaFile;
  final OutputDirectoryService _outputDirectories;
  final GetMediaFiles _getMediaFiles;
  final InspectMedia _inspectMedia;

  ToolMode get mode => _mode;

  final RxList<MediaInfo> sources = <MediaInfo>[].obs;
  final Rx<AudioFormat> format = AudioFormat.mp3.obs;
  final Rx<AudioQuality> quality = AudioQuality.kbps192.obs;
  final Rx<CompressionLevel> compressionLevel = CompressionLevel.medium.obs;
  final RxString fileName = ''.obs;

  final Rx<Duration> trimStart = Duration.zero.obs;
  final Rx<Duration> trimEnd = Duration.zero.obs;

  /// Tempo the export is rendered at.
  final Rx<ExportSpeed> speed = ExportSpeed.normal.obs;

  /// Files already converted in this app, offered as an input source.
  final RxList<MediaFile> libraryFiles = <MediaFile>[].obs;
  final RxBool isLoadingLibrary = false.obs;
  final RxString libraryErrorMessage = ''.obs;

  final Rx<ConverterStage> stage = ConverterStage.configuring.obs;
  final RxDouble progress = 0.0.obs;
  final RxBool isPicking = false.obs;
  final RxString errorMessage = ''.obs;
  final Rxn<ConversionResult> result = Rxn<ConversionResult>();

  /// True once there is enough input to start.
  bool get canConvert =>
      sources.isNotEmpty &&
      fileName.value.trim().isNotEmpty &&
      stage.value != ConverterStage.converting;

  MediaInfo? get primarySource => sources.isEmpty ? null : sources.first;

  /// Length the output is expected to have, used for progress and estimates.
  Duration? get sourceDuration {
    if (_mode.picksMultiple) {
      // A merge has no single length; sum what is known.
      final Iterable<Duration> known = sources
          .map((MediaInfo info) => info.duration)
          .whereType<Duration>();
      return known.isEmpty
          ? null
          : known.reduce((Duration a, Duration b) => a + b);
    }
    return primarySource?.duration;
  }

  /// Bitrate actually applied, which compression drives from its preset.
  AudioQuality get effectiveQuality =>
      _mode.isCompression ? compressionLevel.value.quality : quality.value;

  @override
  void onInit() {
    super.onInit();
    _applyDefaultsFromSettings();
  }

  void _applyDefaultsFromSettings() {
    if (!Get.isRegistered<SettingsController>()) {
      return;
    }
    final SettingsController settings = Get.find<SettingsController>();
    final AudioFormat preferred = settings.settings.value.defaultOutputFormat;

    if (_mode.availableFormats.contains(preferred)) {
      format.value = preferred;
    }
    quality.value = settings.settings.value.defaultAudioQuality;
  }

  /// Opens the picker for this tool and validates the selection.
  Future<void> pickSource() async {
    if (isPicking.value) {
      return;
    }
    isPicking.value = true;
    errorMessage.value = '';

    final Result<Object?> picked = switch (_mode) {
      ToolMode.videoToAudio => await _pickVideo(const NoParams()),
      ToolMode.merge => await _pickAudioFiles(const NoParams()),
      _ => await _pickAudio(const NoParams()),
    };

    isPicking.value = false;

    picked.fold(
      (Failure failure) => errorMessage.value = failure.message,
      _applyPicked,
    );
  }

  void _applyPicked(Object? value) {
    _stopPreviewIfPresent();

    if (value is List<MediaInfo>) {
      if (value.isEmpty) {
        return;
      }
      sources.addAll(value);
    } else if (value is MediaInfo) {
      sources
        ..clear()
        ..add(value);
    } else {
      // Null means the picker was dismissed, which needs no feedback.
      return;
    }

    _resetOutputForSelection();
  }

  void _resetOutputForSelection() {
    final MediaInfo? first = primarySource;
    if (first == null) {
      return;
    }

    fileName.value = _mode.picksMultiple
        ? 'merged_audio'
        : '${first.baseName}${_mode.outputSuffix}';

    trimStart.value = Duration.zero;
    trimEnd.value = first.duration ?? Duration.zero;
    errorMessage.value = '';
  }

  void removeSourceAt(int index) {
    if (index < 0 || index >= sources.length) {
      return;
    }
    _stopPreviewIfPresent();
    sources.removeAt(index);
    if (sources.isEmpty) {
      fileName.value = '';
    }
  }

  /// Reorders the merge list; the output follows this order.
  ///
  /// Written for `onReorderItem`, which already adjusts [newIndex] for the
  /// removed item, so no further shifting is needed here.
  void reorderSources(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= sources.length) {
      return;
    }
    final MediaInfo moved = sources.removeAt(oldIndex);
    sources.insert(newIndex.clamp(0, sources.length), moved);
  }

  void setFormat(AudioFormat value) => format.value = value;

  void setSpeed(ExportSpeed value) {
    speed.value = value;
    _stopPreviewIfPresent();
  }

  /// Loads the app's own converted files so they can be used as input.
  Future<void> loadLibraryFiles() async {
    isLoadingLibrary.value = true;
    libraryErrorMessage.value = '';
    final Result<List<MediaFile>> result = await _getMediaFiles(
      const NoParams(),
    );
    result.fold(
      (Failure failure) => libraryErrorMessage.value = failure.message,
      (List<MediaFile> files) {
        libraryFiles.assignAll(
          // Only audio can be fed to these tools.
          files.where((MediaFile file) => file.type == MediaFileType.audio),
        );
        libraryErrorMessage.value = '';
      },
    );
    isLoadingLibrary.value = false;
  }

  /// Adds a file from the app's library as an input.
  Future<void> pickFromLibrary(MediaFile file) async {
    if (isPicking.value) {
      return;
    }
    isPicking.value = true;
    errorMessage.value = '';

    final Result<MediaInfo> result = await _inspectMedia(file.path);

    isPicking.value = false;

    result.fold((Failure failure) => errorMessage.value = failure.message, (
      MediaInfo info,
    ) {
      _stopPreviewIfPresent();
      if (_mode.picksMultiple) {
        sources.add(info);
      } else {
        sources
          ..clear()
          ..add(info);
      }
      _resetOutputForSelection();
    });
  }

  void setQuality(AudioQuality value) => quality.value = value;

  void setCompressionLevel(CompressionLevel value) =>
      compressionLevel.value = value;

  void setFileName(String value) => fileName.value = value;

  void setTrimRange(Duration start, Duration end) {
    trimStart.value = start;
    trimEnd.value = end;
    _stopPreviewIfPresent();
  }

  void _stopPreviewIfPresent() {
    if (!Get.isRegistered<TrimPreviewController>()) {
      return;
    }
    final TrimPreviewController preview = Get.find<TrimPreviewController>();
    preview.errorMessage.value = '';
    unawaited(preview.stop());
  }

  /// Builds the request and runs it, then records the output in the library.
  Future<void> convert() async {
    if (!canConvert) {
      return;
    }

    final String? safeName = FileUtils.sanitizeFileName(fileName.value);
    if (safeName == null) {
      errorMessage.value = 'Please enter a valid file name.';
      return;
    }

    if (_mode.supportsTrim && trimEnd.value <= trimStart.value) {
      errorMessage.value = 'Please select a section longer than zero seconds.';
      return;
    }

    stage.value = ConverterStage.converting;
    progress.value = 0;
    errorMessage.value = '';

    final String outputDirectory = (await _outputDirectories.resolve()).path;

    final ConversionRequest request = ConversionRequest(
      inputPaths: sources.map((MediaInfo info) => info.path).toList(),
      outputPath: FileUtils.uniquePath(
        directory: outputDirectory,
        baseName: safeName,
        extension: format.value.extension,
      ),
      format: format.value,
      quality: effectiveQuality,
      trimStart: _mode.supportsTrim ? trimStart.value : null,
      trimEnd: _mode.supportsTrim ? trimEnd.value : null,
      totalDuration: sourceDuration,
      speed: speed.value,
    );

    final Result<ConversionResult> outcome = await _convertMedia(
      request,
      onProgress: (double value) => progress.value = value,
    );

    await outcome.fold(_onConversionFailed, _onConversionSucceeded);
  }

  Future<void> _onConversionFailed(Failure failure) async {
    errorMessage.value = failure.message;
    stage.value = failure is ConversionCancelled
        ? ConverterStage.configuring
        : ConverterStage.failed;
    progress.value = 0;
  }

  Future<void> _onConversionSucceeded(ConversionResult conversion) async {
    result.value = conversion;
    progress.value = 1;
    stage.value = ConverterStage.completed;

    await _addMediaFile(
      MediaFile(
        id: null,
        name: conversion.name,
        originalName: primarySource?.name ?? conversion.name,
        path: conversion.outputPath,
        type: MediaFileType.audio,
        format: conversion.format,
        sizeInBytes: conversion.sizeInBytes,
        createdAt: DateTime.now(),
        sourceType: _sourceTypeForMode,
        duration: conversion.duration,
      ),
    );

    await Get.toNamed<void>(AppRoutes.conversionResult, arguments: conversion);
  }

  MediaSourceType get _sourceTypeForMode => switch (_mode) {
    ToolMode.videoToAudio => MediaSourceType.videoToAudio,
    ToolMode.audioConvert => MediaSourceType.audioConvert,
    ToolMode.cut => MediaSourceType.cut,
    ToolMode.merge => MediaSourceType.merge,
    ToolMode.compress => MediaSourceType.compress,
  };

  /// Stops a running conversion. The partial output is removed by the
  /// repository, so nothing unusable is left behind.
  Future<void> cancel() async {
    if (stage.value != ConverterStage.converting) {
      return;
    }
    await _cancelConversion(const NoParams());
  }

  /// Returns to the configuration step after a failure.
  void retry() {
    stage.value = ConverterStage.configuring;
    progress.value = 0;
    errorMessage.value = '';
  }
}
