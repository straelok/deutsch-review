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
2.1. First hands-on prototype: persistent German/Russian interface switch,
   search, safe delete with undo, duplicate warning, basic typed review without
   manual rating, attempt history and simple problem-word statistics. This
   stage does not schedule reviews by time.
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

## Stage 2.1 acceptance criteria

- The language switch changes all visible application labels immediately and
  survives restart; learning content is not translated or modified.
- Search matches German text, Russian meaning, topic, level and lesson.
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
