import '../../../../core/types/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/storage_usage.dart';
import '../repositories/storage_repository.dart';

class GetStorageUsage implements UseCase<StorageUsage, NoParams> {
  const GetStorageUsage(this._repository);

  final StorageRepository _repository;

  @override
  Future<Result<StorageUsage>> call(NoParams params) => _repository.readUsage();
}

class ClearWorkingFiles implements UseCase<void, NoParams> {
  const ClearWorkingFiles(this._repository);

  final StorageRepository _repository;

  @override
  Future<Result<void>> call(NoParams params) => _repository.clearWorkingFiles();
}

class ClearConvertedFiles implements UseCase<int, NoParams> {
  const ClearConvertedFiles(this._repository);

  final StorageRepository _repository;

  @override
  Future<Result<int>> call(NoParams params) =>
      _repository.clearConvertedFiles();
}
