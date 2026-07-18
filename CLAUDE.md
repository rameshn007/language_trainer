# Language Trainer — Project Context

## Overview

Flutter app (iOS + Android) teaching **European Portuguese** to English speakers.
- **Framework:** Flutter SDK ^3.10.7
- **State Management:** Riverpod (`flutter_riverpod` Notifier providers)
- **Storage:** Hive (local NoSQL, `hive` + `hive_flutter`)
- **Version:** 1.0.0+30

## Directory Structure

```
lib/
  main.dart                          # Entry point, ProviderScope, global service init
  models/
    language_item.dart               # Core vocabulary model (Hive-serialized, typeId 0)
    language_item.g.dart             # Generated Hive adapter
    question.dart                    # Quiz question model (8 question types)
    question.g.dart
    progress_data.dart               # DailyRecord, SessionRecord, WordProgress
    progress_data.g.dart
    verb.dart                        # Verb conjugation model
    verb_phrase.dart                 # Verb phrase model
  services/
    storage_service.dart             # Hive wrapper: items, settings, progress, seen questions
    tts_service.dart                 # Text-to-speech (flutter_tts) — shared across all features
    voice_quiz_service.dart          # Speech recognition + fuzzy answer matching
    quiz_engine_service.dart         # Generates all quiz types from data sources
    progress_service.dart            # XP, streaks, mastery state (Riverpod Notifier)
    question_loader_service.dart
    verb_service.dart                # Loads verbs from CSV + JSON
    markdown_parser.dart             # Parses markdown source data into LanguageItems
    translation_service.dart
    notification_service.dart        # Local notifications (flutter_local_notifications)
    carplay_service.dart             # CarPlay orchestrator
    carplay/
      carplay_drill_provider.dart    # Abstract drill interface + DrillChallenge model
      vocabulary_flashcard_drill_provider.dart  # Vocabulary flashcard drill (only implementation)
  ui/
    home_screen.dart                 # Main dashboard — expandable sections, FABs, animated stats card
    settings_screen.dart
    stats_screen.dart
    voice_trainer_screen.dart        # Voice recognition practice (speech_to_text)
    phrase_trainer_screen.dart       # Phrase training
    vocabulary/
      vocabulary_list_screen.dart
      word_graph_screen.dart
      vocabulary_item_dialog.dart
    exercise/
      exercise_list_screen.dart
      exercise_screen.dart
      exercise_view_model.dart
    quiz/
      quiz_screen.dart               # Main quiz UI (card swiper via flutter_card_swiper)
      quiz_view_model.dart
      category_selection_screen.dart
      verb_conjugation_screen.dart
      verb_conjugation_view_model.dart
      single_verb_conjugation_screen.dart
      single_verb_conjugation_view_model.dart
      verb_phrase_trainer_screen.dart
      interrogative_quiz_screen.dart
      interrogative_reference_screen.dart
      preposition_quiz_screen.dart
      preposition_reference_screen.dart
      grammar_quiz_screen.dart
      grammar_reference_screen.dart
    listen_repeat/
      listen_repeat_screen.dart      # Passive listening/repetition mode
      listen_repeat_view_model.dart  # Riverpod state for Listen & Repeat
    widgets/
      xp_popup.dart
      word_star_field.dart
    common/
      long_press_word_text.dart
  utils/
    logger.dart
    circular_reveal_clipper.dart     # Custom page transition clipper
```

## Routing

No named routes. Uses imperative `Navigator.push` with `PageRouteBuilder` and `CircularRevealClipper` for circular reveal animations.

`HomeScreen` is the `home` of `MaterialApp`. All other screens are pushed imperatively.

## Global Providers (main.dart)

| Provider | Type | Purpose |
|---|---|---|
| `storageServiceProvider` | `StorageService` | Hive database wrapper (singleton) |
| `ttsServiceProvider` | `TtsService` | Text-to-speech |
| `notificationServiceProvider` | `NotificationService` | Push/local notifications |
| `progressServiceProvider` | `ProgressService → ProgressSnapshot` | XP, streaks, mastery |
| `verbServiceProvider` | `VerbService` | Verb conjugation data |

`navigatorKey` is a global `GlobalKey<NavigatorState>` for deep linking from notifications.

## Key Features

### Quiz Types (QuestionType enum)
1. **Multiple Choice** — PT↔EN word matching
2. **Vocabulary Match** — prioritizes unseen words, splits words vs phrases
3. **Interrogative Match** — Portuguese question words to English
4. **Preposition Fill** — cloze-style blanks in PT sentences
5. **Grammar Rules** — multiple choice about grammar concepts
6. **Verb Conjugation** — conjugate by pronoun (eu, tu, voce, nos, voces)
7. **Cloze** — fill-in-the-blank from example sentences
8. **Jumble / True-False / ReorderAndConjugate** — defined, usage varies

