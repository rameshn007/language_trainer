# On-device answer verification with Laya — planning notes

Status: **not started.** Written 2026-10-05 after reviewing PR #42 (three rounds) and the
[`convaiinnovations/laya`](https://huggingface.co/convaiinnovations/laya) model card + configs.
Nothing here is implemented; PR #42 shipped *without* it (the earlier Core ML experiment was
reverted). Re-read the "Why the first attempt failed" section before writing any code.

---

## 1. What the model actually is

Verified from the model repo, not from memory:

- **Not an LLM.** `ModernBertForMaskedLM` backbone + a 2-layer decision head.
  `pipeline_tag: text-classification`. Non-autoregressive — one forward pass, no generation,
  so nothing to parse and nothing to hallucinate.
- **Interface:** you pass a *state* (any text/JSON) plus *typed questions*, and get typed
  answers with calibrated probabilities. Three question types: `choice` (pick among labelled
  criteria), `score` (ordinal scale), `noul` (binary + probability).
- **Checkpoints:**
  | checkpoint | backbone | params | context | notes |
  |---|---|---|---|---|
  | root `laya` | ModernBERT-large | 421M | 512 | English; **0.362** acc on typed-decisions |
  | `multilingual/` | mmBERT-base | 322M | 1024 (8192 w/ `max_len=8192`) | 100+ langs, ~2.2x faster |
  | `typed-decisions/` | ModernBERT-large | 421M | 1024 | fine-tuned, **0.766** acc |
- **Runtime:** `pip install laya` (Python ≥3.10), extras `[onnx]`, `[serve]`, `[mcp]`,
  `[langchain]`. Apache-2.0. Fine-tuning notebook available (Kaggle 2×T4).
- **Weights on disk:** 842 MB (root, fp32), 644 MB (multilingual fp32), 842 MB
  (typed-decisions). Tokenizer ships separately: `tokenizer/tokenizer.json` 3.58 MB (root),
  34.36 MB (multilingual). No Core ML / `.mlmodel` / `.mlpackage` in the repo.

### Facts that must survive into any implementation

- Accuracy claims are **not** for language-learning answer grading. Base English scores 0.362
  on their own typed-decisions benchmark; only the *fine-tuned* checkpoint reaches 0.766.
  Portuguese is **unmeasured**. Multilingual XNLI ≈0.731 over 14 non-English languages.
- Card warning, verbatim in spirit: the model stays *confident while wrong* (Khmer: 0.000
  accuracy at 0.952 confidence) and *"confidence gating cannot save you."* The Router does
  script/language detection in <0.5 ms **before** the forward pass and dispatches non-Latin
  script to the multilingual checkpoint.
- Latency 33–40 ms is measured on a **T4 GPU**. Each question is its own sequence (options
  must fit `head_max_len` = 192/256), so N questions = N sequences. Expect materially slower
  on a phone; measure, don't assume.
- It is **not a similarity model.** Do not wire it as "distance between my answer and the key."
  Its native shape is classification over an explicit label set.

## 2. Why the first attempt failed (PR #42, commit `b9c025e`, later reverted)

That commit added `LayaSemanticEvaluator` (189 lines, `AppDelegate.swift`),
`SemanticGradingService` (136 lines Dart), `scripts/export_laya_coreml.py` (223 lines), and
three test files. It never ran a model:

1. No tokenizer was bundled, and no weights were added to `project.pbxproj` resources.
2. `coreMLModel` was declared and never used.
3. `preloadModel` returned a hard-coded `true` → the "available" flag was fiction, and every
   call fell through to Levenshtein while *reporting* neural grading.
4. The export script never referenced ModernBERT at all — it was a stub.
5. The two new test files were vacuous (they passed with the feature removed).
6. Grading used NLEmbedding distance, which produced **false accepts**: e.g. "Eu vou a pé para
   casa" vs "Eu vou de comboio para casa" at distance 0.337 → graded CORRECT; and
   "Obrigado" / "Muito obrigado" at 0.679 → wrongly rejected. This is the failure class to beat,
   and it is why "just add a model" is not the plan — a *distance threshold* is the wrong shape.

