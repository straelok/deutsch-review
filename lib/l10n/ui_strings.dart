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
  String get todayStatistics => choose('Heute', 'За сегодня');
  String get grammarIntro => choose(
        'Lies eine bereits gelernte Regel und markiere sie danach als gelernt.',
        'Откройте уже пройденное правило и отметьте его изученным.',
      );
  String get grammarLearned => choose('Gelernt', 'Изучено');
  String get allLessons => choose('Alle', 'Все');
  String get notLearnedLessons => choose('Nicht gelernt', 'Не изученные');
  String get learnedLessons => choose('Gelernt', 'Изученные');
  String get alphabetCategory => choose('Alphabet', 'Алфавит');
  String get numbersCategory => choose('Zahlen', 'Цифры');
  String get grammarCategory => choose('Grammatik', 'Грамматика');
  String get wordsCategory => choose('Wortschatz', 'Слова');
  String get toGermanCategory => choose(
        'Russisch → Deutsch',
        'С русского на немецкий',
      );
  String get toRussianCategory => choose(
        'Deutsch → Russisch',
        'С немецкого на русский',
      );
  String get importantWordsCategory =>
      choose('Wichtige Wörter', 'Важные слова');
  String get importantToGermanCategory => choose(
        'Wichtig: Russisch → Deutsch',
        'Важные: с русского на немецкий',
      );
  String get importantToRussianCategory => choose(
        'Wichtig: Deutsch → Russisch',
        'Важные: с немецкого на русский',
      );
  String get noImportantWordsHint => choose(
        'Markiere zuerst wichtige Wörter in deiner Wörterliste.',
        'Сначала отметьте важные слова в словаре.',
      );
  String get noLearnedLessons => choose(
        'Noch keine Lektionen als gelernt markiert.',
        'Пока нет уроков, отмеченных как изученные.',
      );
  String get noLessonsForFilter => choose(
        'Keine Lektionen in diesem Bereich.',
        'В этом разделе нет уроков.',
      );
  String get grammarReady =>
      choose('Bereit zum Aktivieren', 'Можно отметить изученным');
  String get grammarReference => choose('Grundlage', 'Справочный раздел');
  String grammarNeedsMaterial(String description) => choose(
        'Füge zuerst passendes Material hinzu: $description.',
        'Сначала добавьте подходящий материал: $description.',
      );
  String grammarAddMaterialQuestion(String description) => choose(
        'Für diese Lektion brauchst du mindestens ein passendes Wort, zum Beispiel: $description. Jetzt hinzufügen?',
        'Для завершения урока нужно хотя бы одно подходящее слово, например: $description. Добавить его сейчас?',
      );
  String get addAndLearn =>
      choose('Hinzufügen und lernen', 'Добавить и отметить');
  String get practiceThisTheory => choose(
        'Diese Theorie üben',
        'Пройти урок по этой теории',
      );
  String get materialAdded => choose(
        'Das Wort wurde ohne Duplikate hinzugefügt.',
        'Слово добавлено без создания дублей.',
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
  String vocabularyToGermanLesson(int number) => choose(
        'Wörter auf Deutsch · Übung $number',
        'Практика слов на немецком №$number',
      );
  String vocabularyToRussianLesson(int number) => choose(
        'Wörter auf Russisch · Übung $number',
        'Практика слов на русском №$number',
      );
  String importantVocabularyToGermanLesson(int number) => choose(
        'Wichtige Wörter auf Deutsch · Übung $number',
        'Важные слова на немецком №$number',
      );
  String importantVocabularyToRussianLesson(int number) => choose(
        'Wichtige Wörter auf Russisch · Übung $number',
        'Важные слова на русском №$number',
      );
  String grammarLesson(int number) => choose(
        'Gemischte Grammatikübung $number',
        'Смешанная практика грамматики №$number',
      );
  String topicGrammarLesson(String title) => choose(
        'Übung: $title',
        'Урок по теме: $title',
      );
  String numbersLesson(int number) => choose(
        'Zahlentraining $number',
        'Практика цифр №$number',
      );
  String grammarTopics(String topics) => choose(
        'Themen: $topics',
        'Темы: $topics',
      );
  String grammarTopicsPlanned(String topics) => choose(
        'Gemischte Aufgaben aus: $topics',
        'Смешанные задания из тем: $topics',
      );
  String get extraSession => choose('Zusatzsitzung', 'Дополнительное занятие');
  String get getNewLesson =>
      choose('Neue Sitzung starten', 'Получить новый урок');
  String get addLesson => choose('Weitere Lektion', 'Добавить урок');
  String get nextLesson => choose('Nächste Lektion', 'Следующий урок');
  String get continueLesson => choose('Lektion fortsetzen', 'Продолжить урок');
  String get expand => choose('Aufklappen', 'Развернуть');
  String get collapse => choose('Einklappen', 'Свернуть');
  String categoryProgress(int completed, int total) => '$completed/$total';
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
  String get markImportant =>
      choose('Als wichtig markieren', 'Отметить важным');
  String get removeImportant =>
      choose('Nicht mehr wichtig', 'Снять отметку «Важное»');
  String get clearImportantWords =>
      choose('Alle Markierungen entfernen', 'Убрать все важные');
  String get clearImportantWordsTitle => choose(
        'Alle wichtigen Markierungen entfernen?',
        'Убрать все отметки «Важное»?',
      );
  String clearImportantWordsMessage(int count) => choose(
        'Die Markierung wird bei $count Wörtern entfernt. Begonnene Lektionen bleiben erhalten.',
        'Отметка будет снята с $count слов. Начатые уроки сохранятся.',
      );
  String get importantWordsCleared => choose(
        'Alle wichtigen Markierungen wurden entfernt.',
        'Все отметки «Важное» сняты.',
      );
  String get importPreviewTitle => choose('Import prüfen', 'Проверка импорта');
  String importPreview(int additions, int updates, int skipped) => choose(
        'Neue Wörter: $additions\nAktualisiert: $updates\nUnverändert oder übersprungen: $skipped',
        'Новых слов: $additions\nОбновлено: $updates\nБез изменений или пропущено: $skipped',
      );
  String get importAction => choose('Importieren', 'Импортировать');
  String importComplete(int additions, int updates, int skipped) => choose(
        'Neu: $additions, aktualisiert: $updates, unverändert: $skipped.',
        'Добавлено: $additions, обновлено: $updates, без изменений: $skipped.',
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
  String get meaningAlternativesHint => choose(
        'Mehrere russische Übersetzungen mit ; trennen',
        'Несколько русских переводов разделяйте знаком ;',
      );
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
  String get singleGermanEntry => choose(
        'Bitte nur eine deutsche Variante eingeben.',
        'Введите только один немецкий вариант.',
      );
  String get invalidRussianAlternatives => choose(
        'Zwischen zwei Übersetzungen muss Text stehen.',
        'Между разделителями должны быть заполненные переводы.',
      );
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
  String get russianAnswer => choose(
        'Russische Übersetzung',
        'Перевод на русский',
      );
  String get germanNumberAnswer => choose(
        'Zahl auf Deutsch',
        'Число по-немецки',
      );
  String get digitsAnswer => choose('Ziffer', 'Цифра');
  String get check => choose('Prüfen', 'Проверить');
  String get doNotKnow => choose('Ich weiß es nicht', 'Не знаю');
  String get needHelp => choose('Ich brauche Hilfe', 'Мне нужна помощь');
  String get usageExamples => choose('Beispiele', 'Примеры');
  String get correct => choose('Richtig', 'Правильно');
  String get incorrect => choose('Noch nicht richtig', 'Пока неверно');
  String correctAnswer(String answer) => choose(
        'Richtige Antwort: $answer',
        'Правильный ответ: $answer',
      );
  String get acceptMyTranslation => choose(
        'Meine Antwort ist auch richtig',
        'Мой вариант тоже верный',
      );
  String get translationAdded => choose(
        'Die Übersetzung wurde ergänzt.',
        'Вариант добавлен в перевод.',
      );
  String get translationAddFailed => choose(
        'Die Übersetzung konnte nicht ergänzt werden.',
        'Не удалось добавить вариант перевода.',
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
  String get chooseAnswer => choose('Wähle eine Antwort', 'Выберите ответ');
  String get fillMissingPart => choose(
        'Ergänze den fehlenden Teil.',
        'Введите пропущенную часть.',
      );
  String get buildSentence => choose('Baue den Satz', 'Соберите предложение');
  String get undoLastWord => choose('Letztes Wort zurück', 'Убрать последнее');
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
  String practiceStat(String label, int correct, int attempts, int percent) =>
      choose(
        '$label: $correct/$attempts · $percent %',
        '$label: $correct/$attempts · $percent %',
      );
  String get recentStatistics => choose('Letzte 10', 'Последние 10');
  String get allTimeStatistics => choose('Gesamt', 'За всё время');
  String noPracticeStat(String label) => choose('$label: –', '$label: —');
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
