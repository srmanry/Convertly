import 'package:equatable/equatable.dart';
import 'package:get/get.dart';
import '../../../../core/i18n/translation_keys.dart';

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
  newest(K.sortNewest),
  oldest(K.sortOldest),
  name(K.sortName),
  size(K.sortSize);

  const MediaSortOrder(this.labelKey);

  final String labelKey;

  String get label => labelKey.tr;
}
