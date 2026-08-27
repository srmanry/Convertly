import 'package:shared_preferences/shared_preferences.dart';

import '../errors/exceptions.dart';

/// Thin wrapper over [SharedPreferences].
///
/// Data sources depend on this instead of the plugin directly, so persistence
/// can be swapped later without touching any feature code.
class StorageService {
  StorageService(this._preferences);

  final SharedPreferences _preferences;

  /// Resolves the plugin instance. Called once during app bootstrap.
  static Future<StorageService> init() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return StorageService(preferences);
  }

  bool? readBool(String key) => _preferences.getBool(key);

  String? readString(String key) => _preferences.getString(key);

  int? readInt(String key) => _preferences.getInt(key);

  Future<void> writeBool(String key, bool value) async {
    if (!await _preferences.setBool(key, value)) {
      throw CacheException('Failed to persist bool for "$key"');
    }
  }

  Future<void> writeString(String key, String value) async {
    if (!await _preferences.setString(key, value)) {
      throw CacheException('Failed to persist string for "$key"');
    }
  }

  Future<void> writeInt(String key, int value) async {
    if (!await _preferences.setInt(key, value)) {
      throw CacheException('Failed to persist int for "$key"');
    }
  }

  Future<void> remove(String key) => _preferences.remove(key);

  Future<void> clear() => _preferences.clear();
}
