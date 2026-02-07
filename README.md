# language_trainer

A Flutter-based language learning application designed to help users practice and improve their language skills through interactive exercises, quizzes, and audio-based learning activities.

## Features

- Interactive vocabulary and quiz exercises
- Voice recognition and text-to-speech functionality
- Multiple language learning units with structured exercises
- Local data storage using Hive for offline access
- Cross-platform compatibility (iOS, Android, Web)
- CarPlay support for automotive environments
- Modern UI with animations and responsive design

## Project Structure

```
language_trainer/
├── lib/
│   ├── main.dart                 # Entry point
│   ├── services/                 # Business logic services
│   │   ├── voice_quiz_service.dart
│   │   ├── storage_service.dart
│   │   ├── carplay_service.dart
│   │   ├── tts_service.dart
│   │   ├── quiz_engine_service.dart
│   │   └── question_loader_service.dart
│   ├── ui/                       # User interface components
│   │   └── vocabulary/
│   │       └── vocabulary_list_screen.dart
│   ├── models/                   # Data models
│   │   ├── question.dart
│   │   └── language_item.dart
│   └── utils/                    # Utility functions
│       └── logger.dart
├── assets/                       # Static assets
│   ├── data/                     # Exercise and question data
│   │   ├── exercises/
│   │   └── questions.json
│   └── images/                   # Image assets
├── scripts/                      # Data processing scripts
├── android/                      # Android specific files
├── ios/                          # iOS specific files
└── web/                          # Web specific files
```

## Technologies

- Flutter SDK
- Dart programming language
- Hive for local data storage
- flutter_tts for text-to-speech
- speech_to_text for voice recognition
- flutter_riverpod for state management
- google_fonts for typography
- flutter_card_swiper for interactive UI components

## Getting Started

1. Clone the repository
2. Install dependencies: `flutter pub get`
3. Run the application: `flutter run`

## Data Sources

The application uses structured data files including:
- JSON files containing exercises and questions for different language units
- RTF files with language learning content
- Markdown files with source materials and documentation