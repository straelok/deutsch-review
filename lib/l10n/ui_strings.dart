import '../domain/app_language.dart';

final class UiStrings {
  const UiStrings(this.language);

  final AppLanguage language;

  bool get isRussian => language == AppLanguage.russian;

  String choose(String german, String russian) => isRussian ? russian : german;

  String get today => choose('Heute', 'Сегодня');
  String get learn => choose('Lernen', 'Повторение');
  String get material => choose('Wörter', 'Слова');
  String get grammar => choose('Grammatik', 'Грамматика');
  String get statistics => choose('Statistik', 'Статистика');
  String get grammarIntro => choose(
        'Lies eine bereits gelernte Regel und markiere sie danach als gelernt.',
        'Откройте уже пройденное правило и отметьте его изученным.',
      );
  String get grammarLearned => choose('Gelernt', 'Изучено');
  String get grammarReady =>
      choose('Bereit zum Aktivieren', 'Можно отметить изученным');
  String get grammarReference => choose('Grundlage', 'Справочный раздел');
  String grammarNeedsVerb(String lemma) => choose(
        'Füge zuerst „$lemma“ als Verb zu Wörter hinzu.',
        'Сначала добавьте «$lemma» в словарь с типом «Глагол».',
      );
  String get markLearned =>
      choose('Als gelernt markieren', 'Отметить изученным');
  String get markNotLearned => choose('Nicht mehr gelernt', 'Снять отметку');
  String get switchLanguage => choose('Sprache wechseln', 'Сменить язык');
  String get dailyPlan => choose('Tagesplan', 'План на сегодня');
  String get remindersTitle => choose('Erinnerungen', 'Напоминания');
  String get remindersEnabled => choose(
        'Aktiv: 13:30, 16:30 und 19:30',
        'Включены: 13:30, 16:30 и 19:30',
      );
  String get remindersDisabled => choose(
        'Aktiviere Erinnerungen für offene Sitzungen.',
        'Включите напоминания о незавершённых занятиях.',
      );
  String get enableReminders => choose('Aktivieren', 'Включить');
  String dailyProgress(int completed, [int total = 5]) => choose(
        '$completed von $total Sitzungen abgeschlossen',
        'Выполнено занятий: $completed из $total',
      );
  String sessionNumber(int number) =>
      choose('Sitzung $number', 'Занятие $number');
  String get extraSession => choose('Zusatzsitzung', 'Дополнительное занятие');
  String get getNewLesson =>
      choose('Neue Sitzung starten', 'Получить новый урок');
  String sessionAnswers(int answered, int target) =>
      choose('$answered von $target Antworten', '$answered из $target ответов');
  String get planned => choose('Geplant', 'Запланировано');
  String get inProgress => choose('In Bearbeitung', 'В процессе');
  String get completed => choose('Abgeschlossen', 'Завершено');
  String get start => choose('Starten', 'Начать');
  String get continueSession => choose('Fortsetzen', 'Продолжить');
  String get repeatSession => choose('Wiederholen', 'Повторить');
  String get chooseSession => choose(
        'Wähle eine Sitzung aus deinem Tagesplan.',
        'Выберите занятие из плана на сегодня.',
      );
  String entries(int count) => choose(
        '$count Wörter',
        '$count слов',
      );
  String get add => choose('Hinzufügen', 'Добавить');
  String get importJson => choose('JSON importieren', 'Импорт JSON');
  String get exportJson => choose('JSON exportieren', 'Экспорт JSON');
  String get importPreviewTitle => choose('Import prüfen', 'Проверка импорта');
  String importPreview(int additions, int skipped) => choose(
        'Neue Wörter: $additions\nÜbersprungen: $skipped',
        'Новых слов: $additions\nПропущено: $skipped',
      );
  String get importAction => choose('Importieren', 'Импортировать');
  String importComplete(int additions, int skipped) => choose(
        '$additions Wörter importiert, $skipped übersprungen.',
        'Импортировано: $additions, пропущено: $skipped.',
      );
  String importFailed(String error) => choose(
        'Import fehlgeschlagen: $error',
        'Ошибка импорта: $error',
      );
  String exportComplete(int count) => choose(
        '$count Wörter exportiert.',
        'Экспортировано слов: $count.',
      );
  String exportFailed(String error) => choose(
        'Export fehlgeschlagen: $error',
        'Ошибка экспорта: $error',
      );
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
  String get verb => choose('Verb', 'Глагол');
  String get article => choose('Artikel', 'Артикль');
  String get germanWord => choose('Deutsches Wort', 'Немецкое слово');
  String get infinitive => choose('Infinitiv', 'Инфинитив');
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
  String progress(int answered, int target) => choose(
        'Antwort ${answered + 1} von $target',
        'Ответ ${answered + 1} из $target',
      );
  String get sessionComplete => choose(
        'Sitzung abgeschlossen',
        'Повторение завершено',
      );
  String get sessionCompleteHint => choose(
        'Die Sitzung ist geschafft.',
        'Занятие завершено.',
      );
  String get grammarSessionUnavailable => choose(
        'Für diese Grammatik-Sitzung fehlen gelernte Themen oder passende Verben.',
        'Для занятия не хватает изученных тем или подходящих глаголов.',
      );
  String get grammarEnding => choose('Fehlender Teil', 'Пропущенная часть');
  String get again => choose('Noch einmal', 'Повторить ещё раз');
  String get statsEmpty => choose(
        'Noch keine Wiederholungen. Starte eine Sitzung unter „Heute“.',
        'Повторений пока нет. Начните занятие в разделе «Сегодня».',
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
  String get syncTitle => choose('Synchronisierung', 'Синхронизация');
  String get nickname => choose('Nickname', 'Ник');
  String get nicknameHint => choose(
        '3–24 Zeichen: a–z, 0–9, _ oder -',
        '3–24 символа: a–z, 0–9, _ или -',
      );
  String get nicknameError => choose(
        'Bitte einen gültigen Nickname eingeben.',
        'Введите допустимый ник.',
      );
  String get syncRiskHint => choose(
        'Wer deinen Nickname kennt, hat vollen Zugriff auf dieses Profil.',
        'Любой, кто знает ник, получает полный доступ к этому профилю.',
      );
  String get connectSync => choose('Verbinden', 'Подключить');
  String get changeNickname => choose('Nickname wechseln', 'Сменить ник');
  String get disconnectSync => choose('Trennen', 'Отключить');
  String get syncNow => choose('Jetzt synchronisieren', 'Синхронизировать');
  String get close => choose('Schließen', 'Закрыть');
  String get syncDisconnected =>
      choose('Nicht verbunden', 'Синхронизация не подключена');
  String get syncReady => choose('Bereit', 'Готово к синхронизации');
  String get syncing => choose('Synchronisierung…', 'Синхронизация…');
  String get syncComplete => choose('Synchronisiert', 'Синхронизировано');
  String get syncError => choose(
        'Keine Verbindung. Lokale Daten sind sicher.',
        'Нет соединения. Локальные данные сохранены.',
      );
  String get syncUnavailable => choose(
        'Supabase ist in diesem Build nicht konfiguriert.',
        'Supabase не настроен в этой сборке.',
      );
  String lastSync(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final formatted = '$day.$month.${local.year}, $hour:$minute';
    return choose(
      'Letzte Synchronisierung: $formatted',
      'Последняя синхронизация: $formatted',
    );
  }
}