### Learning Systems
- **Mastery Tiers** (0–4): New → Learning → Familiar → Strong → Mastered
- **XP System**: 10 XP first correct, 5 XP retries, 20 XP session bonus, 10 XP daily goal bonus
- **Daily Goals**: Default 50 XP/day, configurable
- **Streak Tracking**: Current and best streak from daily records
- **Seen Questions Tracking**: Remembers question variants to avoid repetition

### Home Screen Organization
4 expandable sections with grid buttons:
1. **Vocabulary & Flashcards** — Vocabulary list, Start Quiz, Vocab Quiz
2. **Grammar & Verbs** — Verb Trainer, Interrogatives, Prepositions, Grammar Rules
3. **Practice & Exercises** — Exercises, Sentence Builder, Question Builder
4. **Speaking & Phrases** — Voice Trainer, Phrase Trainer, 100 Phrases

Two FABs:
- **Headphones** → Listen & Repeat
- **Sparkle** → Lucky Quiz (infinite random quiz)

Animated pinned stats card at top (shrinks on scroll): XP progress, streak, mastery distribution.

---

## Listen & Repeat Feature

**Entry:** FAB (`Icons.headset_rounded`) on HomeScreen → pushes `ListenRepeatScreen`.

### Flow

1. **Session start** (`listen_repeat_view_model.dart`):
   - Fetches all `LanguageItem`s from `StorageService.getAllItems()`
   - Shuffles pool, picks a random word, sets `isPlaying = true`

2. **Auto-play loop** (`listen_repeat_screen.dart:_startAutoPlayLoop`):
   - Calls `_playAudio(item)`: speaks Portuguese (`pt-PT`) → 500ms pause → speaks English (`en-US`)
   - Pauses 2 seconds (user repeats aloud)
   - Advances to next random word via `nextWord()`
   - Loops until user stops or app leaves foreground

3. **Background silence**: `silence.mp3` plays on loop via `just_audio` to keep iOS audio session active (prevents lock-screen audio routing issues).

4. **UI controls**:
   - **Play Again** — replays current word audio (manual override)
   - **Next Word** — skips to next random word
   - **Shuffle** — reshuffles pool, picks new word
   - **Stop** — stops session, pops screen

5. **Lifecycle handling** (`didChangeAppLifecycleState`):
   - On `resumed` while TTS is speaking: forces `tts.stop()` + `nextWord()` to unblock a stuck isolate (common iOS edge case when user pauses from lock screen).

### No speech recognition in this mode.
The user repeats silently. This is purely a passive listening/repetition feature.

### Key files
- `lib/ui/listen_repeat/listen_repeat_screen.dart` — UI + auto-play loop
- `lib/ui/listen_repeat/listen_repeat_view_model.dart` — Riverpod Notifier state
- `lib/services/tts_service.dart` — shared TTS engine

---

## CarPlay Integration

**Entry:** `CarPlayService().init(storageService, ttsService)` called in `main.dart` at app startup.

### Architecture

Uses `flutter_carplay` (v1.6.3) with a **drill provider pattern** (strategy pattern):

1. **`CarPlayDrillProvider`** (abstract interface):
   - `displayName` / `description` — for list items
   - `startSession()` → returns first `DrillChallenge`
   - `nextChallenge()` → returns next challenge
   - `processAnswer(String answer)` → validates spoken answer
   - `completionSummary`, `isFinished`

2. **`DrillChallenge`** — data model:
   - `promptText`, `detailText`, `options`, `isVoiceOnly`

3. **`VocabularyFlashcardDrillProvider`** — only concrete implementation:
   - Takes 5 random vocabulary items
   - Shows Portuguese word, user speaks answer
   - Validates via substring matching against Portuguese target
   - TTS feedback: "Correct" or "Incorrect. It was [word]"

### Session Flow (`carplay_service.dart`)

1. **Connection detection**: `FlutterCarplay.addListenerOnConnectionChange` → calls `_setupRootTemplate()` when connected
2. **Root template**: `CPListTemplate` titled "Language Trainer" with house icon, shows "Available Drills" section
3. **Drill session loop**:
   - Pushes `CPListTemplate` with current challenge prompt
   - If voice-only, speaks prompt via TTS
   - Calls `VoiceQuizService.listenForAnswer(10s)` — uses `speech_to_text` with `pt-PT` locale
   - Passes recognized answer to drill provider for validation
   - Repeats until `isFinished`