**Root cause to avoid repeating:** every layer was written against an assumed model. No step
ever established, on real data, that on-device semantic grading beats the existing 0.65
Levenshtein rule. Start at step 0 below.

## 3. Invariants this touches (from `CLAUDE.md`)

- Voice grading keeps **three tiers**: exact → substring → Levenshtein >0.65
  (`lib/services/voice_quiz_service.dart` `isCorrect`, ~line 227). Anything new is a *fourth
  stage above them*, not a replacement.
- XP: 10 first correct / 5 retry; `recordProgress: false` for mode switch / reshuffle. A new
  answer channel must not become an XP farm.
- `QuestionType` has 8 values; new types must register in the `seen_questions` box or they
  repeat. Append field indices on `LanguageItem`(0)/`QuestionType`(1)/`Question`(2) — never
  renumber.
- Listen & Repeat and CarPlay share one audio session; keep any new inference off that path.

## 4. Current-state facts worth remembering

- iOS deployment target **15.0** (`ios/Podfile`, `project.pbxproj`). Core ML flexible-shape /
  `MLTensor` needs 18+; fixed-shape is available but the model's signature is 5 inputs
  (`input_ids`, `attention_mask`, `marker_pos`, `marker_mask`, `qtype`), so it is hand-written
  Swift either way — no auto-glue.
- `android/` exists and is in scope → a Core ML-only design is a half-port. ONNX Runtime C++
  (~30 MB pod) covers both and the model already ships an ONNX path.
- Total shipped assets today: **17 MB**. A 160–320 MB int8 model cannot go in the bundle; it
  has to be a downloadable add-on with an explicit "not downloaded / not loaded" state.
- **No typed freeform answer surface exists.** All 8 question types are tap-to-choose. The only
  text fields in the app are `lib/ui/vocabulary/vocabulary_list_screen.dart` (search) and
  `vocabulary_item_dialog.dart` (editor). Freeform typing is a new feature, not a new grader.
- Only freeform *answer* channel today is voice (STT) in Voice Trainer, graded at
  `lib/ui/voice_trainer_screen.dart:363` and `:366`.
- No ML dependencies remain in `pubspec.yaml` (all reverted).

## 5. Options, ranked

### Step 0 — Offline measurement spike (do this first, no app code)
Decides whether anything below is worth building.

- `pip install laya` in a scratch venv, laptop, no Flutter.
- Build a gold set of **80–120 pairs**: (learner answer, expected answer, human verdict).
  Pull from `assets/data/questions.json`, `combined_questions.json`,
  `assets/data/exercises/*.json`, plus the false-accept/false-reject pairs from the PR #42
  review (a pé/de comboio, Obrigado/Muito obrigado, dialect `contains` hits like "trem" inside
  "extremo"). Add genuine learner errors from the class-notes files, not just invented ones.
- Compare four graders on the same set: (a) current 3-tier rule as-is, (b) Laya `noul`
  ("is this a genuine correct attempt at X?"), (c) Laya `choice` over
  {correct, wrong-meaning, incomplete, nonsense}, (d) Laya multilingual checkpoint vs root.
- Report false accepts and false rejects per grader, not just accuracy. **False accepts are the
  real bug** — a wrong answer graded correct teaches the error and awards XP.
- **Stop rule:** if no configuration beats the 0.65 rule on false accepts at an acceptable false
  reject rate, stop here. Revisit only with a fine-tuned checkpoint.

### Step 1 — Build-time data audit (highest value per unit of effort, keeps no risk)
Run Laya over the *generated quiz data* on the laptop, offline:

- flag cloze/jumble keys that a plausible distractor also satisfies;
- flag near-duplicate or contradicting questions;
- flag items whose "correct" answer is ambiguous for a PT-BR speaker.

