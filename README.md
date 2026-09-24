# Worttrieb

Персональное offline-first приложение для повторения уже изученного немецкого материала на Android и Windows.

## Состояние

Создано offline-first приложение для Android и Windows с немецким и русским
UI, словарём, пятью словарными занятиями и первыми грамматическими темами.
Изученные темы регулярного Präsens, `sein` и `haben` добавляют занятия 6 и 7.
Материал, прогресс и статистика сохраняются в SQLite и синхронизируются через
Supabase по нику. Текущие решения и следующий шаг находятся в
`PROJECT_STATE.md`; порядок этапов — в `ROADMAP.md`.

## Документы

- `AGENTS.md` — короткие постоянные инструкции для Codex.
- `PRODUCT_SPEC.md` — требования к продукту.
- `CONTENT_FORMAT.md` — минимальный JSON-формат импорта и экспорта слов.
- `docs/DATABASE_SCHEMA.md` — доменные таблицы и стратегия миграций SQLite.
- `docs/PROTOTYPE_PLAN.md` — согласованные ограничения и короткие итерации
  первого прототипа.
- `docs/MANUAL_TEST_STAGE_2_1.md` — сценарий первого ручного тестирования.
- `docs/MANUAL_TEST_STAGE_4.md` — проверка JSON-импорта и экспорта слов.
- `docs/MANUAL_TEST_STAGE_5_1.md` — проверка первого грамматического сценария.
- `PROJECT_STATE.md` — текущее состояние и следующий шаг.
- `ROADMAP.md` — последовательность этапов.

## Запуск после установки Flutter

```powershell
flutter pub get
flutter run -d windows
```

Для Android сначала запустите эмулятор или подключите устройство, затем
выполните `flutter run`. Проверки проекта:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Требуемые инструменты и их текущее состояние описаны в `PROJECT_STATE.md`.

## Тестовая Windows-сборка

Архив `dist/Worttrieb-Windows-Debug.zip` создаётся локально и не хранится в
Git. Распакуйте его целиком и запускайте `deutsch_review.exe` внутри
распакованной папки. Один `.exe` без соседних DLL и папки `data` не запускается.
