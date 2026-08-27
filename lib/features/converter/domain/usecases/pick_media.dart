import '../../../../core/types/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/media_info.dart';
import '../repositories/media_repository.dart';

/// Picks a video to extract audio from.
class PickVideo implements UseCase<MediaInfo?, NoParams> {
  const PickVideo(this._repository);

  final MediaRepository _repository;

  @override
  Future<Result<MediaInfo?>> call(NoParams params) => _repository.pickVideo();
}

/// Picks a single audio file, used by the converter, cutter and compressor.
class PickAudio implements UseCase<MediaInfo?, NoParams> {
  const PickAudio(this._repository);

  final MediaRepository _repository;

  @override
  Future<Result<MediaInfo?>> call(NoParams params) => _repository.pickAudio();
}

/// Picks several audio files for merging.
class PickAudioFiles implements UseCase<List<MediaInfo>, NoParams> {
  const PickAudioFiles(this._repository);

  final MediaRepository _repository;

  @override
  Future<Result<List<MediaInfo>>> call(NoParams params) =>
      _repository.pickAudioFiles();
}

/// Loads a file that is already in the app's library.
class InspectMedia implements UseCase<MediaInfo, String> {
  const InspectMedia(this._repository);

  final MediaRepository _repository;

  @override
  Future<Result<MediaInfo>> call(String params) => _repository.inspect(params);
}
