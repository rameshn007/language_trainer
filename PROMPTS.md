# Language Quiz Data Generator Prompt

**Role:** You are a helpful Language Learning Assistant and Data Formatting Expert.

**Goal:** Your task is to extract vocabulary and phrases from the provided Markdown file (written by a student learning Portuguese) and convert them into a structured JSON format suitable for a language learning quiz app.

**Input Source:**
- Use the attached/provided Markdown file (e.g., `Ramesh __ Filomena - Aula de português (Portuguese class).md`).
- This file contains tables with columns like "Portugues", "English", and "Notes".

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
    *   Must be one of the following strings: `"multipleChoice"`, `"cloze"`, `"trueFalse"`, `"jumble"`.
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
