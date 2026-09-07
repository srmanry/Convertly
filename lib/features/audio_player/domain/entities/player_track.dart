import 'package:equatable/equatable.dart';

/// One item in the player's queue.
///
/// Deliberately just what the player needs to open and name a file, so a
/// queue can be built from the music library, the files list, or a single
/// finished conversion without any of them agreeing on a richer type.
class PlayerTrack extends Equatable {
  const PlayerTrack({required this.path, required this.title});

  /// Whatever identifies the audio: a real path, a `content://` uri from the
  /// phone's music index, or a `file://` uri from an iOS pick.
  final String path;

  final String title;

  Map<String, String> toArguments() => <String, String>{
    'path': path,
    'title': title,
  };

  /// Reads a track back out of route arguments, or null if the entry is not
  /// something the player can open.
  static PlayerTrack? fromArguments(Object? value) {
    if (value is! Map) {
      return null;
    }
    final Object? path = value['path'];
    if (path is! String || path.isEmpty) {
      return null;
    }
    final Object? title = value['title'];
    return PlayerTrack(
      path: path,
      title: title is String && title.isNotEmpty ? title : 'Audio',
    );
  }

  @override
  List<Object?> get props => <Object?>[path, title];
}
