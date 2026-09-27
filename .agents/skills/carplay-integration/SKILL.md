---
name: carplay-integration
description: CarPlay player integration — scene-trigger gating, CPListTemplate 8-item limit, section-header IPC debouncing, steering-wheel remote commands, test teardown. Use for lib/services/carplay_service.dart, ios/Runner/AppDelegate.swift, in-car dashboard, phantom sessions, head-unit stutter, wrong track skip.
---

# CarPlay integration

CarPlay is an in-car player for the shared Listen & Repeat session (no microphone/voice).
Dart: `lib/services/carplay_service.dart`. Native: `ios/Runner/AppDelegate.swift`. Roadmap/history: `docs/carplay_roadmap.md`.

## Scene lifecycle & triggering

- The plugin `connected` event is ambiguous — it fires on a plain cable connect. Never start a session from it.
- Session startup is gated only on the `language_trainer/carplay_scene` channel: `sceneWillEnterForeground` push or `sceneStatus` pull (`CarPlaySceneObserver`).
- State listening via `_ensureStateListener()` is lazy — do not attach provider listeners in `init()`.

## Head-unit UI compliance

- Player template is a `CPListTemplate` capped at 8 items in 3 sections: Current Word (now-playing indicator + Flag for Review = 2), Playback controls (3), Session controls (Focus cycle, Speed, Stop = 3). Mid-session reshuffle was removed to stay inside Apple's 8-item limit.
- Stop session returns to the Study Focus menu (Balanced Mix, Verbs, Prepositions, Phrases, Vocabulary).
- On word change: row titles/subtitles (`_wordItem.update()`, `_flagItem.update()`) and now-playing metadata update immediately; full `template.updateSections(...)` IPC is debounced by a 250ms single-flight timer (`_pendingSectionUpdateTimer`).
- That debounce coalesces rapid remote skips (300ms steering-wheel debounce) so multi-section payloads don't stack. Live references hold current item state across the delay; a transient "new word title with `#N-1` header" during the 250ms window is accepted to protect main-thread audio.
- `resetForTesting()` and `_resetPlayer()` must cancel any pending `_pendingSectionUpdateTimer`.

## Remote commands (`RemoteCommandInterceptor` in AppDelegate.swift)

- Exists because default next/previous track steps land on silence chunks.
- Swizzles `AudioServicePlugin` `nextTrack:`, `previousTrack:`, `skipForward:`, `skipBackward:` and hooks `MPRemoteCommandCenter.shared()`.
- Dispatches `remoteNextWord` / `remotePreviousWord` to Dart, which seeks by 6 sources per word — `(currentWordIndex ± 1) * 6` — landing directly on Portuguese audio.
- Dart debounces per direction with `_lastRemoteNextTime` / `_lastRemotePreviousTime` (300ms), so rapid direction reversals still register.

## Testing

`test/carplay_*_test.dart`, `test/in_car_dashboard_test.dart`. `tearDown` must call `CarPlayService().resetForTesting()`. iOS check: `flutter build ios --no-codesign --simulator`.
