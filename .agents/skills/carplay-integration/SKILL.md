---
name: carplay-integration
description: CarPlay player integration — scene-trigger gating, CPListTemplate 8-row limit, Now Playing star and artwork, section-header IPC debouncing, steering-wheel remote commands, phantom sessions, head-unit stutter, wrong track skip. Use for lib/services/carplay_service.dart, ios/Runner/AppDelegate.swift, in-car dashboard.
---

# CarPlay integration

CarPlay is an in-car player for the shared Listen & Repeat session (no microphone/voice).
Dart: `lib/services/carplay_service.dart` (singleton). Native: `ios/Runner/AppDelegate.swift` — `CarPlaySceneObserver` + `RemoteCommandInterceptor`. Phone-side mirror: `lib/ui/listen_repeat/in_car_dashboard_screen.dart`. History: `docs/carplay_roadmap.md`.

## Scene lifecycle & triggering

- The plugin `connected` event is ambiguous — it fires on a plain cable/dock connect with the dashboard still showing. Never start a session from it.
- Session startup is gated only on the `language_trainer/carplay_scene` channel: a `sceneWillEnterForeground` push or a `sceneStatus` pull (the pull is the cold-start fallback when scene activation races the Dart handler being installed).
- `_onSceneActivated()` dedupes with a 2 s `_lastActivation` window, so the paired triggers for one "driver wants the experience" moment (foreground push + `connected`) start exactly one session.
- `background` (another CarPlay app takes the screen) deliberately keeps playback running — media-app behaviour. Only `disconnected` and the "Stop session" row call `_stopSession()`.
- `_container` / `_storageService` arrive via `init()`; state listening is attached lazily by `_ensureStateListener()` inside `_onSceneActivated()`. Do not attach provider listeners in `init()`.
- The scene channel does not exist on Android or in tests; every `invokeMethod` is wrapped in try/catch so a missing channel degrades to a no-op instead of throwing.

## Head-unit UI compliance

- Player template is a `CPListTemplate` capped at 8 rows in 3 sections: Current Word (now-playing indicator + Flag for Review = 2), Playback (Pause/Resume, Previous word, Next word = 3), Session (Focus cycle, Speed, Stop = 3). Mid-session reshuffle was removed to stay inside Apple's limit.
- Tapping the word row *is* the replay affordance: it pushes `CPNowPlayingTemplate` and calls `replayCurrentWord()`. There is no separate Replay row, and no Shuffle row.
- Focus and Speed rows call `complete()` first and run the work un-awaited. Awaiting a deck rebuild there parks the selection highlight for seconds on a cold cache; the rows refresh reactively from `_onListenRepeatStateChanged`.
- Flag state lives in two places at once — the `CPListItem` row and the Now Playing star button — so every toggle must update both. `onItemFlagToggled()` refreshes the row, then regenerates artwork via `DynamicArtService.generateWordArt` and pushes `updateNowPlayingStar(isFlagged, artPath:)`; if artwork generation throws it still pushes the star with no `artPath`. A flag toggle that only touches the list row leaves a stale star on the dash.
- Stop session returns to the Study Focus menu (`_showMainMenu`), which lists `ListenRepeatMode.values` with live counts from `listenRepeatContentServiceProvider.getModeCounts()`; `_resetPlayer()` runs first.
- On word change: row titles/subtitles (`_wordItem.update()`, `_flagItem.update()`) and now-playing metadata update immediately; the full `template.updateSections(...)` IPC is debounced by a 250 ms single-flight timer (`_pendingSectionUpdateTimer`). That debounce also coalesces rapid remote skips; a transient "new word title under the `#N-1` header" inside the 250 ms window is accepted to protect main-thread audio.
- `resetForTesting()` and `_resetPlayer()` must cancel any pending `_pendingSectionUpdateTimer`.

## Remote commands (`RemoteCommandInterceptor` in AppDelegate.swift)

- Exist because default next/previous track steps land on silence chunks.
- Hooks `MPRemoteCommandCenter` next/previous/skipForward/skipBackward, and replaces `AudioServicePlugin`'s `nextTrack:`, `previousTrack:`, `skipForward:`, `skipBackward:` through the ObjC runtime, so the plugin re-registering itself cannot route around the interceptor. Missing class or missing track selectors trip `assertionFailure`/`assert` in DEBUG — loud in debug, silent in release, so a `just_audio_background` upgrade that renames those selectors needs a simulator pass.
- Native only dispatches `remoteNextWord` / `remotePreviousWord` / `remoteToggleFlag` over the scene channel; all arithmetic is Dart-side.
- Dart debounces per direction with `_lastRemoteNextTime` / `_lastRemotePreviousTime` (300 ms), so a rapid direction reversal still registers.
- Remote handlers route through `_container.read(listenRepeatViewModelProvider...)`; when `_container` is null the command is dropped without a trace, and the flag path additionally needs `_storageService`.
- `remoteNextWord` / `remotePreviousWord` call the view model's `nextWord()` / `previousWord()`, which seek `(wordIndex ± 1) * _kSourcesPerWord` (6). Changing the word layout is a Dart-side change plus the literals listed in the audio skill; nothing here computes a source index.

## Testing

`test/listen_repeat_remote_control_test.dart` drives the real channel — it encodes `MethodCall`s onto `language_trainer/carplay_scene` and asserts the resulting seek/`play()` — so the Dart half of the remote path is covered without a simulator. Also `test/carplay_*_test.dart` and `test/in_car_dashboard_test.dart`. `tearDown` must call `CarPlayService().resetForTesting()` (cancels section-update timers, container subscriptions, debounce timestamps).
Nothing automated covers `AppDelegate.swift` (swizzling, star button, artwork): check with `flutter build ios --no-codesign --simulator`, then a simulator pass over Control Center and steering-wheel skips.
