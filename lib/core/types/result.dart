import '../errors/failure.dart';

/// The outcome of an operation that can fail in an expected way.
///
/// Domain and data layers return `Result<T>` instead of throwing, so the
/// presentation layer is forced to handle both branches.
sealed class Result<T> {
  const Result();

  /// Wraps a successful value.
  const factory Result.success(T value) = Success<T>;

  /// Wraps an expected [Failure].
  const factory Result.failure(Failure failure) = Error<T>;

  bool get isSuccess => this is Success<T>;

  bool get isFailure => this is Error<T>;

  /// The value when successful, otherwise `null`.
  T? get valueOrNull => switch (this) {
    Success<T>(:final T value) => value,
    Error<T>() => null,
  };

  /// The failure when unsuccessful, otherwise `null`.
  Failure? get failureOrNull => switch (this) {
    Success<T>() => null,
    Error<T>(:final Failure failure) => failure,
  };

  /// Collapses both branches into a single value.
  R fold<R>(
    R Function(Failure failure) onFailure,
    R Function(T value) onSuccess,
  ) {
    return switch (this) {
      Success<T>(:final T value) => onSuccess(value),
      Error<T>(:final Failure failure) => onFailure(failure),
    };
  }
}

class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Success<T> && other.value == value);

  @override
  int get hashCode => value.hashCode;
}

class Error<T> extends Result<T> {
  const Error(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Error<T> && other.failure == failure);

  @override
  int get hashCode => failure.hashCode;
}
