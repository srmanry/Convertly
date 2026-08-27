import 'dart:async';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/media_information.dart';
import 'package:ffmpeg_kit_flutter_new/media_information_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:ffmpeg_kit_flutter_new/stream_information.dart';

/// How an FFmpeg execution ended.
enum FfmpegOutcome { success, cancelled, failure }

/// Result of one FFmpeg execution.
///
/// [logs] is technical output for diagnostics only and must never be shown to
/// a user.
class FfmpegRunResult {
  const FfmpegRunResult({required this.outcome, this.logs});

  final FfmpegOutcome outcome;
  final String? logs;

  bool get isSuccess => outcome == FfmpegOutcome.success;
}

/// What FFprobe could determine about a media file.
class MediaProbeResult {
  const MediaProbeResult({
    required this.duration,
    required this.formatName,
    required this.hasAudio,
    required this.hasVideo,
    this.audioCodec,
  });

  final Duration? duration;
  final String? formatName;
  final bool hasAudio;
  final bool hasVideo;
  final String? audioCodec;
}

/// The only place in the app that talks to FFmpeg.
///
/// Everything above this class deals in plain Dart types, so the media backend
/// can be replaced without touching any feature code.
class FfmpegService {
  /// Session currently running, used to support cancellation.
  int? _activeSessionId;

  bool get isRunning => _activeSessionId != null;

  /// Turns a picked document URI into something FFmpeg can read.
  ///
  /// Android's picker returns `content://` URIs, which have no filesystem
  /// path. FFmpeg resolves them through SAF, so a large file is read in place
  /// instead of being copied into the cache first.
  Future<String?> resolveReadablePath(Uri uri) async {
    if (uri.scheme == 'file') {
      return uri.toFilePath();
    }
    if (uri.scheme == 'content') {
      return FFmpegKitConfig.getSafParameterForRead(uri.toString());
    }
    return null;
  }

  /// Reads metadata for [path].
  ///
  /// Returns `null` when the file cannot be read or is not media FFmpeg
  /// understands, which callers translate into a user-facing message.
  Future<MediaProbeResult?> probe(String path) async {
    final MediaInformationSession session =
        await FFprobeKit.getMediaInformation(path);
    final MediaInformation? information = session.getMediaInformation();

    if (information == null) {
      return null;
    }

    final List<StreamInformation> streams = information.getStreams();
    final bool hasAudio = streams.any(
      (StreamInformation stream) => stream.getType() == 'audio',
    );
    final bool hasVideo = streams.any(
      (StreamInformation stream) => stream.getType() == 'video',
    );

    return MediaProbeResult(
      duration: _parseDuration(information.getDuration()),
      formatName: information.getFormat(),
      hasAudio: hasAudio,
      hasVideo: hasVideo,
      audioCodec: streams
          .where((StreamInformation stream) => stream.getType() == 'audio')
          .map((StreamInformation stream) => stream.getCodec())
          .firstOrNull,
    );
  }

  /// Runs FFmpeg with [arguments].
  ///
  /// [totalDuration] is what progress is measured against; without it FFmpeg
  /// reports elapsed media time but no meaningful percentage, so [onProgress]
  /// is simply never called.
  Future<FfmpegRunResult> run({
    required List<String> arguments,
    Duration? totalDuration,
    void Function(double progress)? onProgress,
  }) async {
    final FfmpegRunResult result = await _execute(
      arguments: arguments,
      totalDuration: totalDuration,
      onProgress: onProgress,
    );
    _activeSessionId = null;
    return result;
  }

  /// Stops the running session, if any.
  ///
  /// The pending [run] completes with [FfmpegOutcome.cancelled] rather than
  /// throwing.
  Future<void> cancel() async {
    final int? sessionId = _activeSessionId;
    if (sessionId == null) {
      return;
    }
    await FFmpegKit.cancel(sessionId);
  }

  Future<FfmpegRunResult> _execute({
    required List<String> arguments,
    required Duration? totalDuration,
    required void Function(double progress)? onProgress,
  }) async {
    // executeWithArgumentsAsync returns as soon as the session *starts*, and
    // getReturnCode() is null until it ends. The completion callback is the
    // only reliable signal that the run has finished.
    final Completer<FFmpegSession> completion = Completer<FFmpegSession>();

    final FFmpegSession session = await FFmpegKit.executeWithArgumentsAsync(
      arguments,
      (FFmpegSession completed) {
        if (!completion.isCompleted) {
          completion.complete(completed);
        }
      },
      null,
      (Statistics statistics) {
        if (onProgress == null || totalDuration == null) {
          return;
        }
        final int totalMs = totalDuration.inMilliseconds;
        if (totalMs <= 0) {
          return;
        }
        // getTime() is the position reached in the *media*, in milliseconds.
        final double progress = statistics.getTime() / totalMs;
        onProgress(progress.clamp(0.0, 1.0));
      },
    );

    _activeSessionId = session.getSessionId();

    final FFmpegSession finished = await completion.future;
    final ReturnCode? returnCode = await finished.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      onProgress?.call(1);
      return const FfmpegRunResult(outcome: FfmpegOutcome.success);
    }

    if (ReturnCode.isCancel(returnCode)) {
      return const FfmpegRunResult(outcome: FfmpegOutcome.cancelled);
    }

    // A null return code here means the session ended in the FAILED state,
    // where the stack trace carries the reason instead.
    final String? logs = await finished.getAllLogsAsString();
    final String? stackTrace = await finished.getFailStackTrace();

    return FfmpegRunResult(
      outcome: FfmpegOutcome.failure,
      logs: <String?>[logs, stackTrace].nonNulls.join('\n'),
    );
  }

  /// FFprobe reports duration as a string of seconds, e.g. `"213.482000"`.
  static Duration? _parseDuration(String? seconds) {
    if (seconds == null) {
      return null;
    }
    final double? value = double.tryParse(seconds);
    if (value == null || value <= 0) {
      return null;
    }
    return Duration(milliseconds: (value * 1000).round());
  }
}
