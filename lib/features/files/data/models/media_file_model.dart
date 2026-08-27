import '../../domain/entities/media_file.dart';

/// Maps [MediaFile] to and from its database row.
///
/// Enums are stored by name, so reordering them cannot corrupt existing rows.
abstract final class MediaFileMapper {
  static const String table = 'media_files';

  static const String columnId = 'id';
  static const String columnName = 'name';
  static const String columnOriginalName = 'original_name';
  static const String columnPath = 'path';
  static const String columnType = 'type';
  static const String columnFormat = 'format';
  static const String columnSize = 'size_bytes';
  static const String columnDuration = 'duration_ms';
  static const String columnCreatedAt = 'created_at';
  static const String columnSourceType = 'source_type';

  static const String createTableStatement =
      '''
CREATE TABLE $table (
  $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
  $columnName TEXT NOT NULL,
  $columnOriginalName TEXT NOT NULL,
  $columnPath TEXT NOT NULL UNIQUE,
  $columnType TEXT NOT NULL,
  $columnFormat TEXT NOT NULL,
  $columnSize INTEGER NOT NULL,
  $columnDuration INTEGER,
  $columnCreatedAt INTEGER NOT NULL,
  $columnSourceType TEXT NOT NULL
)''';

  static Map<String, Object?> toRow(MediaFile file) {
    return <String, Object?>{
      // Left out when null so SQLite assigns the autoincrement id.
      if (file.id != null) columnId: file.id,
      columnName: file.name,
      columnOriginalName: file.originalName,
      columnPath: file.path,
      columnType: file.type.name,
      columnFormat: file.format,
      columnSize: file.sizeInBytes,
      columnDuration: file.duration?.inMilliseconds,
      columnCreatedAt: file.createdAt.millisecondsSinceEpoch,
      columnSourceType: file.sourceType.name,
    };
  }

  static MediaFile fromRow(Map<String, Object?> row) {
    final Object? durationMs = row[columnDuration];

    return MediaFile(
      id: row[columnId] as int?,
      name: row[columnName]! as String,
      originalName: row[columnOriginalName]! as String,
      path: row[columnPath]! as String,
      type: _parseType(row[columnType] as String?),
      format: row[columnFormat]! as String,
      sizeInBytes: row[columnSize]! as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row[columnCreatedAt]! as int,
      ),
      sourceType: _parseSourceType(row[columnSourceType] as String?),
      duration: durationMs is int ? Duration(milliseconds: durationMs) : null,
    );
  }

  static MediaFileType _parseType(String? name) {
    return MediaFileType.values.firstWhere(
      (MediaFileType type) => type.name == name,
      orElse: () => MediaFileType.audio,
    );
  }

  static MediaSourceType _parseSourceType(String? name) {
    return MediaSourceType.values.firstWhere(
      (MediaSourceType type) => type.name == name,
      orElse: () => MediaSourceType.videoToAudio,
    );
  }
}
