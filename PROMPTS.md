# Language Quiz Data Generator Prompt

**Historical prompt, kept for provenance.** `generate_quiz.py` (repo root) now does this job deterministically: it reads `assets/data/source.md` and appends to `assets/data/questions.json`. Prefer the script; use this prompt only when you need something it cannot generate. Whatever produces the JSON, these are the live loading rules (`lib/services/question_loader_service.dart`):

- Key aliases are both accepted: `question`/`questionText`, `answer`/`correctAnswer`, `cat`/`category`.
- `_parseType` (`lib/services/question_loader_service.dart`) resolves exactly four strings — `cloze`, `trueFalse`, `jumble`, `reorderAndConjugate`. Everything else becomes `multipleChoice`: a literal `"multipleChoice"`, typos, and the three engine-only types included. Those three (`vocabularyMatch`, `interrogativeMatch`, `prepositionFill`) do run in the app — `quiz_engine_service.dart` builds them at runtime from `interrogatives.json`, `prepositions.json` and the vocabulary pool — they just cannot be requested from a questions JSON. Adding a real type means editing `_parseType`, `QuestionType` in `lib/models/question.dart`, and the `seen_questions` registration.
- A string `sourceItem` is matched against the deck (exact, then contains). No match still loads, but as `legacy_<hash>` with empty English — no mastery link, no translation hint. A `sourceItem` given as a **map** is accepted as well.
- Pin a stable `id` on every object. Without one a question becomes `json_<timestamp>_<index>`, and a map-form `sourceItem` without an id becomes `generated_<timestamp>` — both are re-randomised on every launch, so the question never registers in the `seen_questions` box (it repeats forever) and never links to mastery. If you cannot name the item, omit `sourceItem` rather than inventing one.

**Input Source:**
- Canonical input is `assets/data/source.md` (pipe-delimited `| Portugues | English | Notes |` rows). The `Ramesh __ Filomena - Aula de português (Portuguese class).md` named below survives only as a `.bak` at the repo root; the readable class notes are `docs/class_materials/classes_6_7/Ramesh __ Filomena - Aula de português (Portuguese class) (6).md` and `(7).md`, and nothing parses them automatically — treat them as research, not a pipeline path.
The whole pipeline (inbox → `source.md` → `questions.json`) is described in `.agents/skills/expand-vocabulary/SKILL.md`.

**Output Requirements:**
- Generate a single valid JSON array containing "Question" objects.
- The output must be downloadable or easy to copy-paste into a file named `questions.json`.
- Do not output markdown code blocks if possible, or ensure the code block contains *only* the raw JSON data so it can be saved directly.

**Target JSON Structure:**

Each item in the array must follow this schema:

```json
{
  "id": "unique_id_string",
  "type": "type_enum",
  "question": "The question text to display",
  "options": ["Option 1", "Option 2", "Option 3", "Option 4"],
  "answer": "The correct option string",
  "sourceItem": "Exact Portuguese text from the source"
}
```

**Field Details & Rules:**

1.  **`id`**:
    *   Generate a unique string for each question (e.g., `"q1"`, `"q2"`, or `"question_timestamp"`).

2.  **`type`**:
    *   Usable strings: `"multipleChoice"`, `"cloze"`, `"trueFalse"`, `"jumble"`, `"reorderAndConjugate"`. Anything else loads as `multipleChoice` — see the loading rules at the top.
    *   *Recommendation:* Use `"multipleChoice"` for most vocabulary items. Use `"cloze"` (fill-in-the-blank) for sentences or phrases.

3.  **`question`**:
    *   **For Vocabulary (`multipleChoice`):** Create a question like "What is the English translation of '[Portuguese Word]?'" or "Select the correct Portuguese word for '[English Word]'.
    *   **For Sentences (`cloze`):** Create a sentence with a missing word, replacing the key term with `_____`. E.g., "Eu _____ de jogar ténis." (missing 'gosto').

4.  **`options`**:
    *   A list of 4 strings.
    *   Must include the Correct Answer.
    *   Must include 3 incorrect "distractors".
    *   *Distractors Rule:* Distractors should be other words/phrases *from the source file* if possible, or plausible incorrect alternatives. Do not use random nonsense.

5.  **`answer`**:
    *   The string that matches the correct option exactly.

6.  **`sourceItem`**:
    *   **CRITICAL:** This field MUST contain the **Exact Portuguese Text** as it appears in the "Portugues" column of the source Markdown file.
    *   The app uses this string to link the question back to the user's progress tracking. If this does not match exactly (including case and accents), the mastery tracking will fail.

**Example Process:**

*Source Row:* `| Um carro | A car | |`

*Generated Output Object:*
```json
{
    "id": "gen_001",
    "type": "multipleChoice",
    "question": "What is the English translation of 'Um carro'?",
    "options": [
        "A car",
        "A house",
        "A bicycle",
        "A plane"
    ],
    "answer": "A car",
    "sourceItem": "Um carro"
}
```

**Instructions:**
1. Read the provided Markdown file.
2. Select a set of items (e.g., all items, or a random selection of 20 items if the list is huge).
3. Convert them into the JSON format described above.
4. Ensure the JSON syntax is valid.
