# Database schema

Статус: схема версии 3 реализована в `lib/data/database/schema.dart`, открытие и
миграция базы — в `lib/data/database/app_database.dart`.

## Принципы

- SQLite является локальным источником истины.
- Все идентификаторы — UUID в текстовом представлении.
- Даты хранятся как UTC RFC 3339 (`TEXT`).
- Логические значения хранятся как `INTEGER` со значениями `0` и `1`.
- Различающееся содержимое учебных элементов и очередь занятия хранятся как
  валидный JSON. Поля для фильтрации и сортировки вынесены в столбцы.
- Учебный элемент доступен для повторения при `deleted_at IS NULL`.
- Удаление учебных элементов мягкое. Попытки ответа неизменяемые.

## Схема версии 1

```sql
CREATE TABLE learning_items (
  id TEXT PRIMARY KEY NOT NULL,
  type TEXT NOT NULL CHECK (type IN (
    'word',
    'noun',
    'verb',
    'phrase',
    'sentence',
    'grammar_rule',
    'rule_example',
    'fill_gap',
    'word_order',
    'multiple_choice'
  )),
  level TEXT NOT NULL,
  lesson TEXT NOT NULL,
  topic TEXT NOT NULL,
  learned INTEGER NOT NULL CHECK (learned IN (0, 1)),
  source_ref TEXT NOT NULL,
  content_json TEXT NOT NULL CHECK (json_valid(content_json)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  CHECK (deleted_at IS NULL OR deleted_at >= created_at),
  CHECK (updated_at >= created_at)
);

CREATE INDEX learning_items_reviewable_idx
  ON learning_items (learned, deleted_at, level, lesson);

CREATE INDEX learning_items_topic_idx
  ON learning_items (topic)
  WHERE deleted_at IS NULL;

CREATE TABLE review_schedules (
  item_id TEXT PRIMARY KEY NOT NULL,
  due_at TEXT NOT NULL,
  scheduler_name TEXT NOT NULL,
  scheduler_version TEXT NOT NULL,
  scheduler_state_json TEXT NOT NULL
    CHECK (json_valid(scheduler_state_json)),
  updated_at TEXT NOT NULL,
  FOREIGN KEY (item_id) REFERENCES learning_items (id) ON DELETE RESTRICT
);

CREATE INDEX review_schedules_due_idx ON review_schedules (due_at);

CREATE TABLE review_events (
  id TEXT PRIMARY KEY NOT NULL,
  item_id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  rating TEXT NOT NULL CHECK (rating IN ('again', 'hard', 'good', 'easy')),
  reviewed_at TEXT NOT NULL,
  scheduler_name TEXT NOT NULL,
  scheduler_version TEXT NOT NULL,
  state_before_json TEXT NOT NULL CHECK (json_valid(state_before_json)),
  state_after_json TEXT NOT NULL CHECK (json_valid(state_after_json)),
  FOREIGN KEY (item_id) REFERENCES learning_items (id) ON DELETE RESTRICT
);

CREATE INDEX review_events_item_time_idx
  ON review_events (item_id, reviewed_at);

CREATE INDEX review_events_session_idx
  ON review_events (session_id, reviewed_at);

CREATE TRIGGER review_events_prevent_update
BEFORE UPDATE ON review_events
BEGIN
  SELECT RAISE(ABORT, 'review events are immutable');
END;

CREATE TRIGGER review_events_prevent_delete
BEFORE DELETE ON review_events
BEGIN
  SELECT RAISE(ABORT, 'review events are immutable');
END;
```

Таблицы `review_schedules` и `review_events` были частью первоначального
проекта, но не использовались приложением и удаляются миграцией версии 3.

## Стратегия миграций

1. Схема имеет целочисленную версию в `PRAGMA user_version`.
2. Каждая миграция имеет последовательный номер и выполняется только вперёд:
   `0 -> 1`, `1 -> 2` и далее. Пропуски версий запрещены.
3. Все операции одной миграции выполняются в транзакции. `user_version`
   обновляется последней операцией перед фиксацией транзакции.
4. Перед изменением существующей пользовательской базы создаётся резервная
   копия. При ошибке исходный файл остаётся основным.
5. Изменения, которые SQLite не поддерживает через `ALTER TABLE`, выполняются
   через новую таблицу: создать, скопировать с явным перечислением столбцов,
   проверить количество строк, заменить старую таблицу, восстановить индексы и
   триггеры.
