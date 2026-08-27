import '../../../../core/types/result.dart';
import '../entities/conversion_request.dart';
import '../entities/conversion_result.dart';

/// Running and cancelling conversions.
abstract interface class ConversionRepository {
  /// Executes [request], reporting progress from 0.0 to 1.0.
  Future<Result<ConversionResult>> convert(
    ConversionRequest request, {
    void Function(double progress)? onProgress,
  });

  /// Stops the running conversion, if any.
  Future<void> cancel();

  /// Resolves the directory output is written to.
  Future<Result<String>> resolveOutputDirectory();
}
