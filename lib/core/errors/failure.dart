import 'package:equatable/equatable.dart';

/// Base type for every recoverable error that crosses a layer boundary.
///
/// A [Failure] always carries a [message] that is safe to show to a user.
/// Technical detail stays in [debugMessage] and must never reach the UI.
sealed class Failure extends Equatable {
  const Failure({required this.message, this.debugMessage});

  final String message;
  final String? debugMessage;

  @override
  List<Object?> get props => <Object?>[message, debugMessage];
}

/// Reading from or writing to local persistence failed.
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Could not access local data. Please try again.',
    super.debugMessage,
  });
}

/// A required runtime permission was denied by the user or the system.
class PermissionFailure extends Failure {
  const PermissionFailure({
    super.message = 'Permission is required to continue.',
    super.debugMessage,
  });
}

/// The requested file is missing, unreadable or not a supported media file.
class FileFailure extends Failure {
  const FileFailure({
    super.message = 'This file could not be opened. Please choose another one.',
    super.debugMessage,
  });
}

/// The device does not have enough free space for the requested operation.
class StorageFailure extends Failure {
  const StorageFailure({
    super.message = 'Not enough storage space available.',
    super.debugMessage,
  });
}

/// FFmpeg could not complete the conversion.
class ConversionFailure extends Failure {
  const ConversionFailure({
    super.message = 'Unable to convert this file. Please try another one.',
    super.debugMessage,
  });
}

/// The user stopped the conversion. Not an error; shown as a neutral message.
class ConversionCancelled extends Failure {
  const ConversionCancelled({
    super.message = 'Conversion cancelled.',
    super.debugMessage,
  });
}

/// Anything that was not anticipated. Always log [debugMessage].
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'Something went wrong. Please try again.',
    super.debugMessage,
  });
}
