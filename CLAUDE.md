# Language Trainer — Project Guide

European Portuguese learning app for English speakers (iOS/Android).
Flutter ^3.10.7 · Riverpod (`Notifier` providers) · Hive local storage · `just_audio` + `just_audio_background`.
No backend: TTS, STT and quiz generation run on-device.

## Layout

- `lib/main.dart` — global providers: `storageServiceProvider`, `ttsServiceProvider`, `progressServiceProvider`, `verbServiceProvider`, `notificationServiceProvider`, `navigatorKey` (notification deep links).
- `lib/services/` — one class per file (audio: `tts_service`, `silence_audio_service`, `carplay_service`; quiz: `quiz_engine_service`, `voice_quiz_service`, `question_loader_service`; content/state: the rest). `lib/ui/*/…_view_model.dart` holds feature state.
- `lib/ui/` — imperative `Navigator.push` + `CircularRevealClipper`, no named routes; `HomeScreen` is root.
- `lib/ui/flashcards/` — `FlashcardsScreen` (filtered deck + hands-free auto-advance chain) with `widgets/flashcard_card_widget.dart` and `widgets/conjugation_table_widget.dart`. Deck defaults to **shuffled + auto-advance on**; decks injectable via `initialCards`.
- `lib/utils/iphone_duo_helper.dart` — single source of truth for iPhone Duo / Dynamic Island geometry: `isDuo`, `systemIconReservedWidth` (76), `appBarActionsRightPadding` (56), `getContentHorizontalPadding`, `getAppBarActionsRightPadding`, `getFabLocation`, `debugOverride`.
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
- Flashcard answers pay XP through `ProgressService.recordQuizAnswer` — never `updateWordProgress` alone (that moves mastery but awards no XP).
- Session +20 is gated on `_hasAwardedCompletionThisPass && _cardsStudiedThisPass.isNotEmpty`; both reset on restart/deck rebuild. Keep that pairing — a completion bonus keyed only to a once-per-screen flag is farmable with two gestures.
- Flashcard auto-advance chain = one `AnimationController` (`_countdownController.forward().orCancel`, catch `TickerCanceled`) + `_speechDelayTimer`/`_speechDelayCompleter` + per-chain `_speechChainToken`. Every await between utterances must re-check `token == _speechChainToken && mounted && !_isDisposed`; `_stopSpeech` bumps the token, kills the timer **and** completes the pending completer (a hanging completer parks the chain forever).
- Anything indexing `_deck[_currentIndex]` needs a `_deck.isNotEmpty` guard (empty deck + auto-advance threw `RangeError (length): Valid value range is empty: 0`).
- Status strip and countdown bar sit outside the card body and listen to `_countdownController` via `AnimatedBuilder`; don't rebuild the card body per frame. A content-rich card is ~21 s of audio + reading time — budget new spoken segments accordingly (the 878-card deck is not meant to auto-play end to end; filtered decks are).
- Deck shuffle is unseeded `List.shuffle()` and auto-advance defaults on → pass `initialShuffle: false` / `initialAutoAdvance: false` in tests unless that path is the subject.

## Landscape / iPhone Duo layout (failures are visual, portrait tests won't catch them)

- Take horizontal insets from `IPhoneDuoHelper.getContentHorizontalPadding(context, hasFab: false)` — pass `hasFab: false` on screens with no FAB (Flashcards); the default adds +84 right clearance for the FAB. AppBar actions take `getAppBarActionsRightPadding(context)`.
- Never stack manual horizontal padding on top of an active horizontal `SafeArea`: `SafeArea` re-applies `MediaQuery.padding.right`, so the insets add up (bottom bar once measured 88 pt against the card's 44). Either let `SafeArea` do it, or use `SafeArea(top: false, left: false, right: false)` plus helper padding.
- The left edge needs the same treatment as the right: in island-left landscape the system band is 44–59 pt, so fixed 18–20 pt padding puts content under the cutout.
- Keep card content and the bottom control bar on the same inset — misalignment between the two reads as a bug even when nothing overflows.
- Home tile grids are content-driven, not breakpoint-driven: `chooseTileColumnCount` (`lib/ui/home_tile_layout.dart`) measures the section's copy and takes the widest grid that fits it, so a phone renders one full-width tile per row. Tile text sits in a `FittedBox(fit: scaleDown)`, and `RenderFittedBox` lays its child out *unbounded* — a column too narrow for the copy never ellipsizes it, it just paints the text smaller (the old 2-column phone grid rendered tile text at 40–70% of its `fontSize`). Type sizes, chrome width and the column floor live in that file; `test/home_tile_layout_test.dart` pins the rule.

## Test harness gotchas

- `tester.pump(Duration(n))` advances the fake clock in a **single** frame. `AnimationController`/countdown sequences need repeated small pumps (16–250 ms) to actually run.
- `rootBundle.loadString` does not resolve asset paths under fake async, so the production deck-load path is not widget-testable — inject decks with `initialCards`.
- mocktail needs `registerFallbackValue` for `SessionRecord` and `ActivityType` when mocking storage/progress.
- Device geometry comes from `tester.view.physicalSize` / `devicePixelRatio` / `padding` / `viewPadding` (`configureDevice` in `test/iphone_landscape_layout_test.dart`); Duo detection is forced with `IPhoneDuoHelper.debugOverride`.

## Deep dives (read only when the task touches them)

- `.agents/skills/listen-repeat-audio/SKILL.md` — 6-source word layout, buffer/starvation/speech-shielding contract, TTS concurrency.
- `.agents/skills/carplay-integration/SKILL.md` — scene gating, 8-item template limit, IPC debouncing, steering-wheel remote commands.
- `.agents/skills/expand-vocabulary/SKILL.md` — inbox → `source.md` → `questions.json` pipeline.

## Verify before finishing

- `flutter test` — all must pass (490 as of Oct 2026) · `flutter analyze` — zero issues · `flutter build ios --no-codesign --simulator` for native changes.
- Run the suite twice when touching flashcards or layout: unseeded deck shuffle and audio pacing are non-deterministic, so one green run proves less than it looks like.
- CarPlay/audio tests need `CarPlayService().resetForTesting()` in `tearDown` (cancels section-update timers, container subscriptions, debounce timestamps).
- Any test that sets `IPhoneDuoHelper.debugOverride` must reset it (`IPhoneDuoHelper.resetForTesting()`, e.g. in `addTearDown`), or the override leaks into later layout tests; also reset `tester.view` size/padding after changing it.
