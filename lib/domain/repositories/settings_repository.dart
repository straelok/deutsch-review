import '../app_language.dart';
import '../app_settings.dart';

abstract interface class SettingsRepository {
  Future<AppLanguage> readLanguage();

  Future<void> saveLanguage(AppLanguage language);

  Future<AppSettings> readAppSettings();

  Future<void> saveAppSettings(AppSettings settings);
}
