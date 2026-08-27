import 'dart:io';

import '../../../../core/errors/failure.dart';
import '../../../../core/services/ffmpeg_service.dart';
import '../../../../core/services/output_directory_service.dart';
import '../../../../core/types/result.dart';
import '../../../../core/utils/file_utils.dart';
import '../../domain/entities/conversion_request.dart';
import '../../domain/entities/conversion_result.dart';
import '../../domain/repositories/conversion_repository.dart';
import '../ffmpeg_command_builder.dart';

class ConversionRepositoryImpl implements ConversionRepository {
  const ConversionRepositoryImpl(this._ffmpeg, this._directories);

  final FfmpegService _ffmpeg;
  final OutputDirectoryService _directories;

  @override
  Future<Result<ConversionResult>> convert(
    ConversionRequest request, {
    void Function(double progress)? onProgress,
  }) async {
    if (!request.isValid) {
      return const Result<ConversionResult>.failure(
        FileFailure(message: 'That conversion could not be started.'),
      );
    }

    try {
      if (!await _directories.canWrite()) {
        return const Result<ConversionResult>.failure(
          StorageFailure(
            message:
                'There is not enough free space to save the converted file.',
          ),
        );
      }

      final FfmpegRunResult run = await _ffmpeg.run(
        arguments: FfmpegCommandBuilder.build(request),
        totalDuration: request.expectedDuration,
        onProgress: onProgress,
      );

      switch (run.outcome) {
        case FfmpegOutcome.cancelled:
          await _deletePartialOutput(request.outputPath);
          return const Result<ConversionResult>.failure(ConversionCancelled());

        case FfmpegOutcome.failure:
          await _deletePartialOutput(request.outputPath);
          // The raw FFmpeg log is kept for diagnostics only.
          return Result<ConversionResult>.failure(
            ConversionFailure(debugMessage: run.logs),
          );

        case FfmpegOutcome.success:
          return _buildResult(request);
      }
    } catch (error) {
      await _deletePartialOutput(request.outputPath);
      return Result<ConversionResult>.failure(
        ConversionFailure(debugMessage: error.toString()),
      );
    }
  }

  @override
  Future<void> cancel() => _ffmpeg.cancel();

  @override
  Future<Result<String>> resolveOutputDirectory() async {
    try {
      final Directory directory = await _directories.resolve();
      return Result<String>.success(directory.path);
    } catch (error) {
      return Result<String>.failure(
        StorageFailure(debugMessage: error.toString()),
      );
    }
  }

  Future<Result<ConversionResult>> _buildResult(
    ConversionRequest request,
  ) async {
    final File output = File(request.outputPath);

    // FFmpeg can report success while producing nothing usable, e.g. when the
    // trim range selected an empty span.
    if (!output.existsSync()) {
      return const Result<ConversionResult>.failure(
        ConversionFailure(message: 'The converted file could not be created.'),
      );
    }

    final int size = await output.length();
    if (size <= 0) {
      await _deletePartialOutput(request.outputPath);
      return const Result<ConversionResult>.failure(
        ConversionFailure(
          message: 'The converted file was empty. Please try again.',
        ),
      );
    }

    // Read the real duration back rather than trusting the requested range.
    final MediaProbeResult? probe = await _ffmpeg.probe(request.outputPath);

    return Result<ConversionResult>.success(
      ConversionResult(
        outputPath: request.outputPath,
        name: FileUtils.basename(request.outputPath),
        sizeInBytes: size,
        format: request.format.label,
        duration: probe?.duration ?? request.expectedDuration,
      ),
    );
  }

  /// Removes the half-written file a cancelled or failed run leaves behind.
  Future<void> _deletePartialOutput(String path) async {
    try {
      final File file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    } on FileSystemException {
      // Nothing more can be done; the temp sweeper will catch it later.
    }
  }
}