4. **Completion**: Shows summary, speaks it, pops back after 5 seconds

### iOS Native Setup
- `Info.plist` declares `CPTemplateApplicationSceneSessionRoleApplication` scene
- Uses `flutter_carplay.FlutterCarPlaySceneDelegate` (implements `CPTemplateApplicationSceneDelegate`)
- Shared `FlutterEngine` between regular app and CarPlay scene
- Audio permissions: `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`
- `UIBackgroundModes` includes `audio`

### Key files
- `lib/services/carplay_service.dart` — CarPlay orchestrator (connection, navigation, session loop)
- `lib/services/carplay/carplay_drill_provider.dart` — abstract interface + `DrillChallenge`
- `lib/services/carplay/vocabulary_flashcard_drill_provider.dart` — vocabulary flashcard drill

### Current state
Only **one drill** implemented. Architecture supports adding more by implementing `CarPlayDrillProvider`.

---

## TtsService — Shared Speech Engine

**File:** `lib/services/tts_service.dart`

- Wraps `flutter_tts` with intelligent voice selection
- **Voice scoring at init:**
  - Portuguese: prefers "Joana" (+20), "Enhanced"/"Premium" (+10)
  - English: prefers "Alex"/"Daniel" (+10), "Samantha" (+5), penalizes Siri (-1000), novelty voices (-1000)
- Users can select custom voices (persisted in settings)
- **Dynamic fallback:** if cached voice fails at speak-time, re-queries system voices
- **Audio session (iOS):** `playback` category with `defaultToSpeaker`, `allowBluetooth`, `allowBluetoothA2DP`, `mixWithOthers`, `allowAirPlay`
- **Rate:** base 0.5 × user multiplier (0.1–1.0 range)
- `awaitSpeakCompletion(true)` — speak() waits for audio to finish

---

## VoiceQuizService — Speech Recognition

**File:** `lib/services/voice_quiz_service.dart`

- Uses `speech_to_text` plugin
- `listenForAnswer(Duration, localeId)` — activates mic, streams sound level updates, returns recognized text or null
- Options: `listenFor` timeout, `pauseFor` 3s silence auto-stop, `listenMode.confirmation`
- `isCorrect(spoken, correct)` — fuzzy matching:
  1. Normalize: lowercase, trim, strip non-word chars
  2. Direct match
  3. Contains match (substring)
  4. Levenshtein distance — similarity > 0.65 allowed

---

## Data Model

**`LanguageItem`** (`lib/models/language_item.dart`) — Hive typeId 0:
- `id`, `portuguese`, `english`, `notes`
- `masteryLevel` (0–5), `lastReviewed`
- `pronunciation`, `wordType`, `cefrLevel`, `topicCategory`
- `exampleSentencePt`, `exampleSentenceEn`, `gender`, `plural`, `irregular`, `verbClass`

Loaded from multiple sources at startup (`home_screen.dart:_loadData`):
1. `assets/data/source.md` (markdown parser)
2. `assets/Combined_Portuguese_Class_Notes.md`
3. `assets/vocabulary.json`
4. `assets/data/verbs.csv` (via `VerbService`)
Mastery and review history are preserved across reloads.

---

## Dependencies (pubspec.yaml)

| Package | Purpose |
|---|---|
| `flutter_riverpod` | State management |
| `hive` / `hive_flutter` | Local storage |
| `flutter_tts` | Text-to-speech |
| `speech_to_text` | Speech recognition |
| `flutter_card_swiper` | Card-flip quiz UI |
| `just_audio` / `just_audio_background` | Audio playback |
| `flutter_local_notifications` | Notifications |
| `flutter_carplay` | CarPlay integration |
| `avatar_glow` | Audio playback animation |
| `google_fonts` | Custom typography |
| `animate_do` | Animations |
| `http` | HTTP requests |

---

## Important Notes for Development

- **No backend/API** for speech processing — all TTS and STT run on-device (Apple Speech framework / Google Speech API)
- **No named routes** — all navigation is imperative `Navigator.push`
- **Shared FlutterEngine** between mobile app and CarPlay scene on iOS
- **Silence audio asset** (`assets/audio/silence.mp3`) is critical for iOS audio session behavior in Listen & Repeat
- **Voice selection** has extensive scoring logic — don't remove novelty voice penalties without testing
- **CarPlay** uses `FlutterCarplay.pop()` / `push()` to navigate — templates are replaced to avoid stack growth during sessions
