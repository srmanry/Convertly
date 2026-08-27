import '../../../../core/types/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/media_file.dart';
import '../repositories/media_library_repository.dart';

class GetMediaFiles implements UseCase<List<MediaFile>, NoParams> {
  const GetMediaFiles(this._repository);

  final MediaLibraryRepository _repository;

  @override
  Future<Result<List<MediaFile>>> call(NoParams params) => _repository.getAll();
}

class AddMediaFile implements UseCase<MediaFile, MediaFile> {
  const AddMediaFile(this._repository);

  final MediaLibraryRepository _repository;

  @override
  Future<Result<MediaFile>> call(MediaFile params) => _repository.add(params);
}

/// Arguments for a rename.
class RenameMediaParams {
  const RenameMediaParams({required this.file, required this.newName});

  final MediaFile file;
  final String newName;
}

class RenameMediaFile implements UseCase<MediaFile, RenameMediaParams> {
  const RenameMediaFile(this._repository);

  final MediaLibraryRepository _repository;

  @override
  Future<Result<MediaFile>> call(RenameMediaParams params) =>
      _repository.rename(params.file, params.newName);
}

class DeleteMediaFile implements UseCase<void, MediaFile> {
  const DeleteMediaFile(this._repository);

  final MediaLibraryRepository _repository;

  @override
  Future<Result<void>> call(MediaFile params) => _repository.delete(params);
}

/// Deletes a whole selection in one action.
class DeleteMediaFiles implements UseCase<int, List<MediaFile>> {
  const DeleteMediaFiles(this._repository);

  final MediaLibraryRepository _repository;

  @override
  Future<Result<int>> call(List<MediaFile> params) =>
      _repository.deleteMany(params);
}

class PruneMissingMediaFiles implements UseCase<int, NoParams> {
  const PruneMissingMediaFiles(this._repository);

  final MediaLibraryRepository _repository;

  @override
  Future<Result<int>> call(NoParams params) => _repository.pruneMissing();
}
