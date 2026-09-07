# Language Trainer — Context & Architecture

European Portuguese learning app for English speakers (iOS & Android).
- **Stack:** Flutter SDK ^3.10.7, Riverpod (`Notifier` providers), Hive (local storage), `just_audio` + `just_audio_background`.
- **Navigation:** Imperative `Navigator.push` with `CircularRevealClipper` (no named routes). `HomeScreen` is root.
- **Backend:** None. All TTS, STT, and quiz generation run entirely on-device.

---

## Global Providers (`main.dart`)

- `storageServiceProvider`: `StorageService` (Hive boxes: `items`, `settings`, `progress`, `seen_questions`).
- `ttsServiceProvider`: `TtsService` (system TTS scoring: prefers "Joana" pt-PT, "Alex"/"Daniel" en-US; penalizes Siri/novelty voices -1000).
- `progressServiceProvider`: `ProgressService -> ProgressSnapshot` (XP, streaks, mastery tiers).
- `verbServiceProvider`: `VerbService` (CSV + JSON conjugation tables).
- `notificationServiceProvider`: `NotificationService` (local push notifications).
- `navigatorKey`: Global key for notification deep linking.

---

## Data Model & Learning Systems

- **`LanguageItem`** (Hive typeId 0): `id`, `portuguese`, `english`, `notes`, `masteryLevel` (0–5), `lastReviewed`, sentences, gender, verb class.
  - Loaded at launch from `assets/data/source.md`, `Combined_Portuguese_Class_Notes.md`, `vocabulary.json`, `verbs.csv`. User review history is preserved across reloads.
- **Mastery Tiers (0–4):** New → Learning → Familiar → Strong → Mastered (`LanguageItem.masteryLevel` 0–5).
- **XP System:** 10 XP first correct, 5 XP retry, 20 XP session completion bonus, 10 XP daily goal bonus (default goal: 50 XP/day).
- **Voice Quiz (`VoiceQuizService`):** `speech_to_text` + fuzzy matcher (exact, substring, Levenshtein distance > 0.65 similarity).
- **Quiz Engine (`QuizEngineService`):** 8 question types (Multiple Choice, Vocab Match, Cloze, Conjugation, Prepositions, Grammar, Interrogatives, Jumble). Tracks seen questions in storage to prevent repeats.

---

## Listen & Repeat (L&R) Architecture

Passive audio training — no speech recognition, user repeats silently. Runs via `listenRepeatViewModelProvider` (`lib/ui/listen_repeat/listen_repeat_view_model.dart`).

- **Audio Pipeline:**
  - Words are synthesized on-demand to temporary audio files (`pt-PT` and `en-US`) via `TtsService.synthesizeToFile`.
  - Words are streamed into a `ConcatenatingAudioSource` played by `_bgAudioPlayer` (`just_audio` + `just_audio_background`).
  - Each word consists of **5 audio sources**: `[PT, silence1, silence2 (repetition pause), EN, silence3]`.
  - Every audio source **must** be tagged with `MediaItem.copyWith(id: '${item.id}_...')` for `just_audio_background` notification support.
- **Concurrency & State Safety:**
  - Concurrency model: **"latest request wins"** via `_runStartLoop` and `_sessionId` invalidation. Rapid taps (e.g. mode switches) cleanly abort prior in-flight builds.
  - Word generation mutex: `_generationFuture` lock guarantees only one background deck build / TTS synthesis runs at a time.
  - Poison-pill protection: skips any item that fails synthesis twice; halts after 6 consecutive failures.
  - Playback resume: `_bgAudioPlayer.play()` is un-awaited (`if (_isAutoPlayActive && !_bgAudioPlayer.playing) _bgAudioPlayer.play().catchError(...)`) so it never blocks word-skipping methods.
- **Study Focus Modes (`ListenRepeatMode`):**
  - `all` (Balanced Mix), `verbs`, `prepositions`, `phrases`, `vocabulary`. Filtered via `ListenRepeatContentService`.
  - Mode switching and shuffling pass `recordProgress: false` and cache `_sessionWordsOffset` so cumulative words seen persist without XP farming. Explicit session stops pass `recordProgress: true` to award XP once.

---

## CarPlay Integration (`CarPlayService` & Native iOS)

CarPlay acts as an in-car player for the shared L&R session (no microphone/voice).

- **Scene Lifecycle & Triggering (`CarPlaySceneObserver` in `AppDelegate.swift`):**
  - Plugin `connected` event is ambiguous (fires on plain cable connect).
  - Session startup is strictly gated on the native `language_trainer/carplay_scene` channel (`sceneWillEnterForeground` push or `sceneStatus` pull).
  - State listening via `_ensureStateListener()` is lazy — never attach provider listeners in `init()`.
- **UI & Head Unit Compliance:**
  - Player template is a `CPListTemplate` capped at 8 items across 3 sections (Current Word with live now-playing indicator & Flag for Review action [2 items], Playback controls [3 items], Session controls: Focus cycle, Speed, Stop [3 items]; replacing mid-session reshuffle to stay strictly within Apple's 8-item template limit).
  - Stop session returns to the Study Focus menu (`Balanced Mix`, `Verbs`, `Prepositions`, `Phrases`, `Vocabulary`).
- **Steering Wheel & Media Controls (`RemoteCommandInterceptor` in `AppDelegate.swift`):**
  - Fixes the 5-source skip glitch where default next/previous track steps into silence chunks.
  - Swizzles `AudioServicePlugin` (`nextTrack:`, `previousTrack:`, `skipForward:`, `skipBackward:`) via Objective-C runtime and hooks `MPRemoteCommandCenter.shared()`.
  - Dispatches `remoteNextWord` / `remotePreviousWord` to Dart, seeking by 5 audio sources (`(currentWordIndex ± 1) * 5`) directly to the Portuguese audio.
  - Debounced in Dart with independent per-direction timers (`_lastRemoteNextTime`, `_lastRemotePreviousTime`, 300ms) to allow rapid reversals while dropping hardware bounce.

---

## Testing & Quality Conventions

- Run tests: `flutter test` (all tests should pass, currently 163 tests).
- Static analysis: `flutter analyze` (zero issues allowed).
- iOS Simulator build: `flutter build ios --no-codesign --simulator`.
- Test hygiene: Use `CarPlayService().resetForTesting()` in `tearDown` to reset container subscriptions and debounce timestamps.
