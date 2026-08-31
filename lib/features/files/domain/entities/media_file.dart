import 'package:equatable/equatable.dart';

/// What produced a file in the library.
enum MediaSourceType {
  videoToAudio,
  audioConvert,
  cut,
  merge,
  compress,
  mix,
  arrange,
  cleanup,
}

/// Whether an entry is audio or video.
enum MediaFileType { audio, video }

/// A converted file, as tracked in the local database.
///
/// Only metadata and a path live here; the media itself stays on disk.
class MediaFile extends Equatable {
  const MediaFile({
    required this.id,
    required this.name,
    required this.originalName,
    required this.path,
    required this.type,
    required this.format,
    required this.sizeInBytes,
    required this.createdAt,
    required this.sourceType,
    this.duration,
  });

  final int? id;
  final String name;
  final String originalName;
  final String path;
  final MediaFileType type;
  final String format;
  final int sizeInBytes;
  final DateTime createdAt;
  final MediaSourceType sourceType;
  final Duration? duration;

  MediaFile copyWith({int? id, String? name, String? path, int? sizeInBytes}) {
    return MediaFile(
      id: id ?? this.id,
      name: name ?? this.name,
      originalName: originalName,
      path: path ?? this.path,
      type: type,
      format: format,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      createdAt: createdAt,
      sourceType: sourceType,
      duration: duration,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    originalName,
    path,
    type,
    format,
    sizeInBytes,
    createdAt,
    sourceType,
    duration,
  ];
}

/// Ordering offered in the files list.
enum MediaSortOrder {
  newest('Newest'),
  oldest('Oldest'),
  name('Name'),
  size('Size');

  const MediaSortOrder(this.label);

  final String label;
}
