import '../app_language.dart';

abstract interface class SettingsRepository {
  Future<AppLanguage> readLanguage();

  Future<void> saveLanguage(AppLanguage language);
}
