# Minimal prototype plan

## Confirmed requirements

- New words are not limited by the application. Their number follows the
  material studied in the DAA course.
- The user does not manually rate an answer. Correctness, hints and repeated
  errors provide the scheduler signal automatically.
- Problematic words receive higher priority and visible error statistics.
- Other application sections are never blocked by an unfinished review queue.
- After the dictionary interface stage, a runnable Windows build is delivered
  for hands-on testing before work continues.

## Iterations

1. Local dictionary core: SQLite, migration, repository and persistence tests.
2. Dictionary interface: list, add and edit words and nouns; runnable Windows
   build for user testing.
2.1. First hands-on prototype (complete): persistent German/Russian interface switch,
   search, safe delete with undo, duplicate warning, basic typed review without
   manual rating, optional notes and usage examples, attempt history and simple
   problem-word statistics. This stage does not schedule reviews by time.
3. Intensive scheduler and deferred prototype behavior: isolated FSRS
   integration, unlimited new words and problem-word priority. Automatic
   outcomes and the attempt history from stage 2.1 become FSRS signals. Other
   sections remain available regardless of the review queue.
4. Expanded review: additional material types and more detailed linguistic
   correction beyond the word and noun prototype.
5. Reminders: configurable local notifications and snooze, without blocking
   other features.
6. Prototype hardening: JSON backup, Android/Windows verification and focused
   tests.

## Stage 3 implementation plan

1. Verify and pin the pure-Dart `fsrs` package, then place it behind the
   scheduler abstraction so it can be replaced without changing the UI or
   repositories.
2. Migrate existing active items to scheduler state without resetting words or
   stage 2.1 attempt history. Keep a backup before the schema migration.
3. Map answers automatically: wrong to `Again`, correct after an earlier error
   in the same session to `Hard`, and first-attempt correct to `Good`. Do not
   expose FSRS rating buttons and do not infer `Easy` in the first version.
4. Use desired retention 0.95. Queue due cards first, then every unscheduled new
   card without a daily limit. Use error history as a tie-breaker so problematic
   words appear earlier.
5. Persist the immutable review event and updated schedule atomically. Restore
   the same effective queue after an application restart.
6. Update `Heute`, `Lernen` and `Statistik` together with the scheduler: show
   due/new/problem counts, session progress and the nearest next review while
   keeping all navigation available.
7. Test with a controlled clock: first review, correct and wrong paths,
   same-session retry, unlimited new items, migration, persistence and restart.
   Finish with Android and Windows builds and a manual test checklist.

Stage 3 explicitly excludes notifications, synchronization, new exercise types
and advanced linguistic correction.

## Stage 2.1 acceptance criteria

- Every feature in this stage must be reachable and usable through the Android
  and Windows UI; backend-only completion is not accepted.
- The language switch changes all visible application labels immediately and
  survives restart; learning content is not translated or modified.
- Search matches German text and Russian meaning. Material cards show the
  original addition date, which editing does not change. Optional notes and
  examples are searchable and shown after an answer, never as a pre-answer hint.
- Deletion asks for confirmation, uses the existing soft-delete mechanism and
  offers undo. Deleted material no longer appears in review.
- Creating a likely duplicate produces a warning before data is saved.
- A review session uses every active item marked as learned, with no artificial
  daily limit. The Russian meaning is shown and the German answer is typed.
- Answer checking ignores surrounding whitespace but keeps meaningful German
  differences such as article, capitalization and umlauts. Wrong items return
  later in the same session, never immediately next.
- No rating buttons are shown. Attempts, correct answers, errors and accuracy
  persist locally and feed a simple problem-word list.
- Navigation remains available during a session. The Windows archive starts
  after full extraction, and language, material and statistics survive restart.
