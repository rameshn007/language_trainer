---
name: expand-vocabulary
description: Vocabulary data pipeline — ingest assets/data/inbox.md into assets/data/source.md, expand with related phrases, regenerate questions.json. Use when new words or class notes are added, or when source.md / questions.json / vocabulary.json need regeneration.
---

# Expand vocabulary

1. Read `assets/data/inbox.md` for newly added words.
2. `python3 scripts/ingest_inbox.py` moves base items into `assets/data/source.md`.
3. Inspect the tail of `assets/data/source.md` (new items land under an "Inbox Ingested Items" style heading).
4. For each new item write 5–10 related phrases/questions using that word or concept.
   - Difficulty A1/A2; mix questions, statements, and negatives.
   - Append to `assets/data/source.md`, marking the Notes column `Expanded` or `Related`.
5. `python3 generate_quiz.py` regenerates `assets/data/questions.json` and validates it.
6. Report what was added; then run `flutter test` because item counts feed quiz and Listen & Repeat deck tests.

Notes:
- `scripts/sanitize_source.py` normalizes malformed rows; `scripts/check_duplicates.py` finds repeats.
- Loaded at app launch: `assets/vocabulary.json`, `assets/Combined_Portuguese_Class_Notes.md`, `assets/data/*`. User review history survives reloads — never regenerate item ids that already exist in a user's Hive box.
