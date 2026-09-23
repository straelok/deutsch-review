import '../domain/app_language.dart';

final class UiStrings {
  const UiStrings(this.language);

  final AppLanguage language;

  bool get isRussian => language == AppLanguage.russian;

  String choose(String german, String russian) => isRussian ? russian : german;

  String get today => choose('Heute', 'Сегодня');
  String get learn => choose('Lernen', 'Повторение');
  String get material => choose('Wörter', 'Слова');
  String get statistics => choose('Statistik', 'Статистика');
  String get switchLanguage => choose('Sprache wechseln', 'Сменить язык');
  String get noReviewsToday => choose(
        'Für heute sind noch keine Wiederholungen geplant.',
        'На сегодня повторения пока не запланированы.',
      );
  String entries(int count) => choose(
        '$count Wörter',
        '$count слов',
      );
  String get add => choose('Hinzufügen', 'Добавить');
  String get loadError => choose(
        'Die Wörter konnten nicht geladen werden.',
        'Не удалось загрузить слова.',
      );
  String get retry => choose('Erneut laden', 'Повторить');
  String get noWords => choose('Noch keine Wörter', 'Слов пока нет');
  String get noWordsHint => choose(
        'Füge den bereits gelernten Stoff aus deinem Kurs hinzu.',
        'Добавьте уже изученный материал из курса.',
      );
  String get search => choose('Wörter durchsuchen', 'Поиск по словам');
  String get noSearchResults => choose('Nichts gefunden', 'Ничего не найдено');
  String get edit => choose('Bearbeiten', 'Редактировать');
  String get delete => choose('Löschen', 'Удалить');
  String get deleteTitle => choose('Eintrag löschen?', 'Удалить запись?');
  String deleteMessage(String word) => choose(
        '„$word“ wird aus Wörtern und Wiederholungen entfernt.',
        '«$word» будет удалено из словаря и повторений.',
      );
  String get cancel => choose('Abbrechen', 'Отмена');
  String get undo => choose('Rückgängig', 'Отменить');
  String get deleted => choose('Eintrag gelöscht.', 'Запись удалена.');
  String get added => choose('Eintrag hinzugefügt.', 'Запись добавлена.');
  String get saved => choose('Änderungen gespeichert.', 'Изменения сохранены.');
  String get saveError => choose(
        'Der Eintrag konnte nicht gespeichert werden.',
        'Не удалось сохранить запись.',
      );
  String get duplicateTitle => choose('Mögliches Duplikat', 'Возможный дубль');
  String get duplicateMessage => choose(
        'Ein ähnlicher Eintrag ist bereits vorhanden. Trotzdem speichern?',
        'Похожая запись уже существует. Всё равно сохранить?',
      );
  String get saveAnyway => choose('Trotzdem speichern', 'Сохранить');
  String get addMaterial => choose('Wort hinzufügen', 'Добавить слово');
  String get editMaterial => choose('Wort bearbeiten', 'Редактировать слово');
  String get type => choose('Typ', 'Тип');
  String get word => choose('Wort', 'Слово');
  String get noun => choose('Nomen', 'Существительное');
  String get article => choose('Artikel', 'Артикль');
  String get germanWord => choose('Deutsches Wort', 'Немецкое слово');
  String get plural => choose('Plural', 'Множественное число');
  String get meaning => choose('Bedeutung', 'Перевод');
  String get note => choose('Notiz (optional)', 'Заметка (необязательно)');
  String get usageExample =>
      choose('Beispiel (optional)', 'Пример использования (необязательно)');
  String noteValue(String value) => choose('Notiz: $value', 'Заметка: $value');
  String exampleValue(String value) =>
      choose('Beispiel: $value', 'Пример: $value');
  String addedAt(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final date = '$day.$month.${local.year}, $hour:$minute';
    return choose('Hinzugefügt: $date', 'Добавлено: $date');
  }

  String get requiredField => choose('Pflichtfeld', 'Обязательное поле');
  String get save => choose('Speichern', 'Сохранить');
  String get startReview => choose('Wiederholung starten', 'Начать повторение');
  String get reviewEmpty => choose(
        'Füge zuerst ein Wort oder Nomen hinzu.',
        'Сначала добавьте слово или существительное.',
      );
  String get reviewIntro => choose(
        'Schreibe die deutsche Übersetzung. Fehler kommen später erneut.',
        'Введите перевод на немецком. Ошибки повторятся позже.',
      );
  String get yourAnswer => choose('Deine Antwort', 'Ваш ответ');
  String get check => choose('Prüfen', 'Проверить');
  String get correct => choose('Richtig', 'Правильно');
  String get incorrect => choose('Noch nicht richtig', 'Пока неверно');
  String correctAnswer(String answer) => choose(
        'Richtige Antwort: $answer',
        'Правильный ответ: $answer',
      );
  String get next => choose('Weiter', 'Далее');
  String progress(int remaining) => choose(
        '$remaining Wörter verbleiben',
        'Осталось слов: $remaining',
      );
  String get sessionComplete => choose(
        'Sitzung abgeschlossen',
        'Повторение завершено',
      );
  String get sessionCompleteHint => choose(
        'Alle Wörter wurden richtig beantwortet.',
        'Все слова отвечены правильно.',
      );
  String get again => choose('Noch einmal', 'Повторить ещё раз');
  String get statsEmpty => choose(
        'Noch keine Wiederholungen. Starte eine Sitzung unter „Lernen“.',
        'Повторений пока нет. Начните занятие в разделе «Повторение».',
      );
  String get attempts => choose('Versuche', 'Попытки');
  String get correctAnswers => choose('Richtig', 'Правильно');
  String get errors => choose('Fehler', 'Ошибки');
  String get accuracy => choose('Genauigkeit', 'Точность');
  String get problemWords => choose('Problemwörter', 'Проблемные слова');
  String get wordStatistics =>
      choose('Statistik für dieses Wort', 'Статистика по этому слову');
  String errorCount(int count) => choose('$count Fehler', 'Ошибок: $count');
  String get loading => choose('Wird geladen…', 'Загрузка…');
}
