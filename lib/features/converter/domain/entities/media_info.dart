import 'package:equatable/equatable.dart';

/// A media file the user selected, after validation.
class MediaInfo extends Equatable {
  const MediaInfo({
    required this.path,
    required this.name,
    required this.sizeInBytes,
    required this.extension,
    required this.hasAudio,
    required this.hasVideo,
    this.duration,
    this.audioCodec,
  });

  final String path;
  final String name;
  final int sizeInBytes;
  final String extension;
  final bool hasAudio;
  final bool hasVideo;
  final Duration? duration;
  final String? audioCodec;

  /// Name without its extension, used to seed the output filename.
  String get baseName {
    final int dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  @override
  List<Object?> get props => <Object?>[
    path,
    name,
    sizeInBytes,
    extension,
    hasAudio,
    hasVideo,
    duration,
    audioCodec,
  ];
}
