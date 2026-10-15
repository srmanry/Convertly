import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/services/storage_service.dart';
import '../domain/entities/audio_project.dart';
import '../domain/entities/media_info.dart';

/// Saves editor state and owns durable input copies outside the temp cache.
class AudioProjectStore extends GetxService {
  AudioProjectStore(
    this._storage, {
    Future<Directory> Function()? directory,
    Future<void> Function(MediaInfo, File)? copySource,
  }) : _directory = directory ?? _defaultDirectory,
       _copySource = copySource ?? _defaultCopy {
    try {
      final String? raw = _storage.readString(storageKey);
      if (raw != null) {
        projects.assignAll(<AudioProject>[
          for (final dynamic item in jsonDecode(raw) as List<dynamic>)
            AudioProject.fromJson(item as Map<String, dynamic>),
        ]);
        _sort();
      }
    } catch (_) {
      // Do not overwrite an unreadable index with an empty one.
      loadFailed = true;
    }
  }

  static const String storageKey = 'audio_projects_v1';
  final StorageService _storage;
  final Future<Directory> Function() _directory;
  final Future<void> Function(MediaInfo, File) _copySource;
  final RxList<AudioProject> projects = <AudioProject>[].obs;
  final Map<String, MediaInfo> _copies = <String, MediaInfo>{};
  Future<void> _queue = Future<void>.value();
  bool loadFailed = false;
  int _fileSequence = 0;

  Future<AudioProject> save(AudioProject project) {
    final Completer<AudioProject> result = Completer<AudioProject>();
    _queue = _queue.then((_) async {
      try {
        result.complete(await _save(project));
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<AudioProject> _save(AudioProject project) async {
    if (loadFailed) {
      throw StateError('Project index could not be read');
    }
    if (!project.mode.combinesTracks ||
        !RegExp(r'^\d+$').hasMatch(project.id) ||
        project.sources.length != project.clips.length) {
      throw ArgumentError('Invalid audio project');
    }
    final Directory root = await _directory();
    final Directory assets = Directory('${root.path}/${project.id}');
    await assets.create(recursive: true);
    final List<MediaInfo> sources = <MediaInfo>[];
    for (final MediaInfo source in project.sources) {
      if (source.path.startsWith('${assets.path}/') &&
          await File(source.path).exists()) {
        sources.add(source);
        continue;
      }
      final String key = '${project.id}|${source.path}|${source.playbackUri}';
      final MediaInfo? cached = _copies[key];
      if (cached != null && await File(cached.path).exists()) {
        sources.add(cached);
        continue;
      }
      final String extension = source.extension.replaceAll(
        RegExp('[^a-zA-Z0-9]'),
        '',
      );
      final File target = File(
        '${assets.path}/${DateTime.now().microsecondsSinceEpoch}_${_fileSequence++}.$extension',
      );
      try {
        await _copySource(source, target);
        if (!await target.exists() || await target.length() == 0) {
          throw const FileSystemException('Could not preserve project input');
        }
      } catch (_) {
        if (await target.exists()) {
          await target.delete();
        }
        rethrow;
      }
      final MediaInfo saved = MediaInfo(
        path: target.path,
        name: source.name,
        sizeInBytes: await target.length(),
        extension: source.extension,
        hasAudio: source.hasAudio,
        hasVideo: source.hasVideo,
        duration: source.duration,
        audioCodec: source.audioCodec,
        channels: source.channels,
        playbackUri: target.path,
      );
      _copies[key] = saved;
      sources.add(saved);
    }
    final AudioProject saved = project.withSources(sources);
    final List<AudioProject> next = <AudioProject>[
      saved,
      ...projects.where((AudioProject item) => item.id != project.id),
    ];
    await _storage.writeString(
      storageKey,
      jsonEncode(next.map((AudioProject item) => item.toJson()).toList()),
    );
    projects.assignAll(next);
    _sort();
    return saved;
  }

  void _sort() => projects.sort(
    (AudioProject a, AudioProject b) => b.updatedAt.compareTo(a.updatedAt),
  );

  static Future<Directory> _defaultDirectory() async => Directory(
    '${(await getApplicationSupportDirectory()).path}/audio_projects',
  );

  static Future<void> _defaultCopy(MediaInfo source, File target) async {
    final Uri uri = Uri.parse(source.playbackUri ?? source.path);
    if (uri.scheme == 'content') {
      await const MethodChannel('convertly/device_audio').invokeMethod<void>(
        'copyProjectInput',
        <String, String>{'uri': uri.toString(), 'path': target.path},
      );
    } else {
      await File(
        uri.scheme == 'file' ? uri.toFilePath() : source.path,
      ).copy(target.path);
    }
  }
}
