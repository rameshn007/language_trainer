# language_trainer

European Portuguese for English speakers. Flutter app, iOS-first, running entirely on-device: no backend, no accounts, no server-side content. Vocabulary, audio and quizzes are generated locally from files bundled in `assets/`.

One network call exists: `lib/services/translation_service.dart` hits the MyMemory API for ad-hoc lookups from the word dialog, and returns `null` when offline or rate-limited. Everything else is local.

## What the app does

- **Listen & Repeat** (`lib/ui/listen_repeat/`) — hands-free drill. Each word is a fixed 6-source block on a background `just_audio` player: PT, pause, PT (repeat), adaptive pause, EN, pause. Passive — the learner repeats out loud, nothing is scored.
- **CarPlay** (`lib/services/carplay_service.dart` + native half in `ios/Runner/AppDelegate.swift`) — in-car player over the same session: study-focus menu, 8-row player template, flag-for-review, and steering-wheel ⏭/⏮ that skip a whole word instead of landing on a silence chunk. iOS only.
- **Flashcards** (`lib/ui/flashcards/`) — filtered decks, auto-advance, conjugation tables, XP per answer.
- **Quizzes** (`lib/ui/quiz/`) — 8 question types including cloze, jumble, reorder-and-conjugate, interrogative and preposition matching.
- **Voice trainer** (`lib/ui/voice_trainer_screen.dart`) — the one place with speech recognition; grading in `lib/services/voice_quiz_service.dart` (exact → substring → fuzzy).
- **Vocabulary, exercises, phrase trainer, stats, settings** — `lib/ui/vocabulary/`, `lib/ui/exercise/`, `lib/ui/phrase_trainer_screen.dart`, `lib/ui/stats_screen.dart`, `lib/ui/settings_screen.dart`.

## Layout

```
lib/                     70 Dart files (67 hand-written + 3 generated .g.dart)
├── main.dart            storageServiceProvider, ttsServiceProvider,
│                        notificationServiceProvider, navigatorKey — that's all.
│                        Every other provider sits next to its own class.
├── models/              LanguageItem, Question, Verb, ProgressData (+ generated .g.dart)
├── services/            15 services, one class per file
│   audio      tts_service · silence_audio_service · carplay_service · dynamic_art_service
│   quiz       quiz_engine_service · voice_quiz_service · question_loader_service
│   content    listen_repeat_content_service · verb_service · progress_service ·
│              storage_service · markdown_parser · translation_service ·
│              related_words_service · notification_service
├── theme/               carplay_theme.dart
├── ui/                  39 files
│   ├── flashcards/ listen_repeat/ quiz/ vocabulary/ exercise/ widgets/ common/
│   └── screens that keep state themselves: home, settings, stats, the trainers
└── utils/               iphone_duo_helper · circular_reveal_clipper ·
                         tts_text_sanitizer · logger

test/                    32 `*_test.dart` files, 494 tests; 10 of them import helpers/carplay_test_helpers.dart
assets/vocabulary.json   871 entries → 878 flashcards once `grammar_flashcards.json` (7) is added
assets/data/             source.md · questions.json · combined_questions.json · verbs.csv ·
                         phrases.json · verb_phrases.json · prepositions.json ·
                         interrogatives.json · grammar_rules.json · grammar_flashcards.json ·
                         a2_topic_words.json · exercises/ (20 files) · inbox.md
docs/carplay_roadmap.md  CarPlay design history; phases 6-8 still open
scripts/ · generate_quiz.py   data tooling (below)
```

Navigation is imperative — `Navigator.push` with a `CircularRevealClipper` transition, no named routes, `HomeScreen` is the root.

Listen & Repeat and CarPlay share **one** audio session and one `AudioPlayer`. That coupling is the reason several rules in `CLAUDE.md` exist (mode switches must not award XP, every `AudioSource` needs a unique `MediaItem` id).

## Stack

Flutter 3.47.6 · Dart SDK `^3.10.7` · `flutter_riverpod` 3.4 (Notifier providers) · `hive` + `hive_flutter` · `just_audio` + `just_audio_background` + `audio_session` · `flutter_carplay` 1.6.2 · `flutter_tts` · `speech_to_text` · `google_fonts` · `flutter_card_swiper` · `animate_do` · `avatar_glow` · `flutter_local_notifications` + `timezone` + `flutter_timezone` · `path_provider` · `http`. Tests: `flutter_test`, `mocktail`, `hive_test`. Codegen: `build_runner` + `hive_generator`.

iOS is the platform that is actually exercised (CarPlay, Now Playing, steering-wheel commands, simulator builds). `android/`, `web/`, `linux/`, `macos/`, `windows/` are present because `flutter create` generated them; the audio-dependent features are not verified there.

## Building and testing

```bash
flutter pub get
flutter run
flutter test            # 494 tests
flutter analyze         # must stay clean
flutter build ios --no-codesign --simulator
```

`flutter test` twice when you touch flashcards or layout: deck shuffle is unseeded and audio pacing is timed, so a single green run proves less than it looks like.

## Data pipeline

`assets/data/inbox.md` → `scripts/ingest_inbox.py` → `assets/data/source.md` → `generate_quiz.py` → `assets/data/questions.json`.

Helpers: `scripts/sanitize_source.py` (malformed rows), `scripts/check_duplicates.py` (repeats), `check_translations.py` (read-only, reports rows missing English). Item ids are load-bearing — they key both `questions.json` and a user's Hive history, so re-keying silently breaks mastery tracking and the `seen_questions` box. `generate_quiz.py` appends by default; `--rebuild-all` does the re-keying and is not a routine command. `scripts/ingest_inbox.py` clears `inbox.md` as it ingests, so commit the inbox first.

`assets/data/source.md` is the live file. Every other `.md`/`.json` at the repo root (`source.md` and the `new.md` / `Even_More_words.md` / `batch_1.md` / `more_words_1.md` family, `extracted_words.json`) is a spent input from an earlier import that nothing reads — and the other `.py` files in `scripts/` and at the root are spent one-shot importers. CLAUDE.md lists what each one clobbers before you run it.

## Where the rules live

`CLAUDE.md` — layout map, the invariants that fail silently (Hive typeIds, XP accounting, the audio chain, safe-area insets), and test-harness gotchas. Read it before touching flashcards, Listen & Repeat, CarPlay, or any landscape layout.

`.agents/skills/` — three deep dives: `listen-repeat-audio` (6-source layout, buffer and starvation contract, TTS concurrency), `carplay-integration` (scene gating, 8-row template, Now Playing star and artwork, IPC debouncing, remote commands), `expand-vocabulary` (the pipeline above, plus which `.py` files are safe to re-run).

`docs/carplay_roadmap.md` — what was built and why, phase by phase. History: its audio-source counts describe the layout *at the time*, not today's.