Fits the existing pipeline (`scripts/generate_quiz.py`, `check_duplicates.py`,
`ingest_inbox.py`). Zero app size, zero native code, no iOS-version problem, and it doubles as
the harness for Step 0. Do this even if you never ship on-device grading.

### Step 2 — Fuzzy-tier veto (the only on-device use I'd recommend as a first ship)
- Location: `isCorrect` in `voice_quiz_service.dart`; keep all three tiers.
- Consult the model **only** in the ambiguous band (similarity ~0.65–0.95, or when content
  words differ), and let it **veto** an accept — never grant new ones. Asymmetric on purpose:
  the tier's failure mode today is over-acceptance.
- One `noul` call per ambiguous answer, cached by (answer, expected) pair.
- Must be off the audio-critical path and must not run during L&R / CarPlay playback.

### Step 3 — "Not a real attempt" detector
STT in a car returns noise; today that becomes a false wrong, or a substring false right. A
`noul` question ("is this a genuine attempt at translating X?") filters it, and protects XP
integrity. Cheap, and works on both platforms.

### Step 4 — Error-type labelling
`choice` over {correct, wrong preposition, wrong gender/article, anglicism, word order,
unfinished} → drives feedback text. A mislabel only degrades a hint, so moderate accuracy is
still useful. Better fit for a classifier than binary right/wrong.

### Step 5 — Freeform typed answers (the feature you actually asked about)
Independent of the model, and it needs deciding *first*, because the grader is only half of it:
new `QuestionType` (append index 8), `seen_questions` registration, a text input on the trainer,
and an explicit XP policy for keyboard answers. Grading typed answers can start as rules-only.

### Probably not worth it
Difficulty routing into the mastery 0–5 system (that system already works and is deterministic);
anything needing a bigger model — "no backend" is a deliberate architecture choice here.

## 6. If you ship on-device inference

- Choose **multilingual (mmBERT-base) at int8**, ~160–320 MB, not the 842 MB English large
  checkpoint. Portuguese is a multilingual-checkpoint task; the root checkpoint degrades on
  non-English.
- Ship weights as a **downloadable add-on**, not a bundled asset. Explicit states: not
  downloaded / downloading / loaded / failed. Availability must come from a real successful load
  — never a constant — with a test for the missing-weights path. (This is bug #3 above.)
- Reproduce `rl_common.build_sequence` / `render_options` / marker positions / qtype
  **byte-exactly**, and write a parity test against the Python reference on ≥20 fixed inputs.
  Without that, garbage input reads as success — bugs #1, #2, #4 above.
- Load the model at session start, never mid-turn. Measure peak RSS mid-session alongside audio.
- Tests: every new grading path needs a case that **fails when the feature is removed**. Both
  prior test files passed with the feature deleted; verify by deleting the feature and re-running.
- CarPlay/audio tests need `CarPlayService().resetForTesting()` in `tearDown`.

## 7. Open questions to answer before code

1. Is a wrong answer from the assistant ever shown as *correct* today? How often, on real
   learner input? (Sizes the problem; answer it from class-notes data, not intuition.)
2. Do typed/keyboard answers earn XP? If yes, how do you keep the keyboard out of XP farming?
3. Do you want verification (model judges the answer) or *coaching* (model names the mistake)?
   Step 4 is cheaper and more robust than Step 2 for the same user-visible benefit.
4. Android: half-port acceptable, or is one shared engine (ONNX Runtime) a precondition?
5. What is the app-size / download budget for an optional 160–320 MB model?

## 8. Suggested first session, if picked up

Do Step 0 + Step 1 together, entirely under `scripts/` with a `test/` file for the harness:
scratch venv, gold-set JSON built from existing quiz data, four graders, a printed
false-accept/false-reject table. Deliverable is a **number**, not a feature. No `lib/`, no
`ios/`, no `pubspec.yaml` changes until that number justifies them.
