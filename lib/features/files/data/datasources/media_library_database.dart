import 'package:sqflite/sqflite.dart';

import '../models/media_file_model.dart';

/// Owns the SQLite connection for the media library.
class MediaLibraryDatabase {
  MediaLibraryDatabase({this.databaseName = 'convertly_library.db'});

  static const int _version = 1;

  final String databaseName;

  Database? _database;

  /// Opens the database on first use and reuses it afterwards.
  Future<Database> open() async {
    final Database? existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }

    final String path = '${await getDatabasesPath()}/$databaseName';
    final Database database = await openDatabase(
      path,
      version: _version,
      onCreate: (Database db, int version) async {
        await db.execute(MediaFileMapper.createTableStatement);
      },
    );

    _database = database;
    return database;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
