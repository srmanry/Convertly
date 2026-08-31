import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/enums/audio_format.dart';
import '../../../../core/enums/audio_quality.dart';
import '../../../../core/enums/cleanup_mode.dart';
import '../../../../core/enums/compression_level.dart';
import '../../../../core/enums/export_speed.dart';
import '../../../../core/enums/mix_length_mode.dart';
import '../../../../core/enums/noise_strength.dart';
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
import '../../domain/entities/cleanup_settings.dart';
import '../../domain/entities/conversion_request.dart';
import '../../domain/entities/conversion_result.dart';
import '../../domain/entities/media_info.dart';
import '../../domain/entities/mix_settings.dart';
import '../../domain/entities/mix_track.dart';
import '../../domain/usecases/convert_media.dart';
import '../../domain/usecases/pick_media.dart';
import 'mix_preview_controller.dart';
import 'timeline_preview_controller.dart';
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

  /// Per-clip level, position and trim, held in step with [sources] so index
  /// `n` in one always describes the same clip as index `n` in the other.
  final RxList<MixTrack> clips = <MixTrack>[].obs;

  final Rx<MixLengthMode> mixLength = MixLengthMode.longestTrack.obs;
  final RxBool loopShorterTracks = false.obs;

  final Rx<CleanupMode> cleanupMode = CleanupMode.backgroundNoise.obs;
  final Rx<NoiseStrength> noiseStrength = NoiseStrength.medium.obs;

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
      (!_mode.needsTwoSources || sources.length >= 2) &&
      !isCleanupUnsupported &&
      fileName.value.trim().isNotEmpty &&
      stage.value != ConverterStage.converting;

  MediaInfo? get primarySource => sources.isEmpty ? null : sources.first;

  /// Length the output is expected to have, used for progress and estimates.
  Duration? get sourceDuration {
    final Iterable<Duration> known = <Duration?>[
      for (int index = 0; index < sources.length; index++) usedLengthOf(index),
    ].whereType<Duration>();

    if (_mode.combinesTracks) {
      // A track ends at its own start plus its length, so the arrangement is
      // as long as whichever track the length mode says it ends with.
      if (_effectiveMixLength == MixLengthMode.mainTrack) {
        return _trackEnd(0);
      }
      final List<Duration> ends = <Duration>[
        for (int index = 0; index < sources.length; index++)
          if (_trackEnd(index) case final Duration end) end,
      ];
      return ends.isEmpty
          ? null
          : ends.reduce((Duration a, Duration b) => a > b ? a : b);
    }

    if (_mode.picksMultiple) {
      // A merge has no single length; sum what is known.
      return known.isEmpty
          ? null
          : known.reduce((Duration a, Duration b) => a + b);
    }
    return primarySource?.duration;
  }

  /// Point on the timeline where the track at [index] finishes.
  ///
  /// Null when the track's own length could not be read, which keeps an
  /// unknown out of the total rather than counting it as zero.
  Duration? _trackEnd(int index) {
    if (index < 0 || index >= sources.length) {
      return null;
    }
    final Duration? length = usedLengthOf(index);
    return length == null ? null : startOfTrack(index) + length;
  }

  MixTrack clipAt(int index) =>
      index >= 0 && index < clips.length ? clips[index] : const MixTrack();

  Duration startOfTrack(int index) => clipAt(index).start;

  /// How much of the clip at [index] is actually used.
  ///
  /// A clip the user has trimmed contributes only the selected span; an
  /// untrimmed one contributes its whole length.
  Duration? usedLengthOf(int index) {
    if (index < 0 || index >= sources.length) {
      return null;
    }
    return clipAt(index).usedLength ?? sources[index].duration;
  }

  /// Length mode actually applied, which looping forces to the main track.
  MixLengthMode get _effectiveMixLength =>
      loopShorterTracks.value ? MixLengthMode.mainTrack : mixLength.value;

  /// True when the selected cleanup cannot work on the chosen file.
  ///
  /// Cancelling the centre of a mono track subtracts it from itself, which
  /// leaves silence, so the export is blocked instead of producing that.
  bool get isCleanupUnsupported {
    if (!_mode.isCleanup || !cleanupMode.value.requiresStereo) {
      return false;
    }
    final int? channels = primarySource?.channels;
    return channels != null && channels < 2;
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
      ToolMode.merge ||
      ToolMode.mix ||
      ToolMode.arrange => await _pickAudioFiles(const NoParams()),
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
      _appendSources(value);
    } else if (value is MediaInfo) {
      _replaceSources(<MediaInfo>[value]);
    } else {
      // Null means the picker was dismissed, which needs no feedback.
      return;
    }

    _resetOutputForSelection();
  }

  /// Gain a newly added track starts at.
  ///
  /// The first track is the main one, so it comes in untouched; anything
  /// added after it starts lower, which is the level a background layer
  /// wants and an easy drag away from equal.
  static const double _mainTrackVolume = 1;
  static const double _layerTrackVolume = 0.6;

  void _appendSources(List<MediaInfo> added) {
    for (final MediaInfo info in added) {
      clips.add(
        MixTrack(
          // On the timeline nothing is stacked, so no clip needs to duck out
          // of another's way and every one comes in at full level.
          volume: _mode.isTimeline || sources.isEmpty
              ? _mainTrackVolume
              : _layerTrackVolume,
          // A clip starts out whole. Leaving trimEnd null rather than filling
          // in the source length keeps "untrimmed" distinguishable from a
          // selection that happens to cover everything.
        ),
      );
      sources.add(info);
    }
    _reflowTimeline();
  }

  /// Lays the clips out so each one begins exactly where the last ended.
  ///
  /// Positions are derived rather than chosen: a clip cannot be left stranded
  /// after a stretch of silence, and removing or reordering clips closes up
  /// behind them. Playback runs straight through, the way a single recording
  /// would.
  void _reflowTimeline() {
    if (!_mode.isTimeline) {
      return;
    }
    Duration cursor = Duration.zero;
    for (int index = 0; index < clips.length; index++) {
      clips[index] = clips[index].copyWith(start: cursor);
      // Only the selected part of a clip takes up room, so trimming one pulls
      // everything after it earlier. A clip whose length could not be read
      // adds nothing rather than pushing the rest to a guessed position.
      cursor += usedLengthOf(index) ?? Duration.zero;
    }
  }

  void _replaceSources(List<MediaInfo> next) {
    sources.clear();
    clips.clear();
    _appendSources(next);
  }

  void _resetOutputForSelection() {
    final MediaInfo? first = primarySource;
    if (first == null) {
      return;
    }

    fileName.value = switch (_mode) {
      ToolMode.merge => 'merged_audio',
      ToolMode.mix => 'mixed_audio',
      ToolMode.arrange => 'timeline_audio',
      _ => '${first.baseName}${_mode.outputSuffix}',
    };

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
    if (index < clips.length) {
      clips.removeAt(index);
    }
    _reflowTimeline();
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
    final int target = newIndex.clamp(0, sources.length);
    sources.insert(target, moved);

    // The volumes ride along, otherwise dragging a track would hand it the
    // level of whatever used to sit at its new position.
    if (oldIndex < clips.length) {
      final MixTrack moved = clips.removeAt(oldIndex);
      clips.insert(target.clamp(0, clips.length), moved);
    }
    // Dragging a clip changes what follows what, so the whole run is laid out
    // again rather than leaving a hole where the clip used to be.
    _reflowTimeline();
  }

  void setFormat(AudioFormat value) => format.value = value;

  void setTrackVolume(int index, double value) {
    if (index < 0 || index >= clips.length) {
      return;
    }
    clips[index] = clips[index].copyWith(volume: value);
    // A running preview follows the slider rather than waiting for a restart.
    if (Get.isRegistered<MixPreviewController>()) {
      unawaited(
        Get.find<MixPreviewController>().applyVolumes(<double>[
          for (final MixTrack clip in clips) clip.volume,
        ]),
      );
    }
  }

  /// Keeps only [start] to [end] of the clip at [index].
  ///
  /// The clips after it move up, so trimming never opens a gap.
  void setClipTrim(int index, Duration start, Duration end) {
    if (index < 0 || index >= clips.length) {
      return;
    }
    final Duration? sourceLength = sources[index].duration;
    final Duration safeStart = start.isNegative ? Duration.zero : start;
    final Duration safeEnd = sourceLength != null && end > sourceLength
        ? sourceLength
        : end;
    if (safeEnd <= safeStart) {
      return;
    }

    clips[index] = clips[index].copyWith(
      trimStart: safeStart,
      trimEnd: safeEnd,
    );
    _reflowTimeline();
    _stopPreviewIfPresent();
  }

  /// The selection shown on the clip at [index], defaulting to the whole file.
  (Duration start, Duration end) trimRangeOf(int index) {
    final MixTrack clip = clipAt(index);
    final Duration end =
        clip.trimEnd ??
        (index < sources.length ? sources[index].duration : null) ??
        Duration.zero;
    return (clip.trimStart, end);
  }

  void setMixLength(MixLengthMode value) {
    mixLength.value = value;
    _stopPreviewIfPresent();
  }

  void setLoopShorterTracks(bool value) {
    loopShorterTracks.value = value;
    _stopPreviewIfPresent();
  }

  void setCleanupMode(CleanupMode value) {
    cleanupMode.value = value;
    errorMessage.value = '';
  }

  void setNoiseStrength(NoiseStrength value) => noiseStrength.value = value;

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
        _appendSources(<MediaInfo>[info]);
      } else {
        _replaceSources(<MediaInfo>[info]);
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
    if (Get.isRegistered<TrimPreviewController>()) {
      final TrimPreviewController preview = Get.find<TrimPreviewController>();
      preview.errorMessage.value = '';
      unawaited(preview.stop());
    }
    if (Get.isRegistered<MixPreviewController>()) {
      final MixPreviewController preview = Get.find<MixPreviewController>();
      preview.errorMessage.value = '';
      unawaited(preview.stop());
    }
    if (Get.isRegistered<TimelinePreviewController>()) {
      final TimelinePreviewController preview =
          Get.find<TimelinePreviewController>();
      preview.errorMessage.value = '';
      unawaited(preview.stop());
    }
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

    if (_mode.needsTwoSources && sources.length < 2) {
      errorMessage.value = 'Add at least two tracks to mix them together.';
      return;
    }

    if (isCleanupUnsupported) {
      errorMessage.value =
          'This track is mono, so there is no separate centre channel to '
          'remove. Try another cleanup option.';
      return;
    }

    stage.value = ConverterStage.converting;
    progress.value = 0;
    errorMessage.value = '';

    // Anything thrown between here and the engine would otherwise escape as an
    // unhandled async error, leaving the progress screen spinning with no way
    // back. A failure has to reach the user instead.
    final String outputDirectory;
    try {
      outputDirectory = (await _outputDirectories.resolve()).path;
    } catch (error) {
      await _onConversionFailed(
        StorageFailure(
          message: 'Could not find a place to save the converted file.',
          debugMessage: error.toString(),
        ),
      );
      return;
    }

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
      mix: _mode.combinesTracks
          ? MixSettings(
              tracks: List<MixTrack>.of(clips),
              loopShorterTracks: loopShorterTracks.value,
              lengthMode: mixLength.value,
            )
          : null,
      cleanup: _mode.isCleanup
          ? CleanupSettings(
              mode: cleanupMode.value,
              strength: noiseStrength.value,
            )
          : null,
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
    ToolMode.mix => MediaSourceType.mix,
    ToolMode.arrange => MediaSourceType.arrange,
    ToolMode.cleanup => MediaSourceType.cleanup,
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
