import 'package:equatable/equatable.dart';

import '../types/result.dart';

/// A single application action.
///
/// Use cases are the only entry point the presentation layer has into the
/// domain layer, which keeps controllers free of business rules.
abstract class UseCase<T, Params> {
  Future<Result<T>> call(Params params);
}

/// A use case that resolves synchronously, e.g. static domain data.
abstract class SyncUseCase<T, Params> {
  Result<T> call(Params params);
}

/// Placeholder for use cases that take no arguments.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => const <Object?>[];
}
