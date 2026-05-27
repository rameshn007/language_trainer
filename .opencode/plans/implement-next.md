# Implementation Plan — Language Trainer

## Step 0: Test Infrastructure Setup (Pre-requisite) ✅ COMPLETED

**Before any fixes, set up testing infrastructure to validate no regressions.**

### Add Dev Dependencies ✅
- **File:** `pubspec.yaml`
- Added: `mocktail: ^1.0.4`, `hive_test: ^1.0.1`

### Test Execution
```bash
flutter pub get
flutter test
```
Runs headlessly — no app launch needed.

---

## Step 1: Regression Baseline Tests (No Mocking Needed) ✅ COMPLETED

**Goal:** Establish a safety net before making any changes. These tests have zero Flutter context requirements and run in pure Dart mode.

### 1.1 VoiceQuizService — Fuzzy Matching Logic ✅
**File:** `test/voice_quiz_service_test.dart`
**Tests:** 26 tests — exact match, case-insensitive, whitespace, accent normalization (á→a, ç→c, ã→a), article contractions, contains match, Levenshtein threshold, Portuguese diacritics, edge cases.

### 1.2 MarkdownParser — Table Parsing ✅
**File:** `test/markdown_parser_test.dart`
**Tests:** 22 tests — valid tables, empty/invalid input, malformed rows, unicode preservation, multiple tables, empty content filtering, LanguageItem properties.

### 1.3 QuizEngineService — Question Generation ✅
**File:** `test/quiz_engine_service_test.dart`
**Tests:** 32 tests — generateQuiz count/structure, vocabulary quiz word/phrase split, cloze filtering, verb conjugation questions, distractor quality.

### 1.4 QuestionLoaderService — JSON Parsing ✅
**File:** `test/question_loader_service_test.dart`
**Tests:** 6 tests — error handling for missing/invalid files, graceful degradation.

**Total: 91 tests, all passing.**

---

## Step 2: Storage & Progress Tests (With Mocking)

**Goal:** Test data persistence, XP tracking, streak calculation, and mastery advancement using in-memory Hive + mocks.

### 2.1 StorageService — Data Persistence
**File:** `test/storage_service_test.dart`
**What it tests:** Hive CRUD operations, settings, seen questions tracking
**Setup:** Use `hive_test` package for in-memory boxes
**Tests:**
1. `saveItems()` + `getAllItems()` → returns saved items
2. `updateItem()` → item is updated in storage
3. `deleteItem()` → item removed
4. `clearItems()` → empty list
5. `saveSetting()` + `getSetting()` → returns saved value
6. `getSetting()` with default → returns default when key missing
7. `markQuestionAsSeen()` + `isQuestionSeen()` → returns true
8. `clearSeenQuestions()` → all questions cleared
9. `getDailyXPGoal()` → returns default 50
10. `setDailyXPGoal()` → returns new value

**Estimated effort:** ~80 lines

### 2.2 StorageService — XP & Streak Tracking
**File:** `test/storage_service_test.dart` (continue)
**Tests:**
1. `addXP()` → today's XP increases
2. `getTodayXP()` → returns correct sum
3. `getTotalXP()` → sums all daily records
4. `incrementDailySessions()` → session count increases
5. `getCurrentStreak()` — single day with XP → streak = 1
6. `getCurrentStreak()` — 3 consecutive days → streak = 3
7. `getCurrentStreak()` — gap in streak → resets
8. `getCurrentStreak()` — today has no XP, yesterday does → streak = 1
9. `getBestStreak()` — calculates longest consecutive run
10. `getMasteryDistribution()` → correct counts per tier
11. `getXPHistory(7)` → returns 7 values (oldest → newest)
12. `getXPHistoryLabels(7)` → returns 7 day abbreviations

**Estimated effort:** ~80 lines

