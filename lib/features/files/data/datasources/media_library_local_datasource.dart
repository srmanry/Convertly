import 'package:sqflite/sqflite.dart';

import '../../domain/entities/media_file.dart';
import '../models/media_file_model.dart';
import 'media_library_database.dart';

abstract interface class MediaLibraryLocalDataSource {
  Future<List<MediaFile>> readAll();

  Future<MediaFile> insert(MediaFile file);

  Future<void> updateFile(MediaFile file);

  Future<void> deleteById(int id);
}

class MediaLibraryLocalDataSourceImpl implements MediaLibraryLocalDataSource {
  const MediaLibraryLocalDataSourceImpl(this._database);

  final MediaLibraryDatabase _database;

  @override
  Future<List<MediaFile>> readAll() async {
    final Database db = await _database.open();
    final List<Map<String, Object?>> rows = await db.query(
      MediaFileMapper.table,
      orderBy: '${MediaFileMapper.columnCreatedAt} DESC',
    );
    return rows.map(MediaFileMapper.fromRow).toList();
  }

  @override
  Future<MediaFile> insert(MediaFile file) async {
    final Database db = await _database.open();
    final int id = await db.insert(
      MediaFileMapper.table,
      MediaFileMapper.toRow(file),
      // Re-converting to the same path replaces the stale row rather than
      // failing the UNIQUE constraint.
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return file.copyWith(id: id);
  }

  @override
  Future<void> updateFile(MediaFile file) async {
    final Database db = await _database.open();
    await db.update(
      MediaFileMapper.table,
      MediaFileMapper.toRow(file),
      where: '${MediaFileMapper.columnId} = ?',
      whereArgs: <Object?>[file.id],
    );
  }

  @override
  Future<void> deleteById(int id) async {
    final Database db = await _database.open();
    await db.delete(
      MediaFileMapper.table,
      where: '${MediaFileMapper.columnId} = ?',
      whereArgs: <Object?>[id],
    );
  }
}
