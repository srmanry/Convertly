import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/entities/song.dart';

/// Reads the songs the device already knows about.
///
/// Backed by Android's own media index through a channel this app owns. The
/// published plugins for this no longer configure under current Gradle, and a
/// music list is too central here to rest on one.
abstract interface class DeviceAudioDataSource {
  Future<bool> hasPermission();

  Future<bool> requestPermission();

  Future<List<Song>> readSongs();
}

class DeviceAudioDataSourceImpl implements DeviceAudioDataSource {
  const DeviceAudioDataSourceImpl([
    this._channel = const MethodChannel(channelName),
  ]);

  static const String channelName = 'convertly/device_audio';

  final MethodChannel _channel;

  /// Only Android has the index this reads; elsewhere the player falls back to
  /// the app's own files rather than calling a channel that is not there.
  bool get _isSupported => Platform.isAndroid;

  @override
  Future<bool> hasPermission() async {
    if (!_isSupported) {
      return false;
    }
    return await _channel.invokeMethod<bool>('hasPermission') ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_isSupported) {
      return false;
    }
    return await _channel.invokeMethod<bool>('requestPermission') ?? false;
  }

  @override
  Future<List<Song>> readSongs() async {
    if (!_isSupported) {
      return const <Song>[];
    }

    final List<Object?>? rows = await _channel.invokeMethod<List<Object?>>(
      'querySongs',
    );
    if (rows == null) {
      return const <Song>[];
    }

    return <Song>[
      for (final Object? row in rows)
        if (row is Map) fromRow(row),
    ];
  }

  /// Builds a song from one row of the index.
  ///
  /// Every field but the id and uri can be missing: the index is filled from
  /// file tags, and plenty of files carry none.
  static Song fromRow(Map<Object?, Object?> row) {
    final Object? durationMs = row['durationMs'];
    final Object? size = row['sizeBytes'];
    final String uri = row['uri'] as String? ?? '';
    final String? title = row['title'] as String?;

    return Song(
      id: 'device:${row['id']}',
      // An untagged file still has a name worth showing, so the uri's last
      // part stands in rather than leaving the row blank.
      title: title == null || title.trim().isEmpty ? _nameFromUri(uri) : title,
      path: uri,
      source: SongSource.phone,
      artist: row['artist'] as String?,
      duration: durationMs is int ? Duration(milliseconds: durationMs) : null,
      sizeInBytes: size is int ? size : null,
    );
  }

  static String _nameFromUri(String uri) {
    final int slash = uri.lastIndexOf('/');
    final String tail = slash < 0 ? uri : uri.substring(slash + 1);
    return tail.isEmpty ? 'Unknown track' : tail;
  }
}
