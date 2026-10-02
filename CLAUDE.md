# Language Trainer — Project Guide

European Portuguese learning app for English speakers (iOS/Android).
Flutter ^3.10.7 · Riverpod (`Notifier` providers) · Hive local storage · `just_audio` + `just_audio_background`.
No backend: TTS, STT and quiz generation run on-device.

## Layout

- `lib/main.dart` — global providers: `storageServiceProvider`, `ttsServiceProvider`, `progressServiceProvider`, `verbServiceProvider`, `notificationServiceProvider`, `navigatorKey` (notification deep links).
- `lib/services/` — one class per file (audio: `tts_service`, `silence_audio_service`, `carplay_service`; quiz: `quiz_engine_service`, `voice_quiz_service`, `question_loader_service`; content/state: the rest). `lib/ui/*/…_view_model.dart` holds feature state.
- `lib/ui/` — imperative `Navigator.push` + `CircularRevealClipper`, no named routes; `HomeScreen` is root.
- Data loaded at launch: `assets/vocabulary.json`, `assets/Combined_Portuguese_Class_Notes.md`, `assets/data/` (`source.md`, `verbs.csv`, `questions.json`, `combined_questions.json`, `grammar_rules.json`, `interrogatives.json`, `prepositions.json`, `phrases.json`, `verb_phrases.json`, `exercises/`).
- Data tooling: `scripts/ingest_inbox.py`, `scripts/sanitize_source.py`, `scripts/check_duplicates.py`, `generate_quiz.py`.

## Invariants (break these and failures are silent)

- Hive typeIds frozen: `LanguageItem`=0, `QuestionType`=1, `Question`=2. Append fields, never renumber.
- Mastery: `LanguageItem.masteryLevel` 0–5; display tiers 0–4 New/Learning/Familiar/Strong/Mastered (`progress_data.dart`, `maxTier = 4`).
- XP: 10 first correct / 5 retry (`storage_service.dart` `updateWordProgress`), +20 session completion, +10 daily-goal bonus, default goal 50 XP/day (`progress_service.dart`).
- Quiz: 8 `QuestionType` values (`lib/models/question.dart`); seen questions persist in the `seen_questions` box, so any new type must register there or it repeats.
- Voice grading (`voice_quiz_service.dart`): exact → substring → Levenshtein fuzzy at >0.65 similarity; keep all three tiers.
- Listen & Repeat and CarPlay share one audio session. Mode switch / reshuffle pass `recordProgress: false`; only an explicit stop awards XP (blocks XP farming).
- Every `AudioSource` needs a `MediaItem` tag with unique id (`'${item.id}_...'`) or lock-screen/CarPlay notification breaks.

## Deep dives (read only when the task touches them)

- `.agents/skills/listen-repeat-audio/SKILL.md` — 6-source word layout, buffer/starvation/speech-shielding contract, TTS concurrency.
- `.agents/skills/carplay-integration/SKILL.md` — scene gating, 8-item template limit, IPC debouncing, steering-wheel remote commands.
- `.agents/skills/expand-vocabulary/SKILL.md` — inbox → `source.md` → `questions.json` pipeline.

## Verify before finishing

- `flutter test` — all must pass (401 as of Oct 2026) · `flutter analyze` — zero issues · `flutter build ios --no-codesign --simulator` for native changes.
- CarPlay/audio tests need `CarPlayService().resetForTesting()` in `tearDown` (cancels section-update timers, container subscriptions, debounce timestamps).
