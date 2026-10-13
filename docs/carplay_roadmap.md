# CarPlay Listen & Repeat Roadmap & Implementation Plan

This document records the phased design history of the **Listen & Repeat CarPlay integration** and the phases still open (6-8). It is a record of what was decided, not the live contract: the audio-word layout, buffer/refill contract and TTS concurrency rules are specified in `.agents/skills/listen-repeat-audio/SKILL.md`, and the CarPlay surface (scene gating, 8-row template limit, IPC debouncing, remote commands) in `.agents/skills/carplay-integration/SKILL.md`. Read those first when implementing.

> **Audio layout:** the shipped word layout is **6 sources** — `[pt1, silence1, pt2, silence2, en, silence3]`, `_kSourcesPerWord = 6` in `lib/ui/listen_repeat/listen_repeat_view_model.dart`. The 5-source layout described under Phase 2 is what existed *before* that phase shipped, and the repeated Portuguese added afterwards is what made it 6. Do not implement against the numbers below.
>
> Nothing outside the view model computes a source index: `carplay_service.dart` forwards remote skips to `nextWord()` / `previousWord()`, and `AppDelegate.swift` only fires `remoteNextWord` / `remotePreviousWord` (its "6 audio sources" text is a doc comment). A layout change therefore means: the constant + the `assert` in `_generateNextWordSequence`, the odd-is-silence rule, `test/listen_repeat_remote_control_test.dart` (`expect(sources.length, 6)`, `seek(Duration.zero, index: 6)`), that Swift doc block, and `.agents/skills/listen-repeat-audio/SKILL.md`.

---


