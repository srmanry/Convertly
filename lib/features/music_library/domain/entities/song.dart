import 'package:equatable/equatable.dart';

/// Where a track came from.
enum SongSource {
  /// Already on the device, found by the system's media index.
  phone,

  /// Produced by this app and kept in its own folder.
  app,
}

/// One playable track, from either source.
///
/// The two sources describe files very differently — the device index knows
/// artists and albums, the app's own library knows formats and tools — so both
/// are reduced to this before the list ever sees them.
class Song extends Equatable {
  const Song({
    required this.id,
    required this.title,
    required this.path,
    required this.source,
    this.artist,
    this.duration,
    this.sizeInBytes,
  });

  /// Unique within its source.
  final String id;

  final String title;

  /// What the player opens. A device track is a real file path.
  final String path;

  final SongSource source;

  /// Null when the file carries no artist tag, which is normal for a
  /// converted file.
  final String? artist;

  final Duration? duration;
  final int? sizeInBytes;

  /// What to show under the title, or null when there is nothing worth saying.
  String? get subtitle {
    final String? name = artist?.trim();
    if (name == null || name.isEmpty || name == '<unknown>') {
      return null;
    }
    return name;
  }

  @override
  List<Object?> get props => <Object?>[id, source];
}
