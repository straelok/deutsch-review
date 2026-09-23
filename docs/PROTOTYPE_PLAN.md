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
3. Intensive scheduler and deferred prototype behavior: isolated FSRS
   integration, automatic outcomes without manual rating, unlimited new words,
   problem-word priority and error statistics. Other sections remain available
   regardless of the review queue.
4. Review session: typed German answer and concrete correction.
5. Reminders: configurable local notifications and snooze, without blocking
   other features.
6. Prototype hardening: JSON backup, Android/Windows verification and focused
   tests.
