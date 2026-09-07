import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../domain/entities/player_track.dart';
import '../controllers/audio_player_controller.dart';

class AudioPlayerBinding extends Bindings {
  @override
  void dependencies() {
    final Map<Object?, Object?> args = Get.arguments is Map<Object?, Object?>
        ? Get.arguments as Map<Object?, Object?>
        : const <Object?, Object?>{};

    Get.lazyPut<AudioPlayerController>(
      () => AudioPlayerController(
        queue: queueFrom(args),
        startIndex: args['index'] is int ? args['index']! as int : 0,
      ),
    );
  }

  /// Builds the queue from the arguments.
  ///
  /// Callers that have a list to play through pass one; the rest pass a single
  /// path and title, which becomes a queue of one rather than a special case
  /// the player has to know about.
  ///
  /// Public so a test can exercise this parsing directly: Get.arguments is
  /// only set by real navigation, and a test that reimplemented the parsing
  /// would be checking a copy rather than the code that ships.
  @visibleForTesting
  static List<PlayerTrack> queueFrom(Map<Object?, Object?> args) {
    final Object? queue = args['queue'];
    if (queue is List) {
      final List<PlayerTrack> tracks = queue
          .map(PlayerTrack.fromArguments)
          .nonNulls
          .toList();
      if (tracks.isNotEmpty) {
        return tracks;
      }
    }

    final PlayerTrack? single = PlayerTrack.fromArguments(args);
    return single == null ? const <PlayerTrack>[] : <PlayerTrack>[single];
  }
}
