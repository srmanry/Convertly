import 'package:convertly/core/errors/failure.dart';
import 'package:convertly/core/types/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('success exposes its value and no failure', () {
      const Result<int> result = Result<int>.success(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('failure exposes its failure and no value', () {
      const Result<int> result = Result<int>.failure(CacheFailure());

      expect(result.isFailure, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, isA<CacheFailure>());
    });

    test('fold runs exactly one branch', () {
      const Result<String> success = Result<String>.success('ok');
      const Result<String> failure = Result<String>.failure(UnknownFailure());

      expect(success.fold((_) => 'failure', (String v) => v), 'ok');
      expect(failure.fold((_) => 'failure', (String v) => v), 'failure');
    });

    test('results with equal contents compare equal', () {
      expect(const Result<int>.success(1), const Result<int>.success(1));
      expect(const Result<int>.success(1), isNot(const Result<int>.success(2)));
      expect(
        const Result<int>.failure(CacheFailure()),
        const Result<int>.failure(CacheFailure()),
      );
    });
  });
}
