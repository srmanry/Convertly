import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/types/result.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_datasource.dart';
import '../models/app_settings_model.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(this._localDataSource);

  final SettingsLocalDataSource _localDataSource;

  @override
  Future<Result<AppSettings>> getSettings() async {
    try {
      return Result<AppSettings>.success(_localDataSource.read().toEntity());
    } catch (error) {
      // Corrupt or unreadable preferences must not stop the app from starting.
      return Result<AppSettings>.failure(
        CacheFailure(
          message: 'Could not load your settings. Defaults are being used.',
          debugMessage: error.toString(),
        ),
      );
    }
  }

  @override
  Future<Result<AppSettings>> saveSettings(AppSettings settings) async {
    try {
      final AppSettingsModel model = AppSettingsModel.fromEntity(settings);
      await _localDataSource.write(model);
      return Result<AppSettings>.success(model.toEntity());
    } on CacheException catch (error) {
      return Result<AppSettings>.failure(
        CacheFailure(
          message: 'Could not save your settings. Please try again.',
          debugMessage: error.toString(),
        ),
      );
    } catch (error) {
      return Result<AppSettings>.failure(
        UnknownFailure(debugMessage: error.toString()),
      );
    }
  }
}
