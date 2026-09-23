# Database schema

Статус: проект схемы версии 1. Реализация подключения SQLite и миграций будет
выполнена отдельным шагом.

## Принципы

- SQLite является локальным источником истины.
- Все идентификаторы — UUID в текстовом представлении.
- Даты хранятся как UTC RFC 3339 (`TEXT`).
- Логические значения хранятся как `INTEGER` со значениями `0` и `1`.
- Различающееся содержимое учебных элементов и состояние планировщика хранятся
  как валидный JSON. Поля для фильтрации и сортировки вынесены в столбцы.
- Учебный элемент доступен для повторения только при `learned = 1` и
  `deleted_at IS NULL`.
- Удаление учебных элементов мягкое. События повторения неизменяемые.

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

Отдельная строка расписания создаётся после первого планирования элемента.
Отсутствие строки означает, что элемент новый. `due_at` вынесен из JSON, чтобы
очередь повторений не зависела от конкретной реализации FSRS.

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

## Границы текущего шага

Схема не включает пользователей, облачные таблицы, статистические агрегаты и
настройки интерфейса. Они добавляются только при появлении соответствующего
сценария. Импорт сначала проверяет пакет целиком, а затем записывает элементы в
`learning_items` одной транзакцией; реализация импорта относится к более
позднему этапу.
