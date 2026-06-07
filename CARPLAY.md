# CarPlay Implementation Plan

## Current Status

### Completed
- ✅ Fixed SceneDelegate.swift to handle CarPlay scenes (added CPTemplateApplicationScene check)
- ✅ Added CarPlay connection status provider
- ✅ Updated CarPlayService with:
  - Connection listener
  - Template management (setRootTemplate for first, push for subsequent)
  - Session state management for resume
  - XP tracking and progress integration
- ✅ Implemented QuizDrillProvider (50% vocab, 30% verb, 20% interrogative)
- ✅ Implemented VerbConjugationDrillProvider
- ✅ Implemented PhraseTrainerDrillProvider
- ✅ Implemented InterrogativeDrillProvider
- ✅ Updated VocabularyFlashcardDrillProvider with XP tracking
- ✅ Added CarPlay connection indicator to HomeScreen (green car icon)
- ✅ All code compiles without errors

### Ready for Testing
- All providers implemented and ready for CarPlay testing
- XP system integrated with storage service
- Session resume support implemented
- Error handling in place

## Implementation Order

### 1. QuizDrillProvider (High Priority) ✅
**File**: `lib/services/carplay/quiz_drill_provider.dart`

**Features**:
- Mix: 50% vocab, 30% verb, 20% interrogative
- Both voice and button input (toggle via CarPlay options)
- Flexible session length (user exits with CarPlay "Back" button)
- XP scoring: 10 XP first attempt, 5 XP retry, 20 XP session completion
- Mastery level updates
- Track overall score (X/Y correct)

**Input Methods**:
1. **Voice Mode**: TTS question → listen for answer → validate with fuzzy matching
2. **Button Mode**: Show question text + 4 options as list items → user taps option → validate → read correct answer in TTS

### 2. VerbConjugationDrillProvider (High Priority) ✅
**File**: `lib/services/carplay/verb_drill_provider.dart`

**Features**:
- Present verb in infinitive or conjugated form
- User must provide correct conjugation
- TTS for Portuguese pronunciation
- Track mastery per verb class

**Question Format**:
```
Question: "Conjugate 'ser' for 'eu'"
Correct Answer: "sou"
Options: ["sou", "é", "somos", "são"]
```

### 3. PhraseTrainerDrillProvider (Medium Priority) ✅
**File**: `lib/services/carplay/phrase_drill_provider.dart`

**Features**:
- Present Portuguese phrase via TTS
- User must say English translation
- Button mode: show phrase + English options
- TTS feedback on correct/incorrect

### 4. InterrogativeDrillProvider (Medium Priority) ✅
**File**: `lib/services/carplay/interrogative_drill_provider.dart`

**Features**:
- Present interrogative question in Portuguese
- User must provide English translation
- TTS for question, voice/button input
- Category-based filtering (who, what, where, when, why, how)

### 5. Update VocabularyFlashcardDrillProvider ✅
**File**: `lib/services/carplay/vocabulary_flashcard_drill_provider.dart`

**Features**:
- Added XP tracking
- Added session completion bonus
- Added mastery level updates
- Added fuzzy matching for voice answers

### 6. Add Resume on Reconnect ✅
**File**: `lib/services/carplay_service.dart`

**Session State**:
- Save: provider ID, current index, score, total, seen question IDs
- On reconnect: show "Resume" option
- If resume selected: continue from last question
- If too long passed (>5 min): start fresh

### 7. Add Error Handling ✅
**File**: `lib/services/carplay_service.dart`, provider files

- Try-catch around `listenForAnswer`
- Show error template if voice fails
- Allow skip/retry on error
- Handle CarPlay disconnection gracefully
- Resume session on reconnection

### 8. Add Completion Summary ✅
**File**: `lib/services/carplay_service.dart`

**Summary Display**:
```
"Session Complete!"
Score: X/Y correct
XP Earned: Z
Mastery: N words advanced
[Restart] [Back to Menu]
```

## Testing Checklist

- [ ] CarPlay shows root menu (Available Drills list)
- [ ] Vocabulary Flashcards work (voice + button)
- [ ] Quiz mode works with mixed questions
- [ ] Verb conjugation works
- [ ] Phrase trainer works
- [ ] Interrogative quiz works
- [ ] XP is tracked correctly
- [ ] Completion summary shows accurate stats
- [ ] Disconnection doesn't crash app
- [ ] Connection status indicator updates
- [ ] Voice recognition error handling works
- [ ] Button input fallback works
- [ ] Resume on reconnect works
- [ ] Session state saves/clears properly

## Key Design Decisions

### Question Selection
- Use unseen-first logic (like app's quiz mode)
- 4 options per question (1 correct, 3 distractors)
- Options shuffled for each question

### Voice Mode
- Speak question via TTS
- Listen for answer with 10-second timeout
- Fuzzy matching (35% error rate via Levenshtein)
- Normalize input (lowercase, trim, remove punctuation)

### Button Mode
- Show question text on first list item
- Show 4 options as subsequent list items
- User taps option to select answer
- If correct: TTS reads correct answer
- If wrong: TTS says "Incorrect. It was [correct answer]"

### XP Awards
- First attempt correct: 10 XP
- Retry correct: 5 XP
- Wrong answer: 0 XP
- Session completion: 20 XP bonus

### Mastery Tracking
- Update mastery level on correct answers
- 3 consecutive correct → advance tier
- Max tier: 4 (Mastered)

## Estimated Total Time

| Task | Time |
|------|------|
| SceneDelegate fix | 30 min |
| Connection status UI | 20 min |
| Template management fix | 45 min |
| QuizDrillProvider | 2-3 hrs |
| VerbConjugationProvider | 1.5 hrs |
| PhraseTrainerProvider | 1 hr |
| InterrogativeProvider | 45 min |
| Update vocab provider | 30 min |
| Resume on reconnect | 1 hr |
| Error handling | 45 min |
| Completion summary | 30 min |
| Testing | 1 hr |
| **Total** | **8-9 hours** |

## Files Created

1. `lib/services/carplay/quiz_drill_provider.dart`
2. `lib/services/carplay/verb_drill_provider.dart`
3. `lib/services/carplay/phrase_drill_provider.dart`
4. `lib/services/carplay/interrogative_drill_provider.dart`

## Files Updated

1. `lib/services/carplay_service.dart` (connection status, template management, session state)
2. `lib/services/carplay/vocabulary_flashcard_drill_provider.dart` (XP tracking)
3. `ios/Runner/AppDelegate.swift` (CarPlay scene handling)
4. `lib/ui/home_screen.dart` (connection status indicator)

## CarPlay Template Structure

```
Root Template (list of providers)
  → Quiz Session (first template)
    → Current Question (text + options)
    → Update via push() for each question
  → Session Summary (final template)
  → Back to Root (when user exits)
```

## Resume Logic

```dart
// On disconnect:
_saveSessionState() → saves to Hive settings

// On reconnect:
_checkForResume() → loads saved state
  - If session exists and fresh (<5 min): show resume
  - If session stale: clear and show root menu

// On resume:
  - Load provider by name
  - Set current index
  - Set score/total
  - Load seen question IDs
  - Continue from last question
```

## Next Steps

1. Test with real CarPlay (simulator or car)
2. Verify all providers work correctly
3. Test voice and button input modes
4. Test XP tracking and mastery updates
5. Test resume on reconnect
6. Test error handling scenarios
