# Worttrieb

Персональное offline-first приложение для повторения уже изученного немецкого материала на Android и Windows.

## Состояние

Реализовано offline-first приложение с двуязычным интерфейсом, словарём,
настраиваемыми занятиями, грамматикой, статистикой, уведомлениями и импортом /
экспортом JSON. Данные хранятся в SQLite и при желании синхронизируются через
Supabase по нику. Учебный каталог обновляется отдельно через Supabase Storage.
Актуальное состояние и следующий шаг находятся в `PROJECT_STATE.md`, этапы — в
`ROADMAP.md`.

## Документы

- `AGENTS.md` — короткие постоянные инструкции для Codex.
- `PRODUCT_SPEC.md` — требования к продукту.
- `CONTENT_FORMAT.md` — форматы слов и учебного каталога.
- `docs/DATABASE_SCHEMA.md` — доменные таблицы и стратегия миграций SQLite.
- `docs/PROTOTYPE_PLAN.md` — согласованные ограничения и короткие итерации
  первого прототипа.
- `docs/MANUAL_TEST_STAGE_2_1.md` — сценарий первого ручного тестирования.
- `docs/MANUAL_TEST_STAGE_4.md` — проверка JSON-импорта и экспорта слов.
- `docs/MANUAL_TEST_STAGE_5_1.md` — проверка первого грамматического сценария.
- `docs/MANUAL_TEST_STAGE_5_2.md` — проверка базовой грамматики и смешанных
  упражнений.
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

Текущее проверенное состояние описано в `PROJECT_STATE.md`.

## Тестовая Windows-сборка

Полный комплект создаётся одной командой:

```powershell
powershell -ExecutionPolicy Bypass -File tool/package_windows.ps1
```

Скрипт собирает приложение, находит полный результат Flutter, проверяет DLL и
ресурсы и создаёт `dist/Worttrieb-Windows-Debug.zip`. Архив не хранится в Git.
Распакуйте его целиком и запускайте `deutsch_review.exe` внутри папки
`Worttrieb-Windows-Debug`. Файл из `build/windows/x64/runner/Debug` может не
содержать рядом нужные библиотеки и не предназначен для передачи пользователю.
