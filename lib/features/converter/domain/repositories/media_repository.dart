import '../../../../core/types/result.dart';
import '../entities/media_info.dart';

/// Selecting and inspecting source media.
abstract interface class MediaRepository {
  /// Opens the system picker for a video and validates the choice.
  ///
  /// Returns a success with `null` when the user cancels, which is not an
  /// error and must not surface a message.
  Future<Result<MediaInfo?>> pickVideo();

  /// Opens the system picker for a single audio file.
  Future<Result<MediaInfo?>> pickAudio();

  /// Opens the system picker for several audio files, e.g. for merging.
  Future<Result<List<MediaInfo>>> pickAudioFiles();

  /// Reads metadata for a file already on disk.
  Future<Result<MediaInfo>> inspect(String path);
}
