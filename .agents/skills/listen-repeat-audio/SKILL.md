---
name: listen-repeat-audio
description: Listen & Repeat audio engine contract — 6-source word layout, buffer refill / speech shielding, starvation guards, TTS concurrency, session invalidation. Use for lib/ui/listen_repeat/ and audio gap, stutter, underrun or deck-race bugs.
---

# Listen & Repeat audio engine

Entry point: `lib/ui/listen_repeat/listen_repeat_view_model.dart` (`listenRepeatViewModelProvider`).
Passive training — no speech recognition; the user repeats silently.

## Word = 6 audio sources

`[pt1, silence1 (1.0s), pt2, silence2 (adaptive 0.5–1.5s), en, silence3 (1.0s)]`

- `_kSourcesPerWord = 6`; `index % 6` is odd for silence chunks, even for speech.
- Word-level seek math assumes exactly 6 sources per word (CarPlay / steering-wheel skips use `(wordIndex ± 1) * 6`). Changing the layout requires updating that math in `carplay_service.dart` and `AppDelegate.swift`.
- Files are synthesized on demand to temp files by `TtsService.synthesizeToFile` (pt-PT + en-US), then streamed through a `ConcatenatingAudioSource` owned by `_bgAudioPlayer`.
- Every source needs `MediaItem.copyWith(id: '${item.id}_...')` — required by `just_audio_background`.

## Buffer refill contract (`_syncCurrentIndex`)

- Target: 4 words ahead. Background refill only fires on silence chunks while `remainingWords < 4`.
- Speech shielding: no synthesis / disk I/O / PNG encoding / queue mutation during `pt1`, `pt2`, `en` when `remainingWords >= 2`.
- Emergency starvation guard: `remainingWords <= 2 && sourceInWord >= 4` → refill during speech (needed at 1.25×/1.5× speed), synthesizes 1 word then breaks.
- Post-starvation recovery: if `remaining <= 1`, the loop rebuilds up to 2 words max per pass; 200ms yield between syntheses.
- App resume (`didChangeAppLifecycleState.resumed`): audio stopped/paused → `forceRefill` bypasses shielding (max 2 words); audio playing (CarPlay streaming) → shielding stays to avoid stutter.

## Concurrency & state safety

- "Latest request wins": `_runStartLoop` + `_sessionId` invalidation abort in-flight builds; every async loop re-checks `sessionId == _sessionId`.
- `_generationFuture` mutex: one deck build / synthesis at a time. `_fillingSessionId` prevents overlapping refill passes.
- Poison pill: an item failing synthesis twice is added to `_failedItemIds` and skipped; 6 consecutive failures aborts the session with `_reportFailure`.
- `_bgAudioPlayer.play()` is fired un-awaited so it never blocks word skipping.

## Progress rules

Mode switch and reshuffle use `recordProgress: false` + `_sessionWordsOffset` cache; only explicit session stop records progress (single XP award).

## Testing

`test/listen_repeat_*_test.dart` covers buffer timing, failure states, remote control, orientation/Duo. Keep timing constants in tests and code in sync — tests assert on the 6-source layout and refill thresholds.
