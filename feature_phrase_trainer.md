# Feature: Phrase Trainer Mode

## Overview
A new training mode that displays random Portuguese phrases with their English translations, allowing users to listen to the pronunciation and navigate through phrases.

## Purpose
- Provide a focused phrase-based learning experience alongside existing word-based training
- Allow users to practice listening comprehension of common Portuguese phrases
- Reuse existing TTS and navigation patterns for consistency

## Implementation Plan

### 1. New Screen: PhraseTrainerScreen
- **File**: `lib/ui/phrase_trainer_screen.dart`
- **Purpose**: Display phrases with audio playback controls
- **Key Features**:
  - Portuguese phrase display (large text)
  - English translation below the phrase
  - Play button for TTS audio
  - Next/Previous navigation buttons
  - Speed control indicator

### 2. Navigation Integration
- Add new button in `HomeScreen` (similar to Voice Trainer)
- Update bottom action buttons section in home screen

### 3. Data Considerations
**Options**:
1. **Extend LanguageItem Model**:
   - Add support for phrases alongside existing words
   - Pros: Reuses existing data storage and management
   - Cons: Requires model changes, potential impact on existing functionality

2. **Separate Phrase Data**:
   - Create `assets/data/phrases.json` with Portuguese-English pairs
   - Pros: Clean separation, no impact on existing vocabulary system
   - Cons: Additional data file to maintain

3. **Tag-Based Approach**:
   - Use existing vocabulary items but tag certain words as phrases
   - Pros: No new data structure needed
   - Cons: Less flexible for actual phrases (multi-word expressions)

**Recommended**: Option 2 (Separate Phrase Data) for initial implementation to avoid impacting the existing vocabulary system.

### 4. Technical Implementation
- **TTS Service**: Reuse existing `TtsService`
- **Navigation**: Follow same pattern as other screens using MaterialPageRoute
- **State Management**: Use Riverpod (consistent with app)
- **UI Components**: Reuse existing patterns from VoiceTrainerScreen and VocabularyListScreen

### 5. User Experience
- Simple, focused interface:
  - Portuguese phrase at top (large text)
  - English translation below
  - Play button centered below translation
  - Next/Previous buttons at bottom
  - Speed control in AppBar or as FAB

- Navigation flow:
  1. User taps "Phrase Trainer" from home screen
  2. System loads random set of phrases (20-30 items)
  3. Display first phrase with translation
  4. User can:
     - Tap play to hear Portuguese pronunciation
     - Use next/previous buttons to navigate
     - Adjust TTS speed if needed

### 6. Required Changes
1. **New Screen Implementation**
   - Create `PhraseTrainerScreen` with similar structure to `VoiceTrainerScreen`
   - Implement phrase navigation logic
   - Add TTS playback controls

2. **Home Screen Updates**
   - Add new button in bottom action buttons section
   - Update navigation route

3. **Data Loading**
   - Create or extend data loading mechanism for phrases
   - Consider integrating with existing storage service if using separate data

4. **TTS Service Integration**
   - Ensure consistent speed control across all TTS usages

### 7. Potential Enhancements (Future Work)
- Phrase favorites system
- Phrase-based quiz mode (translate English to Portuguese)
- Progress tracking for phrases
- Randomized phrase selection with difficulty levels

## Open Questions
1. Should phrases be loaded from a separate JSON file or integrated with existing vocabulary items?
2. Should we implement any specific phrase categorization (e.g., common travel phrases)?
3. What should the default number of phrases per session be?
4. Should we add any additional controls (e.g., loop mode, shuffle option)?

## Dependencies
- Existing TTS service (`lib/services/tts_service.dart`)
- Storage service for phrase persistence if needed
- Riverpod state management
- Material design components

## Estimated Complexity
- **UI Implementation**: Medium (reuses existing patterns)
- **Data Handling**: Low to Medium (depends on data approach)
- **Integration**: Low (follows established navigation patterns)

This feature can be implemented in parallel with other development work and follows the established architecture patterns of the application.