| Phase | Feature | Status | Description | Primary Files |
| :--- | :--- | :---: | :--- | :--- |
| **Phase 1** | **Mode & Focus Selection** | ✅ **Merged** (PR #27) | Select Verbs, Prepositions, Phrases, Vocab, or Balanced Mix from CarPlay menu & switch focus mid-session. | `carplay_service.dart`, `listen_repeat_view_model.dart`, `listen_repeat_content_service.dart` |
| **Phase 2** | **Steering Wheel & Native Media Controls** | ✅ **Merged** (PR #28) | Fix 5-source skip glitch so physical steering wheel buttons, Control Center, and Lock Screen skip full words instead of silence chunks. | `AppDelegate.swift`, `carplay_service.dart`, `listen_repeat_view_model.dart` |
| **Phase 3** | **Glanceable Word Context & Dynamic Artwork** | ✅ **Completed** | Display `item.notes` (grammar/tenses) on CarPlay row, show word counter `#X`, and add notes badge to album art. | `carplay_service.dart`, `dynamic_art_service.dart` |
| **Phase 4** | **In-Car "Flag for Review" / Starred Words** | ✅ **Merged** (PR #30) | One-tap button on CarPlay to bookmark difficult words while driving for later review on phone. | `carplay_service.dart`, `storage_service.dart`, `listen_repeat_screen.dart` |
| **Phase 5** | **Brand-Spec UX & Native Now Playing Integration** | ✅ **Completed** | Automatic navigation to CPNowPlayingTemplate with high-fidelity flashcard art (steel-blue halo), native Now Playing Star button, Practice Sets, and In-Car Dashboard. | `AppDelegate.swift`, `carplay_service.dart`, `dynamic_art_service.dart`, `in_car_dashboard_screen.dart` |
| **Phase 6** | **Commute Rewards & Post-Session XP Summary** | ⏳ Planned | Show completion alert on session stop with words completed and XP earned; display drive stats on menu. | `carplay_service.dart`, `listen_repeat_view_model.dart` |
| **Phase 7** | **Active Recall & Repetition Modes** | ⏳ Planned | Optional "Active Recall" mode (EN prompt -> recall PT -> PT confirmation) and "Double Listen" for noisy commutes. | `listen_repeat_view_model.dart`, `carplay_service.dart` |
| **Phase 8** | **HIG Layout & In-Car Error Recovery** | ⏳ Planned | Streamline list layout for driving safety; add one-tap "Try Again" item on CarPlay when TTS fails. | `carplay_service.dart` |

---

## Phase Details

### Phase 1: Mode & Focus Selection from CarPlay ✅ (Merged)
- **Problem**: CarPlay always started in `ListenRepeatMode.all`. When stopping, the main menu only had one generic button. No way to select Verbs, Prepositions, Phrases, or Vocabulary from the dash.
- **Solution**:
  - Main menu provides a dedicated "Study Focus" section with all 5 modes and descriptive subtitles.
  - Player template features a dedicated "Focus: [Badge]" row that cycles through modes on tap.
  - Mode switches serialize cleanly with a "latest request wins" runner, preserving words seen across switches and avoiding duplicate XP farming.
  - Player controls strictly capped at 8 rows across 3 sections for head unit compliance.

---

### Phase 2: Steering Wheel & Native Media Controls ✅ (Merged)
#### Problem
Each word then contained 5 audio sources (`PT`, `silence1`, `silence2`, `EN`, `silence3`) inside a `ConcatenatingAudioSource`; the repeated PT added afterwards makes the shipped layout 6 (see the note at the top of this file).
When the driver presses ⏭️ (Next Track) or ⏮️ (Previous Track) on physical steering wheel controls, iOS invokes `seekToNext()` / `seekToPrevious()` on the playlist, advancing only by 1 silence chunk rather than skipping to the next full word.

#### Technical Design & Architecture
1. **Native Remote Command Interceptor (`ios/Runner/AppDelegate.swift`):**
   - In `CarPlaySceneObserver` or `AppDelegate.swift`, register custom handlers on `MPRemoteCommandCenter.shared()` for `nextTrackCommand` and `previousTrackCommand`.
   - Instead of letting `just_audio_background` perform default single-source track seeking, intercept the commands and invoke a method channel call to Dart:
     ```swift
     let commandCenter = MPRemoteCommandCenter.shared()
     commandCenter.nextTrackCommand.addTarget { [weak self] _ in
         self?.channel?.invokeMethod("remoteNextWord", arguments: nil)
         return .success
     }
     commandCenter.previousTrackCommand.addTarget { [weak self] _ in
         self?.channel?.invokeMethod("remotePreviousWord", arguments: nil)
         return .success
     }
     ```
2. **Dart Method Channel Handling (`lib/services/carplay_service.dart`):**
   - In `_onSceneChannelCall`, handle `remoteNextWord` and `remotePreviousWord`:
     ```dart
     if (call.method == 'remoteNextWord') {
       container?.read(listenRepeatViewModelProvider.notifier).nextWord();
     } else if (call.method == 'remotePreviousWord') {
       container?.read(listenRepeatViewModelProvider.notifier).previousWord();
     }
     ```
3. **Word Skip Logic (`lib/ui/listen_repeat/listen_repeat_view_model.dart`):**
   - Ensure `nextWord()` and `previousWord()` seek by a whole word: `(currentWordIndex ± 1) * _kSourcesPerWord`. The constant's value at the time was 5; read the live value from `listen_repeat_view_model.dart` (now 6) before touching any of this math.
   - If `nextWord()` reaches the end of the playlist, ensure it appends the next word sequence before seeking so the driver never hits a dead end.
4. **Verification:**
   - Test Control Center / Lock Screen / Steering Wheel remote commands in iOS Simulator.
   - Verify pressing Next advances by **1 full word** (`_kSourcesPerWord` sources, now 6), never landing on a silence track.

---

### Phase 3: Glanceable Word Context & Dynamic Artwork ✅ (Completed)
#### Problem
- In the mobile UI, words display grammar/tense pills from `item.notes` (e.g. `Preterite Perfect - Eu`, `Preposition + article`). On CarPlay, `item.notes` is completely hidden.
- The CarPlay player does not display session progress (e.g. "Word 12").
- In `DynamicArtService`, text can clip on long sentences and lacks grammar pills.

#### Technical Design
1. **CarPlay Row Formatting:**
   - In `_showPlayer` and `_onListenRepeatStateChanged`:
     ```dart
     final grammarNote = item.notes.isNotEmpty ? '  •  [${item.notes}]' : '';
     wordItem.setDetailText('${item.english}$grammarNote');
     ```
2. **Live Word Counter:**
   - Section header in `_playerTemplate`:
     `CPListSection(header: 'Current Word (#${state.totalWordsSeen})', items: [wordItem])`.
3. **Enhanced Dynamic Word Art (`dynamic_art_service.dart`):**
   - Compute dynamic font size: scale down font size if `item.portuguese.length > 25` (from 80 to 52) to avoid clipping.
   - If `item.notes.isNotEmpty`, draw a rounded pill badge with dark-blue background and subtle white text above the Portuguese word.

---

### Phase 4: In-Car "Flag for Review" / Starred Words
#### Problem
Drivers who encounter a difficult conjugation or unfamiliar phrase while driving have no way to mark it for later study without touching their phone.

#### Technical Design
1. **Storage Service Support (`storage_service.dart`):**
   - Add methods to `StorageService`:
     ```dart
     bool isItemFlagged(String itemId);
     Future<bool> toggleItemFlagged(String itemId);
     List<LanguageItem> getFlaggedItems();
     ```
   - Persist flagged item IDs in `_settingsBox` under key `'flagged_item_ids'`.
2. **CarPlay List Item:**
   - Add `CPListItem` under the Current Word section:
     - Text: `isFlagged ? '★ Flagged for Review' : '☆ Flag for Review'`
     - DetailText: `'Save to study later on phone'`
     - OnPress: toggles flagged state, updates item text dynamically with immediate visual confirmation.
3. **Mobile Screen Filter:**
   - Add a "Flagged Words" option or banner on `ListenRepeatScreen` / vocabulary lists so the user can easily review items flagged while driving.

---

### Phase 6: Commute Rewards & Post-Session XP Summary
#### Problem
When the driver taps "Stop session", the CarPlay screen resets to the main menu without feedback on words reviewed or XP earned.

#### Technical Design
1. **Track Last Session Stats in `CarPlayService`:**
   - Capture `xp` and `state.totalWordsSeen` when stopping a session.
2. **Post-Session Alert / Menu Summary:**
   - Display a `CPAlertTemplate` via `FlutterCarplay.showAlert`:
     - Title: `'Commute Session Complete! 🎉'`
     - Message: `'Completed $words words\nEarned +$xp XP'`
     - Action: `'Done'`
   - On the Main Menu:
     Add a `"Recent Drive"` section:
     `"Last Drive: $words words completed (+${xp} XP)"` with streak information.

---

### Phase 7: Driving Pedagogy Modes: Active Recall & Double Listen
#### Problem
Commutes often have background road noise making a single pass hard to hear. Furthermore, some learners want active recall (English prompt first -> recall Portuguese before speaker reveals it).

#### Technical Design
1. **Extend `ListenRepeatState`:**
   - Add `ListenRepeatOrder order = ListenRepeatOrder.targetFirst` (`targetFirst`, `promptFirst`).
   - Add `bool doubleListen = false`.
2. **Audio Sequence Generation (`listen_repeat_view_model.dart`):**
   - Read this phase carefully: the shipped layout is *already* Double Listen — `[pt1, silence1, pt2, silence2, en, silence3]` plays Portuguese twice before the English prompt. The "Standard / Double Listen" pair below is the 5-source-era draft, kept for provenance.
   - The live delta is ordering: `promptFirst` = `[EN prompt -> pause to recall -> PT (x2 with the repetition pause) -> pause]`, plus whatever `doubleListen` means once doubled-PT is the default.
   - Any change here moves `_kSourcesPerWord` and the `index % 6` odd-is-silence rule; see the file header for everything that has to move with it.
3. **CarPlay Setting Item:**
   - Add a toggle or cycling item under Session controls in CarPlay.

---

### Phase 8: Apple CarPlay HIG Layout Streamlining & In-Car Error Recovery
#### Problem
- ~~Redundant items~~ — resolved: the Replay and Shuffle rows are gone, and tapping the word row replays (`replayCurrentWord()`) while pushing `CPNowPlayingTemplate`.
- If TTS fails, the driver cannot retry from CarPlay.

#### Technical Design
1. **Streamlined Player Template:** — shipped, this is exactly the current 8-row layout:
   - Section 1: Current Word & Flag Action (2 items)
   - Section 2: Playback (Pause/Resume, Previous word, Next word — 3 items)
   - Section 3: Session (Focus, Speed, Stop — 3 items)
   Remaining here is only the accepted trade-offs: the 250 ms `updateSections` debounce and the resulting `#N-1` section-header lag.
2. **In-Car Error Recovery:**
   - When `state.failure != null`, dynamically inject a `"Try Again"` `CPListItem` with detail text `'Tap to retry speech synthesis'` that calls `notifier.startSession()`.
