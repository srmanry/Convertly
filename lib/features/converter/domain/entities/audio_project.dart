import '../../../../core/enums/audio_format.dart';
import '../../../../core/enums/audio_quality.dart';
import '../../../../core/enums/export_speed.dart';
import '../../../../core/enums/mix_length_mode.dart';
import '../../../../core/enums/tool_mode.dart';
import 'media_info.dart';
import 'mix_track.dart';
import 'volume_envelope.dart';

enum AudioProjectStatus { draft, completed, cancelled }

/// An editable timeline or mix, separate from the audio it exports.
class AudioProject {
  const AudioProject({
    required this.id,
    required this.mode,
    required this.status,
    required this.updatedAt,
    required this.sources,
    required this.clips,
    required this.fileName,
    required this.format,
    required this.quality,
    required this.speed,
    required this.mixLength,
    required this.loopShorterTracks,
    this.outputPath,
  });

  final String id;
  final ToolMode mode;
  final AudioProjectStatus status;
  final DateTime updatedAt;
  final List<MediaInfo> sources;
  final List<MixTrack> clips;
  final String fileName;
  final AudioFormat format;
  final AudioQuality quality;
  final ExportSpeed speed;
  final MixLengthMode mixLength;
  final bool loopShorterTracks;
  final String? outputPath;

  AudioProject withSources(List<MediaInfo> sources) => AudioProject(
    id: id,
    mode: mode,
    status: status,
    updatedAt: updatedAt,
    sources: sources,
    clips: clips,
    fileName: fileName,
    format: format,
    quality: quality,
    speed: speed,
    mixLength: mixLength,
    loopShorterTracks: loopShorterTracks,
    outputPath: outputPath,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'mode': mode.name,
    'status': status.name,
    'updatedAt': updatedAt.toIso8601String(),
    'fileName': fileName,
    'format': format.name,
    'quality': quality.name,
    'speed': speed.value,
    'mixLength': mixLength.name,
    'loopShorterTracks': loopShorterTracks,
    'outputPath': outputPath,
    'sources': <Map<String, Object?>>[
      for (final MediaInfo source in sources)
        <String, Object?>{
          'path': source.path,
          'name': source.name,
          'size': source.sizeInBytes,
          'extension': source.extension,
          'hasAudio': source.hasAudio,
          'hasVideo': source.hasVideo,
          'duration': source.duration?.inMicroseconds,
          'audioCodec': source.audioCodec,
          'channels': source.channels,
          'playbackUri': source.playbackUri,
        },
    ],
    'clips': <Map<String, Object?>>[
      for (final MixTrack clip in clips)
        <String, Object?>{
          'volume': clip.volume,
          'start': clip.start.inMicroseconds,
          'trimStart': clip.trimStart.inMicroseconds,
          'trimEnd': clip.trimEnd?.inMicroseconds,
          'length': clip.length?.inMicroseconds,
          'envelope': clip.envelope == null
              ? null
              : <List<double>>[
                  for (final EnvelopePoint point in clip.envelope!.points)
                    <double>[point.position, point.level],
                ],
        },
    ],
  };

  factory AudioProject.fromJson(Map<String, dynamic> json) {
    final ToolMode mode = ToolMode.values.byName(json['mode'] as String);
    if (!mode.combinesTracks) {
      throw const FormatException('Only timelines and mixes are projects');
    }
    final List<MediaInfo> sources = <MediaInfo>[
      for (final dynamic item in json['sources'] as List<dynamic>)
        MediaInfo(
          path: item['path'] as String,
          name: item['name'] as String,
          sizeInBytes: item['size'] as int,
          extension: item['extension'] as String,
          hasAudio: item['hasAudio'] as bool,
          hasVideo: item['hasVideo'] as bool,
          duration: _duration(item['duration']),
          audioCodec: item['audioCodec'] as String?,
          channels: item['channels'] as int?,
          playbackUri: item['playbackUri'] as String?,
        ),
    ];
    final List<MixTrack> clips = <MixTrack>[
      for (final dynamic item in json['clips'] as List<dynamic>)
        MixTrack(
          volume: (item['volume'] as num).toDouble(),
          start: _duration(item['start'])!,
          trimStart: _duration(item['trimStart'])!,
          trimEnd: _duration(item['trimEnd']),
          length: _duration(item['length']),
          envelope: item['envelope'] == null
              ? null
              : VolumeEnvelope(<EnvelopePoint>[
                  for (final dynamic point in item['envelope'] as List<dynamic>)
                    EnvelopePoint(
                      (point[0] as num).toDouble(),
                      (point[1] as num).toDouble(),
                    ),
                ]),
        ),
    ];
    if (sources.length != clips.length) {
      throw const FormatException('Project clips and sources do not match');
    }
    return AudioProject(
      id: json['id'] as String,
      mode: mode,
      status: AudioProjectStatus.values.byName(json['status'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      sources: sources,
      clips: clips,
      fileName: json['fileName'] as String,
      format: AudioFormat.fromName(json['format'] as String),
      quality: AudioQuality.fromName(json['quality'] as String),
      speed: ExportSpeed.fromValue((json['speed'] as num).toDouble()),
      mixLength: MixLengthMode.values.byName(json['mixLength'] as String),
      loopShorterTracks: json['loopShorterTracks'] as bool,
      outputPath: json['outputPath'] as String?,
    );
  }

  static Duration? _duration(dynamic value) =>
      value == null ? null : Duration(microseconds: value as int);
}
