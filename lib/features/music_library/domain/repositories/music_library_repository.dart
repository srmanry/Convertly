import '../../../../core/types/result.dart';
import '../entities/song.dart';

/// Reads the tracks the player can offer.
abstract interface class MusicLibraryRepository {
  /// Whether the device's music can be read without asking again.
  Future<bool> hasDevicePermission();

  /// Asks for access to the device's audio.
  ///
  /// Returns whether it was granted. A refusal is not a failure: the player
  /// still works with the app's own files.
  Future<bool> requestDevicePermission();

  /// Songs already on the device, newest first.
  Future<Result<List<Song>>> deviceSongs();

  /// Files this app produced.
  Future<Result<List<Song>>> appSongs();
}
