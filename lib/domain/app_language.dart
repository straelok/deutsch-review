enum AppLanguage {
  german('de'),
  russian('ru');

  const AppLanguage(this.code);

  final String code;

  static AppLanguage fromCode(String? value) {
    return value == russian.code ? russian : german;
  }
}
