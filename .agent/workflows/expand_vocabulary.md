---
description: Process new vocabulary from inbox and expand with related phrases
---

1. Read `assets/data/inbox.md` to see what new words the user has added.
2. Run `python3 scripts/ingest_inbox.py` to move these base items to `assets/data/source.md`.
3. View the `assets/data/source.md` file to see the newly added items (they will be at the bottom under "Inbox Ingested Items" or similar).
4. For each new item, generate 5-10 related phrases or questions that use that vocabulary word or concept.
   - Ensure the difficulty matches the user's level (A1/A2).
   - Create variations (questions, statements, negatives).
5. Append these new related items to `assets/data/source.md`. 
   - You can use a python script to append or just `append_to_file` if available, or read/write.
   - Mark them as "Expanded" or "Related" in the Notes column.
6. Run `python3 generate_quiz.py` to regenerate the `questions.json` file ensuring everything is valid.
7. Notify the user that the expansion is complete.
