const currentSchemaVersion = 4;

const migrationFrom0To1 = '''
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
''';

const migrationFrom1To2 = '''
CREATE TABLE app_settings (
  key TEXT PRIMARY KEY NOT NULL,
  value TEXT NOT NULL
);

CREATE TABLE practice_attempts (
  id TEXT PRIMARY KEY NOT NULL,
  item_id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  answer_text TEXT NOT NULL,
  correct INTEGER NOT NULL CHECK (correct IN (0, 1)),
  attempted_at TEXT NOT NULL,
  FOREIGN KEY (item_id) REFERENCES learning_items (id) ON DELETE RESTRICT
);

CREATE INDEX practice_attempts_item_time_idx
  ON practice_attempts (item_id, attempted_at);

CREATE INDEX practice_attempts_session_time_idx
  ON practice_attempts (session_id, attempted_at);

CREATE TRIGGER practice_attempts_prevent_update
BEFORE UPDATE ON practice_attempts
BEGIN
  SELECT RAISE(ABORT, 'practice attempts are immutable');
END;

CREATE TRIGGER practice_attempts_prevent_delete
BEFORE DELETE ON practice_attempts
BEGIN
  SELECT RAISE(ABORT, 'practice attempts are immutable');
END;
''';

const migrationFrom2To3 = '''
DROP TABLE review_events;
DROP TABLE review_schedules;

CREATE TABLE daily_sessions (
  id TEXT PRIMARY KEY NOT NULL,
  local_date TEXT NOT NULL,
  slot INTEGER CHECK (slot IS NULL OR slot BETWEEN 1 AND 5),
  status TEXT NOT NULL CHECK (status IN ('planned', 'in_progress', 'completed')),
  target_answers INTEGER NOT NULL CHECK (target_answers > 0),
  answered_count INTEGER NOT NULL DEFAULT 0
    CHECK (answered_count >= 0 AND answered_count <= target_answers),
  queue_json TEXT NOT NULL CHECK (
    json_valid(queue_json) AND json_type(queue_json) = 'array'
  ),
  last_item_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  completed_at TEXT,
  CHECK (
    (status = 'completed' AND answered_count = target_answers AND completed_at IS NOT NULL)
    OR
    (status != 'completed' AND answered_count < target_answers AND completed_at IS NULL)
  ),
  FOREIGN KEY (last_item_id) REFERENCES learning_items (id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX daily_sessions_required_slot_idx
  ON daily_sessions (local_date, slot)
  WHERE slot IS NOT NULL;

CREATE INDEX daily_sessions_date_status_idx
  ON daily_sessions (local_date, status);
''';

const migrationFrom3To4 = '''
CREATE TABLE grammar_topic_progress (
  topic_id TEXT PRIMARY KEY NOT NULL,
  learned INTEGER NOT NULL CHECK (learned IN (0, 1)),
  updated_at TEXT NOT NULL
);

CREATE TABLE grammar_attempts (
  id TEXT PRIMARY KEY NOT NULL,
  topic_id TEXT NOT NULL,
  exercise_id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  answer_text TEXT NOT NULL,
  correct INTEGER NOT NULL CHECK (correct IN (0, 1)),
  attempted_at TEXT NOT NULL
);

CREATE INDEX grammar_attempts_topic_time_idx
  ON grammar_attempts (topic_id, attempted_at);
CREATE INDEX grammar_attempts_session_time_idx
  ON grammar_attempts (session_id, attempted_at);

CREATE TRIGGER grammar_attempts_prevent_update
BEFORE UPDATE ON grammar_attempts
BEGIN
  SELECT RAISE(ABORT, 'grammar attempts are immutable');
END;

CREATE TRIGGER grammar_attempts_prevent_delete
BEFORE DELETE ON grammar_attempts
BEGIN
  SELECT RAISE(ABORT, 'grammar attempts are immutable');
END;

ALTER TABLE daily_sessions RENAME TO daily_sessions_v3;

CREATE TABLE daily_sessions (
  id TEXT PRIMARY KEY NOT NULL,
  local_date TEXT NOT NULL,
  slot INTEGER CHECK (slot IS NULL OR slot BETWEEN 1 AND 7),
  kind TEXT NOT NULL DEFAULT 'vocabulary'
    CHECK (kind IN ('vocabulary', 'grammar')),
  status TEXT NOT NULL CHECK (status IN ('planned', 'in_progress', 'completed')),
  target_answers INTEGER NOT NULL CHECK (target_answers > 0),
  answered_count INTEGER NOT NULL DEFAULT 0
    CHECK (answered_count >= 0 AND answered_count <= target_answers),
  queue_json TEXT NOT NULL CHECK (
    json_valid(queue_json) AND json_type(queue_json) = 'array'
  ),
  last_item_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  completed_at TEXT,
  CHECK (
    (status = 'completed' AND answered_count = target_answers AND completed_at IS NOT NULL)
    OR
    (status != 'completed' AND answered_count < target_answers AND completed_at IS NULL)
  )
);

INSERT INTO daily_sessions (
  id, local_date, slot, kind, status, target_answers, answered_count,
  queue_json, last_item_id, created_at, updated_at, completed_at
)
SELECT
  id, local_date, slot, 'vocabulary', status, target_answers, answered_count,
  queue_json, last_item_id, created_at, updated_at, completed_at
FROM daily_sessions_v3;

DROP TABLE daily_sessions_v3;

CREATE UNIQUE INDEX daily_sessions_required_slot_idx
  ON daily_sessions (local_date, slot)
  WHERE slot IS NOT NULL;
CREATE INDEX daily_sessions_date_status_idx
  ON daily_sessions (local_date, status);
''';