6. При каждом открытии включаются `PRAGMA foreign_keys = ON` и проверяется
   поддерживаемая версия схемы. База с более новой версией открывается только
   для безопасного сообщения об ошибке, без автоматического сброса.
7. Миграции тестируются как на пустой базе, так и на базе каждой поддерживаемой
   предыдущей версии. После миграции выполняются `PRAGMA foreign_key_check` и
   `PRAGMA integrity_check`.
8. Удаление пользовательских данных и откат через пересоздание базы не являются
   допустимой стратегией миграции.

## Схема версии 2

Миграция `1 -> 2` добавляет:

- `app_settings` — локальные настройки по ключу, сейчас выбранный язык UI;
- `practice_attempts` — неизменяемые попытки базового повторения с введённым
  ответом, автоматическим результатом, сессией и временем;
- индексы попыток по учебному элементу и сессии;
- триггеры, запрещающие изменение и удаление истории попыток.

Статистика вычисляется из `practice_attempts`, без преждевременных агрегатных
таблиц. Перед миграцией файловой базы версии 1 приложение создаёт согласованную
копию рядом с базой через `VACUUM INTO`.

Поля `level`, `lesson`, `topic`, `learned` и `source_ref` сохранены в версии 2
только для совместимости с уже созданными базами. UI их не показывает и не
запрашивает; любой активный элемент доступен для повторения. Удалять их без
отдельной практической необходимости не планируется.

## Схема версии 3

Миграция `2 -> 3` после автоматической резервной копии удаляет неиспользуемые
`review_schedules` и `review_events` и добавляет `daily_sessions`:

- `local_date` — локальный день в формате `YYYY-MM-DD`;
- `slot` — обязательное занятие от 1 до 5 или `NULL` для дополнительного;
- `status` — `planned`, `in_progress` или `completed`;
- `target_answers` и `answered_count` — размер и прогресс занятия;
- `queue_json` — точная сохранённая очередь UUID слов;
- `last_item_id` — последнее показанное слово для защиты от немедленного
  повтора;
- `created_at`, `updated_at`, `completed_at` — UTC-время жизненного цикла.

Частичный уникальный индекс гарантирует не более одного обязательного занятия
для каждой пары `(local_date, slot)`. Ответ добавляется в `practice_attempts`,
а прогресс и очередь обновляются в одной транзакции.

## Локальные настройки синхронизации

Версия локальной схемы остаётся 3. Таблица `app_settings` хранит только
`sync_nickname` и время `sync_last_success`; язык интерфейса остаётся локальным.
Очередь отправки не нужна: при синхронизации строится полный снимок локальных
слов, попыток и занятий, а результат атомарно объединяется обратно в SQLite.

Облачная таблица и атомарная функция объединения описаны отдельно в
`supabase/migrations/202609230001_sync_profiles.sql`. Прямой доступ ролей
`anon` и `authenticated` к этой таблице отозван.

## Границы текущего шага

Локальная схема не включает отдельную таблицу пользователей и статистические
агрегаты.
JSON-импорт слов полностью проверяет пакет, затем записывает новые элементы в
`learning_items` одной транзакцией. Формат не изменяет схему SQLite.

Приоритет вычисляется запросом последних десяти строк `practice_attempts` для
каждого слова; отдельная агрегатная таблица не используется.

## Целевая схема этапа 5 — ещё не реализована

До реализации подэтапа 5.1 рабочей остаётся схема версии 3. Следующая миграция
должна после автоматической резервной копии добавить минимальные структуры для:

- стабильных идентификаторов встроенных грамматических тем;
- локальной и синхронизируемой отметки изученности темы;
- неизменяемых попыток грамматических ответов, включая ID темы, ID задания,
  введённый ответ, правильность и время;
- типа занятия (`vocabulary` или `grammar`) и сохранённого снимка очереди,
  достаточного для точного продолжения после обновления банка заданий;
- занятий 6 и 7 по 10 заданий при наличии доступной изученной темы.

Встроенные объяснения и банк упражнений не дублируются в SQLite. База хранит их
стабильные идентификаторы, пользовательский прогресс и снимок уже начатого
занятия. Точная версия схемы и SQL фиксируются только вместе с реализацией и
миграционными тестами; удалять или переопределять существующие попытки нельзя.
