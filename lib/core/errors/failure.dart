import 'package:equatable/equatable.dart';
import 'package:get/get.dart';

import '../i18n/translation_keys.dart';

/// Base type for every recoverable error that crosses a layer boundary.
///
/// A [Failure] always carries a [message] that is safe to show to a user.
/// Technical detail stays in [debugMessage] and must never reach the UI.
sealed class Failure extends Equatable {
  const Failure({required this.messageKey, this.debugMessage});

  /// What to tell the user, as a translation key.
  ///
  /// A key rather than the sentence itself: a failure is often built deep in
  /// a repository, long before anyone reads it, and the language can change
  /// in between. Text that is not a known key is shown as it is, so a message
  /// that has no translation yet still reads as a sentence.
  final String messageKey;

  /// Technical detail for logs. Never shown, so never translated.
  final String? debugMessage;

  /// The message in the language the app is being read in.
  String get message => messageKey.tr;

  @override
  List<Object?> get props => <Object?>[messageKey, debugMessage];
}

/// Reading from or writing to local persistence failed.
class CacheFailure extends Failure {
  const CacheFailure({
    super.messageKey = K.errorCache,
    super.debugMessage,
  });
}

/// A required runtime permission was denied by the user or the system.
class PermissionFailure extends Failure {
  const PermissionFailure({
    super.messageKey = K.errorPermission,
    super.debugMessage,
  });
}

/// The requested file is missing, unreadable or not a supported media file.
class FileFailure extends Failure {
  const FileFailure({
    super.messageKey = K.errorUnsupportedFile,
    super.debugMessage,
  });
}

/// The device does not have enough free space for the requested operation.
class StorageFailure extends Failure {
  const StorageFailure({
    super.messageKey = K.errorStorage,
    super.debugMessage,
  });
}

/// FFmpeg could not complete the conversion.
class ConversionFailure extends Failure {
  const ConversionFailure({
    super.messageKey = K.errorConversion,
    super.debugMessage,
  });
}

/// The user stopped the conversion. Not an error; shown as a neutral message.
class ConversionCancelled extends Failure {
  const ConversionCancelled({
    super.messageKey = K.errorCancelled,
    super.debugMessage,
  });
}

/// Anything that was not anticipated. Always log [debugMessage].
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.messageKey = K.errorUnknown,
    super.debugMessage,
  });
}
