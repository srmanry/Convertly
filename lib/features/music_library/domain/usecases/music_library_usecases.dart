import '../../../../core/types/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/song.dart';
import '../repositories/music_library_repository.dart';

class GetDeviceSongs implements UseCase<List<Song>, NoParams> {
  const GetDeviceSongs(this._repository);

  final MusicLibraryRepository _repository;

  @override
  Future<Result<List<Song>>> call(NoParams params) => _repository.deviceSongs();
}

class GetAppSongs implements UseCase<List<Song>, NoParams> {
  const GetAppSongs(this._repository);

  final MusicLibraryRepository _repository;

  @override
  Future<Result<List<Song>>> call(NoParams params) => _repository.appSongs();
}

/// Checking and asking are one step here: a caller only ever wants to know
/// whether it may read the device's music now.
class EnsureDevicePermission implements UseCase<bool, NoParams> {
  const EnsureDevicePermission(this._repository);

  final MusicLibraryRepository _repository;

  @override
  Future<Result<bool>> call(NoParams params) async {
    if (await _repository.hasDevicePermission()) {
      return const Result<bool>.success(true);
    }
    return Result<bool>.success(await _repository.requestDevicePermission());
  }
}
