# Potential Features and Bugs for Language Trainer

CarPlay and Listen & Repeat work is tracked in `docs/carplay_roadmap.md` (phases 6-8 still open) and `.agents/skills/carplay-integration/SKILL.md` — check those before adding a duplicate item here. Paths below were re-checked against the tree on 2026-10-10, as was the 494-test / 32-file total quoted under Technical Debt.

## Features to Implement or Enhance

### 1. Enhanced Voice Recognition Accuracy
- **Description**: Improve the accuracy of voice recognition, especially in noisy environments.
- **Files involved**: `lib/services/voice_quiz_service.dart`, `lib/ui/voice_trainer_screen.dart`
- **Priority**: High

### 2. Multi-language Support Expansion
- **Description**: Expand support for additional languages beyond the current ones.
- **Files involved**: `lib/models/language_item.dart`, `lib/services/question_loader_service.dart`, `assets/data/questions.json`
- **Priority**: Medium

### 3. Adaptive Learning Algorithm
- **Description**: Implement an adaptive learning algorithm that adjusts difficulty based on user performance.
- **Files involved**: `lib/services/quiz_engine_service.dart`, `lib/ui/quiz/quiz_view_model.dart`
- **Priority**: High

### 4. Offline Mode Enhancements
- **Description**: Improve offline functionality, including caching more data and providing better offline error handling.
- **Files involved**: `lib/services/storage_service.dart`, `lib/models/question.dart`
- **Priority**: Medium

### 5. CarPlay UI Optimization
- **Description**: Optimize the CarPlay interface for better usability in automotive environments.
- **Files involved**: `lib/services/carplay_service.dart`, `lib/ui/listen_repeat/in_car_dashboard_screen.dart`, `ios/Runner/AppDelegate.swift` — the concrete open work is roadmap Phase 8 (driving-safety layout pass + in-car "Try Again" on TTS failure); the Replay and Shuffle rows are already gone, replay now lives on the word row.
- **Priority**: Low

### 6. Text-to-Speech Customization
- **Description**: Allow users to customize TTS voice settings (speed, pitch).
- **Files involved**: `lib/services/tts_service.dart`, `lib/ui/voice_trainer_screen.dart`
- **Priority**: Medium

### 7. Progress Tracking and Analytics
- **Description**: Implement detailed progress tracking with analytics to show user improvement over time.
- **Files involved**: `lib/models/language_item.dart`, `lib/services/storage_service.dart`
- **Priority**: High

### 8. CarPlay Provider Interface Improvement
- **Description**: Update the provider interface to include a `nextChallenge()` method, avoiding reliance on `startSession()`.
- **Files involved**: `lib/services/carplay_service.dart`, `lib/ui/listen_repeat/listen_repeat_view_model.dart` — there is no `lib/services/carplay/` package; services are flat files, so name the real ones
- **Priority**: Medium

## Bugs to Fix

### 1. Voice Recognition Errors in the Voice Trainer
- **Description**: Users report voice recognition not working consistently during speaking drills. Scope it before triaging: `SpeechToText` exists only in `voice_quiz_service.dart`, which only `lib/ui/voice_trainer_screen.dart` constructs — `quiz_screen.dart` has no microphone at all, so a "voice fails in the quiz" report is either a Voice Trainer report or a mislabelled multiple-choice issue.
- **Files involved**: `lib/services/voice_quiz_service.dart`, `lib/ui/voice_trainer_screen.dart`
- **Priority**: Critical

### 2. Data Loading Issues on Slow Devices
- **Description**: The app crashes or freezes when loading exercises on low-end devices.
- **Files involved**: `lib/services/question_loader_service.dart`, `lib/ui/exercise/exercise_list_screen.dart`
- **Priority**: High

### 3. Inconsistent State Management in Quiz Screen
- **Description**: The quiz screen sometimes shows incorrect answers or resets unexpectedly.
- **Files involved**: `lib/ui/quiz/quiz_view_model.dart`, `lib/services/quiz_engine_service.dart`
- **Priority**: Critical

### 4. Missing Error Handling for TTS Service
- **Description**: The app crashes when the TTS service fails to initialize or returns errors.
- **Files involved**: `lib/services/tts_service.dart`, `lib/ui/voice_trainer_screen.dart`
- **Priority**: Medium

### 5. Localization Issues in Exercise Data
- **Description**: Some exercises contain hardcoded strings that are not properly localized.
- **Files involved**: `assets/data/exercises/*.json`, `lib/models/question.dart`
- **Priority**: Low

## Technical Debt

### 1. Code Duplication in UI Components
- **Description**: Multiple UI components have duplicated logic, especially in the quiz and exercise screens.
- **Files involved**: `lib/ui/quiz/*.dart`, `lib/ui/exercise/*.dart`
- **Priority**: Medium

### 2. Untested paths that matter
- **Description**: 494 tests across 32 files, including 32 for `quiz_engine_service`, so "no unit tests for critical services" is no longer true. The real gaps: nothing exercises the production asset-load path (`rootBundle` does not resolve under fake async — decks must be injected with `initialCards`, and the Listen & Repeat suites inject fixtures rather than reading `assets/data/`), and only the Dart half of the remote-command path is covered — `test/listen_repeat_remote_control_test.dart` encodes channel `MethodCall`s, but nothing exercises `RemoteCommandInterceptor`'s swizzling of `AudioServicePlugin.nextTrack:` / `previousTrack:`, which is only reachable on a device or simulator and only asserts in DEBUG.
- **Files involved**: `lib/services/question_loader_service.dart`, `ios/Runner/AppDelegate.swift`, `test/helpers/carplay_test_helpers.dart`
- **Priority**: High

### 3. Inconsistent Error Handling
- **Description**: Error handling is inconsistent across the application, leading to crashes or poor user experience.
- **Files involved**: All service files in `lib/services/`
- **Priority**: Medium

## Documentation Improvements

### 1. Update API Documentation for Services
- **Description**: Add detailed documentation for all public methods in the services directory.
- **Files involved**: `lib/services/*.dart`
- **Priority**: Low

### 2. Add Example Usage for Key Components
- **Description**: Provide example usage for key components like `WordStarField` and `QuizScreen`.
- **Files involved**: `lib/ui/widgets/word_star_field.dart`, `lib/ui/quiz/quiz_screen.dart`
- **Priority**: Low