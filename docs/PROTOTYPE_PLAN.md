# Minimal prototype plan

## Confirmed requirements

- New words are not limited by the application. Their number follows the
  material studied in the DAA course.
- The user does not rate answers. Only the last ten correct/incorrect results
  determine a word's simple selection weight.
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
3. Five daily word sessions, Android reminders and nickname-only Supabase sync.
   Each session contains 20 answers and problematic words appear more often
   based on the last ten results. Other sections remain available.
4. Expanded review: additional material types and more detailed linguistic
   correction beyond the word and noun prototype.
5. Prototype hardening: JSON backup, Android/Windows verification and focused
   tests.

## Stage 3 implementation plan

1. Complete: add five local daily sessions with 20 answers each. Persist an unfinished
   queue and restore it exactly after restart.
2. Select words by the last ten results. Unseen words have 0% success; use
   weight `1 + round((1 - successRate) * 9)` and avoid immediate repetition.
3. Update `Heute`, `Lernen` and `Statistik` with the daily plan and progress.
4. Add Android reminders at 13:30, 16:30 and 19:30 device time while required
   sessions remain unfinished.
5. Add offline-first Supabase sync for words, attempts and session state. A
   normalized nickname is the only credential; knowing it grants full access,
   and that risk is explicitly accepted.
6. Test migration, priority, continuation, offline recovery, conflicts and
   Android/Windows exchange. Finish with both builds and a manual checklist.

Stage 3 excludes new exercise types, advanced linguistic correction and
reliable background notifications on unpackaged Windows builds.

## Stage 2.1 acceptance criteria

- Every feature in this stage must be reachable and usable through the Android
  and Windows UI; backend-only completion is not accepted.
- The language switch changes all visible application labels immediately and
  survives restart; learning content is not translated or modified.
- Search matches German text and Russian meaning. Word cards show the
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
