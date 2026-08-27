import '../../../../core/types/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/app_settings.dart';
import '../repositories/settings_repository.dart';

class SaveSettings implements UseCase<AppSettings, AppSettings> {
  const SaveSettings(this._repository);

  final SettingsRepository _repository;

  @override
  Future<Result<AppSettings>> call(AppSettings params) =>
      _repository.saveSettings(params);
}
