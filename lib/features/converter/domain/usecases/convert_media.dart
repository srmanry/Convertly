import '../../../../core/types/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/conversion_request.dart';
import '../entities/conversion_result.dart';
import '../repositories/conversion_repository.dart';

/// Runs a conversion. Shared by every tool in the app.
class ConvertMedia implements UseCase<ConversionResult, ConversionRequest> {
  const ConvertMedia(this._repository);

  final ConversionRepository _repository;

  @override
  Future<Result<ConversionResult>> call(
    ConversionRequest params, {
    void Function(double progress)? onProgress,
  }) {
    return _repository.convert(params, onProgress: onProgress);
  }
}

/// Cancels the running conversion.
class CancelConversion implements UseCase<void, NoParams> {
  const CancelConversion(this._repository);

  final ConversionRepository _repository;

  @override
  Future<Result<void>> call(NoParams params) async {
    await _repository.cancel();
    return const Result<void>.success(null);
  }
}
