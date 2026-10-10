---
name: expand-vocabulary
description: Vocabulary data pipeline — ingest assets/data/inbox.md into assets/data/source.md, expand with related phrases, regenerate questions.json. Use when new words or class notes are added, or when source.md / questions.json / vocabulary.json need regeneration.
---

# Expand vocabulary

Run everything from the repo root: the scripts use relative paths (`assets/data/source.md`, `extracted_words.json`), so another working directory writes to the wrong place or fails to find its input.

1. Read `assets/data/inbox.md` for newly added words. Missing or empty → `ingest_inbox.py` prints "No inbox file found." / "No new items in inbox." and stops; there is nothing to ingest.
2. Copy or commit `assets/data/inbox.md` first. `scripts/ingest_inbox.py` **clears the inbox** after moving items, so an uncommitted inbox is unrecoverable.
3. `python3 scripts/ingest_inbox.py` moves base items into `assets/data/source.md`.
4. Inspect the tail of `assets/data/source.md` (new items land under an "Inbox Ingested Items" style heading).
5. For each new item write 5–10 related phrases/questions using that word or concept.
   - Difficulty A1/A2; mix questions, statements, and negatives.
   - Append to `assets/data/source.md`, marking the Notes column `Expanded` or `Related`.
6. `python3 generate_quiz.py` — appends to `assets/data/questions.json` and leaves existing questions alone. `--rebuild-all` is the opposite: it wipes the file and re-keys every id.
7. Checks, all read-only: `python3 scripts/check_duplicates.py`, `python3 check_translations.py` (rows missing English), `scripts/sanitize_source.py` only if rows are malformed.
8. `flutter test` before finishing. `test/new_words_and_exercises_test.dart` and `test/quiz_category_loader_test.dart` read the JSON straight off disk (`File(...).readAsStringSync()`), so a data-only edit can fail them: exercise invariants, `verbs.csv` field counts, and "every category in `kQuizCategories` still yields > 0 questions" are pinned there. The Listen & Repeat suites inject fixture `LanguageItem`s and mocked `loadVerbs()` instead of reading `assets/data/`, so a green suite is not proof the deck loads.

## Do not

- Do not run the other `.py` files. `scripts/massive_expansion.py`, `scripts/process_new_words.py`, `scripts/append_new_questions.py`, `scripts/add_a2_topics_exercises.py`, `scripts/add_listen_repeat_phrases.py`, `scripts/ingest_ano_words.py`, `scripts/ingest_classes_6_7.py` and the root `add_content.py` / `append_vocab.py` / `sanitize_data.py` / `process_*.py` are spent one-shots that rewrite live data in place; a second run duplicates or corrupts content (CLAUDE.md lists what each one clobbers).
- Do not re-key item ids that already exist. Ids link `questions.json` → `sourceItem` → a user's Hive mastery history and `seen_questions` box; re-keying silently unlinks progress.
- Do not edit the root `source.md`, `Even_More_words.md`, `new.md`, `new_words_2.md`, `more_words_1.md`, `mon_mar_9_words.md`, `batch_1.md` or `extracted_words.json`. They are spent inputs from earlier imports; the live file is `assets/data/source.md`.
- Do not assume `assets/data/exercises/grammar_rules.json` feeds the grammar quiz — the engine reads `assets/data/grammar_rules.json`. The `exercises/` copy is referenced by nothing.

## Loading notes

Item counts feed the quiz and Listen & Repeat decks, so a data edit changes runtime behaviour without touching code. `assets/data/inbox.md` is bundled into the app (it sits inside a declared asset dir) even though only `ingest_inbox.py` reads it. User review history survives reloads — never regenerate ids that already exist in a user's Hive box.
