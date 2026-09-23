# Deutsch Review

Персональное offline-first приложение для повторения уже изученного немецкого материала на Android и Windows.

## Состояние

Создан локальный словарь для Android и Windows с адаптивной навигацией,
добавлением и редактированием слов и существительных. Материал сохраняется в
SQLite между запусками. Текущие решения и следующий шаг находятся в
`PROJECT_STATE.md`; порядок этапов — в `ROADMAP.md`.

## Документы

- `AGENTS.md` — короткие постоянные инструкции для Codex.
- `PRODUCT_SPEC.md` — требования к продукту.
- `CONTENT_FORMAT.md` — версия и структура импортируемого материала.
- `docs/DATABASE_SCHEMA.md` — доменные таблицы и стратегия миграций SQLite.
- `docs/PROTOTYPE_PLAN.md` — согласованные ограничения и короткие итерации
  первого прототипа.
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

Архив `dist/DeutschReview-Windows-Debug.zip` создаётся локально и не хранится в
Git. Распакуйте его целиком и запускайте `deutsch_review.exe` внутри
распакованной папки. Один `.exe` без соседних DLL и папки `data` не запускается.
