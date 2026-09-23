const currentSchemaVersion = 1;

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
