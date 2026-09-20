import 'dart:io';

import '../../../../core/errors/failure.dart';
import '../../../../core/services/ffmpeg_service.dart';
import '../../../../core/types/result.dart';
import '../../../../core/utils/file_utils.dart';
import '../../domain/entities/media_info.dart';
import '../../domain/repositories/media_repository.dart';
import '../datasources/media_picker_datasource.dart';
import '../../../../core/i18n/translation_keys.dart';

class MediaRepositoryImpl implements MediaRepository {
  const MediaRepositoryImpl(this._picker, this._ffmpeg);

  /// Refuse anything past this; FFmpeg would work but the wait is unreasonable
  /// and the device is likely to run out of space for the output.
  static const int maxInputSizeInBytes = 4 * 1024 * 1024 * 1024;

  final MediaPickerDataSource _picker;
  final FfmpegService _ffmpeg;

  @override
  Future<Result<MediaInfo?>> pickVideo() =>
      _pickAndValidate(_picker.pickVideo, requireVideo: true);

  @override
  Future<Result<MediaInfo?>> pickAudio() =>
      _pickAndValidate(_picker.pickAudio, requireVideo: false);

  @override
  Future<Result<List<MediaInfo>>> pickAudioFiles() async {
    try {
      final List<PickedMedia> picked = await _picker.pickAudioFiles();
      final List<MediaInfo> valid = <MediaInfo>[];

      for (final PickedMedia media in picked) {
        final Result<MediaInfo?> result = await _validate(
          media,
          requireVideo: false,
        );
        // One unreadable file must not discard the user's whole selection.
        if (result.valueOrNull case final MediaInfo info) {
          valid.add(info);
        }
      }

      if (picked.isNotEmpty && valid.isEmpty) {
        return const Result<List<MediaInfo>>.failure(
          FileFailure(
            messageKey: K.errorNoFilesReadable,
          ),
        );
      }

      return Result<List<MediaInfo>>.success(valid);
    } catch (error) {
      return Result<List<MediaInfo>>.failure(
        FileFailure(debugMessage: error.toString()),
      );
    }
  }

  @override
  Future<Result<MediaInfo>> inspect(String path) async {
    try {
      final File file = File(path);
      if (!file.existsSync()) {
        return const Result<MediaInfo>.failure(
          FileFailure(
            messageKey: K.errorFileGone,
          ),
        );
      }

      final MediaProbeResult? probe = await _ffmpeg.probe(path);
      if (probe == null) {
        return const Result<MediaInfo>.failure(
          FileFailure(messageKey: K.errorFileUnreadable),
        );
      }

      if (!probe.hasAudio) {
        return const Result<MediaInfo>.failure(
          FileFailure(messageKey: K.errorNoAudioInFile),
        );
      }

      return Result<MediaInfo>.success(
        MediaInfo(
          path: path,
          name: FileUtils.basename(path),
          sizeInBytes: await file.length(),
          extension: FileUtils.extensionOf(path),
          hasAudio: probe.hasAudio,
          hasVideo: probe.hasVideo,
          duration: probe.duration,
          audioCodec: probe.audioCodec,
          channels: probe.channels,
          // A library file is a real file, so it plays directly.
          playbackUri: path,
        ),
      );
    } catch (error) {
      return Result<MediaInfo>.failure(
        FileFailure(debugMessage: error.toString()),
      );
    }
  }

  Future<Result<MediaInfo?>> _pickAndValidate(
    Future<PickedMedia?> Function() pick, {
    required bool requireVideo,
  }) async {
    try {
      final PickedMedia? picked = await pick();
      // Cancelling the picker is a normal outcome, not a failure.
      if (picked == null) {
        return const Result<MediaInfo?>.success(null);
      }
      // Awaited rather than returned directly: the catch below only reaches
      // a failure that happens before control leaves this block, and
      // validating the pick can still throw.
      return await _validate(picked, requireVideo: requireVideo);
    } catch (error) {
      return Result<MediaInfo?>.failure(
        FileFailure(debugMessage: error.toString()),
      );
    }
  }

  /// Applies the checks the spec requires before a file is accepted: readable,
  /// actually media, has an audio track, and a workable size.
  Future<Result<MediaInfo?>> _validate(
    PickedMedia picked, {
    required bool requireVideo,
  }) async {
    if (picked.sizeInBytes <= 0) {
      return const Result<MediaInfo?>.failure(
        FileFailure(messageKey: K.errorFileEmpty),
      );
    }

    if (picked.sizeInBytes > maxInputSizeInBytes) {
      return const Result<MediaInfo?>.failure(
        FileFailure(
          messageKey: K.errorFileTooLarge,
        ),
      );
    }

    final String? readablePath = await _ffmpeg.resolveReadablePath(picked.uri);
    if (readablePath == null) {
      return const Result<MediaInfo?>.failure(
        FileFailure(messageKey: K.errorFileNotOpened),
      );
    }

    final MediaProbeResult? probe = await _ffmpeg.probe(readablePath);
    if (probe == null) {
      return const Result<MediaInfo?>.failure(
        FileFailure(messageKey: K.errorNotMedia),
      );
    }

    if (!probe.hasAudio) {
      return Result<MediaInfo?>.failure(
        FileFailure(
          messageKey: requireVideo
              ? K.errorNoAudioTrack
              : K.errorNoAudioInFile,
        ),
      );
    }

    if (requireVideo && !probe.hasVideo) {
      return const Result<MediaInfo?>.failure(
        FileFailure(messageKey: K.errorNotVideo),
      );
    }

    return Result<MediaInfo?>.success(
      MediaInfo(
        path: readablePath,
        name: picked.name,
        sizeInBytes: picked.sizeInBytes,
        extension: FileUtils.extensionOf(picked.name),
        hasAudio: probe.hasAudio,
        hasVideo: probe.hasVideo,
        duration: probe.duration,
        audioCodec: probe.audioCodec,
        channels: probe.channels,
        playbackUri: picked.uri.toString(),
      ),
    );
  }
}