### 2.3 StorageService — Word Progress & Mastery
**File:** `test/storage_service_test.dart` (continue)
**Tests:**
1. `updateWordProgress()` correct on first attempt → awards 10 XP
2. `updateWordProgress()` correct on retry → awards 5 XP
3. `updateWordProgress()` wrong → resets correctStreak, no XP
4. `updateWordProgress()` 3 consecutive correct → advances mastery tier
5. `updateWordProgress()` mastery advances to max (tier 4) → no further advancement
6. `getWordProgress()` → returns correct/wrong counts
7. `resetStats()` → all mastery levels reset to 0
8. `resetAllProgress()` → clears all boxes (items, XP, sessions, word progress)

**Estimated effort:** ~60 lines

### 2.4 ProgressService — Session Recording
**File:** `test/progress_service_test.dart`
**What it tests:** `ProgressService` (Notifier) with mocked StorageService using mocktail
**Setup:** Mock `StorageService` with mocktail, inject into ProgressService
**Tests:**
1. `recordQuizAnswer()` correct → calls storage.updateWordProgress() with correct=true
2. `recordQuizAnswer()` correct → calls storage.addXP() with XP amount
3. `recordQuizAnswer()` wrong → calls storage.updateWordProgress() with correct=false
4. `recordQuizAnswer()` → refreshes state (ProgressSnapshot updates)
5. `recordSessionComplete()` → saves SessionRecord to storage
6. `recordSessionComplete()` → awards 20pt completion bonus
7. `recordSessionComplete()` → daily goal bonus awarded when goal just met
8. `recordSessionComplete()` → increments daily sessions
9. `resetAll()` → calls storage.resetAllProgress() and refreshes state
10. `build()` → initial state is all zeros

**Estimated effort:** ~70 lines

### 2.5 QuizViewModel — State Management (Fix for Bug 3)
**File:** `test/quiz_view_model_test.dart`
**What it tests:** Quiz state transitions, answer tracking, session finish
**Setup:** Mock StorageService, inject via ProviderScope override
**Tests:**
1. `startQuiz()` → state.questions is populated
2. `startQuiz()` → currentIndex = 0, score = 0
3. `answerQuestion()` correct → score increments, XP awarded
4. `answerQuestion()` wrong → score unchanged, wrong answers tracked
5. `answerQuestion()` same question twice → XP only on first attempt
6. `nextQuestion()` → currentIndex increments
7. `nextQuestion()` at end → triggers finishSession()
8. `finishSession()` → isFinished = true, bonusXP recorded
9. `answerQuestion()` when finished → returns 0, no state change
10. **REGRESSION TEST:** `reset()` → clears all state, ready for new quiz
11. **REGRESSION TEST:** Two consecutive `startQuiz()` calls → no state bleed

**Estimated effort:** ~80 lines

---

## Step 3: Implement Fixes (With Tests as Safety Net)

### 3.1 Bug 3 — Inconsistent State in Quiz Screen
**Problem:** `quizViewModelProvider` is a singleton. Navigating between quiz types quickly causes stale questions, score mixing, or state bleed.

**Fix — Add `reset()` method (Recommended)**
- **Files:** `lib/ui/quiz/quiz_view_model.dart`, `lib/ui/exercise/exercise_view_model.dart`
- **Steps:**
  1. Add `reset()` method to `QuizViewModel` that resets state to empty questions, score=0, currentIndex=0
  2. Add `reset()` method to `ExerciseViewModel` with same pattern
  3. Call `reset()` in each screen's `initState()` before starting a new quiz/exercise
- **Estimated effort:** ~15 lines of code

### 3.2 Feature 3 — Adaptive Learning Algorithm
**Problem:** Quiz selection uses unseen-first heuristic but doesn't adjust difficulty based on user performance.

**Fix — Category error-rate tracking (Recommended)**
- **Files:** `lib/services/storage_service.dart`, `lib/ui/quiz/quiz_view_model.dart`
- **Steps:**
  1. Add `Map<String, int>` to storage tracking correct/wrong per category (keys: `"category_correct"`, `"category_wrong"`)
  2. In `recordQuizAnswer()`, increment the correct/wrong counter for the question's category
  3. In `QuizViewModel.startQuiz()`, after generating questions, check error rates — if a category has >50% error rate, replace 2-3 of its questions with easier ones (from other categories)
  4. Persist error rates in storage
- **Estimated effort:** ~60 lines of code

### 3.3 Bug 2 — Data Loading on Slow Devices
**Problem:** `home_screen.dart:_loadData()` loads markdown + JSON synchronously, blocking UI on low-end devices.

**Fix:**
- **File:** `lib/ui/home_screen.dart`
- **Steps:**
  1. Split `_loadData()` into two phases: critical data (markdown) loads first, then vocabulary.json and verbs load in a `Future.delayed` or post-frame callback
  2. Add a loading overlay that shows during the full load but disappears after critical data is ready
  3. Add error handling for each loading phase independently so one failure doesn't block the rest
- **Estimated effort:** ~30 lines

---

## Step 4: Code Quality Improvements

### 4.1 Tech Debt 1 — Code Duplication in UI Components
**Problem:** `quiz_screen.dart` and `exercise_screen.dart` share: `_handleAnswer()`, TTS speed cycling, XP popup logic, `QuestionCard` widget.

**Fix:**
- **File:** `lib/ui/widgets/quiz_shared.dart` (new) + refactor existing screens
- **Extract:**
  1. `SharedQuestionCard` widget — the card swiper question display with options, TTS button, long-press support
  2. `SpeedToggleButton` — reusable speed cycling button with snackbar feedback
  3. `_showXPPopup()` helper function — reusable XP popup animation
- **Estimated effort:** ~200 lines extracted, ~100 lines removed from screens

### 4.2 Bug 5 — Localization Issues in Exercise Data
**Problem:** Hardcoded English strings scattered across screens and exercise data.

**Fix — Extract to constants file (Recommended)**
- **File:** `lib/utils/app_strings.dart` (new)
- **Steps:**
  1. Create `AppStrings` class with static getters for all hardcoded UI strings ("Select the correct translation", "Correct!", "Incorrect.", etc.)
  2. Replace inline strings in `quiz_screen.dart`, `exercise_screen.dart`, `voice_trainer_screen.dart`
- **Estimated effort:** ~20 string replacements

### 4.3 Tech Debt 3 — Inconsistent Error Handling
**Fix:** Add try/catch wrappers around `generateQuiz()`, `generateVocabularyQuiz()`, and `generateVerbConjugationQuestions()` in `quiz_engine_service.dart`. Replace bare `catch (_) {}` blocks with proper logging.

---

## Execution Order & Timeline

| Step | What | Status | Effort | Purpose |
|------|------|--------|--------|---------|
| **0** | Add mocktail + hive_test | ✅ Done | 5 min | Test infrastructure |
| **1** | Baseline tests (no mocking) | ✅ Done | 2-3 hrs | Safety net for existing logic |
| **2** | Storage/Progress tests (with mocks) | ⏳ Pending | 2-3 hrs | Coverage for data layer |
| **3.1** | Bug 3 fix (state reset) | ⏳ Pending | 15 min | Critical bug fix |
| **3.2** | Feature 3 (adaptive difficulty) | ⏳ Pending | 1-2 hrs | User value |
| **3.3** | Bug 2 fix (loading performance) | ⏳ Pending | 30 min | UX improvement |
| **4.1** | Code dedup | ⏳ Pending | 1-2 hrs | Maintainability |
| **4.2** | Localization extraction | ⏳ Pending | 15 min | Cleanup |
| **4.3** | Error handling | ⏳ Pending | 30 min | Robustness |

**Total estimated effort remaining: ~5-8 hours**

**Next step:** Step 2 — Storage & Progress tests with mocking, then Step 3.1 — Bug 3 fix.
