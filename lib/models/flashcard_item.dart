import 'package:flutter/material.dart';

/// Represents a flashcard item matching the visual and pedagogical structure
/// of the Portuguese Flashcard deck.
class FlashcardItem {
  final String id;
  final String cardNumber; // e.g. "#1", "#G1"
  final String portuguese;
  final String english;
  final String category; // e.g. "VERBS", "FOOD", "EXPLANATION"
  final String? pronunciation;
  final String? wordType;
  final String? cefrLevel;
  final String? gender;
  final String? plural;
  final String? examplePt;
  final String? exampleEn;
  final Map<String, String>? presentTense;
  final String? grammarExplanation;
  final bool isGrammarCard;
  final String? languageItemId;

  const FlashcardItem({
    required this.id,
    required this.cardNumber,
    required this.portuguese,
    required this.english,
    required this.category,
    this.pronunciation,
    this.wordType,
    this.cefrLevel,
    this.gender,
    this.plural,
    this.examplePt,
    this.exampleEn,
    this.presentTense,
    this.grammarExplanation,
    this.isGrammarCard = false,
    this.languageItemId,
  });

  /// Category badge color matching the PDF deck styling.
  Color get categoryColor {
    switch (category.toUpperCase()) {
      case 'VERBS':
        return const Color(0xFF0288D1); // Vibrant Sky Blue
      case 'FOOD':
        return const Color(0xFFEF6C00); // Warm Orange
      case 'HOME':
        return const Color(0xFF2E7D32); // Forest Green
      case 'PEOPLE':
        return const Color(0xFFE53935); // Coral Red
      case 'PLACES':
        return const Color(0xFF00897B); // Teal
      case 'TIME':
        return const Color(0xFF7B1FA2); // Purple / Violet
      case 'NUMBERS':
        return const Color(0xFFE65100); // Amber Gold
      case 'PRONOUNS':
        return const Color(0xFFD81B60); // Vibrant Pink
      case 'EXPLANATION':
        return const Color(0xFF1E3A5F); // Deep Navy
      case 'GRAMMAR':
        return const Color(0xFF3949AB); // Indigo Blue
      case 'GENERAL':
      default:
        return const Color(0xFF546E7A); // Slate Grey
    }
  }

  /// Category icon for UI badges.
  IconData get categoryIcon {
    switch (category.toUpperCase()) {
      case 'VERBS':
        return Icons.directions_run_rounded;
      case 'FOOD':
        return Icons.restaurant_rounded;
      case 'HOME':
        return Icons.home_rounded;
      case 'PEOPLE':
        return Icons.people_alt_rounded;
      case 'PLACES':
        return Icons.location_on_rounded;
      case 'TIME':
        return Icons.access_time_filled_rounded;
      case 'NUMBERS':
        return Icons.pin_rounded;
      case 'PRONOUNS':
        return Icons.person_pin_rounded;
      case 'EXPLANATION':
      case 'GRAMMAR':
        return Icons.menu_book_rounded;
      case 'GENERAL':
      default:
        return Icons.category_rounded;
    }
  }

  /// Formatted phonetic display (bracketed e.g. [SAIR]).
  String? get formattedPronunciation {
    if (pronunciation == null || pronunciation!.trim().isEmpty) return null;
    final clean = pronunciation!.trim();
    if (clean.startsWith('[') && clean.endsWith(']')) return clean;
    return '[$clean]';
  }

  /// Subtitle details for back of card (e.g. "Type: noun | Masculine").
  String get typeDetailsString {
    final parts = <String>[];
    if (wordType != null && wordType!.isNotEmpty) {
      parts.add('Type: $wordType');
    }
    if (gender != null && gender!.isNotEmpty) {
      final capitalizedGender =
          gender![0].toUpperCase() + gender!.substring(1);
      parts.add(capitalizedGender);
    }
    return parts.join(' | ');
  }

  /// Construct from vocabulary.json item.
  factory FlashcardItem.fromVocabJson(Map<String, dynamic> json) {
    final dynamic rawId = json['id'];
    final String cardId = rawId != null ? rawId.toString() : '${json.hashCode}';
    final String cardNumber = rawId != null ? '#$rawId' : '#';
    final String? languageItemId = rawId != null ? 'vocab_$rawId' : null;

    // Normalize topic category to PDF category if possible
    String category = _deriveCategory(json);

    // Extract present tense conjugation if available
    Map<String, String>? tenseMap;
    if (json['present_tense'] is Map) {
      tenseMap = (json['present_tense'] as Map).map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } else if (json['present_eu'] != null) {
      tenseMap = {
        'eu': json['present_eu']?.toString() ?? '',
        'tu': json['present_tu']?.toString() ?? '',
        'ele_ela_voce': json['present_ele']?.toString() ?? '',
        'nos': json['present_nos']?.toString() ?? '',
        'voces_eles': json['present_voces']?.toString() ?? '',
      };
    }

    return FlashcardItem(
      id: cardId,
      cardNumber: cardNumber,
      portuguese: json['portuguese']?.toString() ?? '',
      english: json['english']?.toString() ?? '',
      category: category,
      pronunciation: json['pronunciation']?.toString(),
      wordType: json['word_type']?.toString(),
      cefrLevel: json['cefr_level']?.toString(),
      gender: json['gender']?.toString(),
      plural: json['plural']?.toString(),
      examplePt: json['example_sentence_pt']?.toString(),
      exampleEn: json['example_sentence_en']?.toString(),
      presentTense: tenseMap,
      isGrammarCard: false,
      languageItemId: languageItemId,
    );
  }

  /// Construct from grammar_flashcards.json item.
  factory FlashcardItem.fromGrammarJson(Map<String, dynamic> json) {
    final String id = json['id']?.toString() ?? 'G';
    return FlashcardItem(
      id: id,
      cardNumber: json['card_number']?.toString() ?? '#$id',
      portuguese: json['portuguese']?.toString() ?? '',
      english: json['english']?.toString() ?? '',
      category: json['category']?.toString() ?? 'EXPLANATION',
      pronunciation: json['pronunciation']?.toString(),
      wordType: json['word_type']?.toString() ?? 'grammar',
      cefrLevel: json['cefr_level']?.toString() ?? 'A1',
      grammarExplanation: json['explanation']?.toString(),
      isGrammarCard: true,
      languageItemId: null,
    );
  }

  /// Map raw JSON properties to the 11 PDF categories.
  static String _deriveCategory(Map<String, dynamic> json) {
    final wordType = (json['word_type'] ?? '').toString().toLowerCase();
    final rawCat = (json['topic_category'] ?? '').toString().toLowerCase();

    if (wordType == 'verb' || rawCat.contains('verb')) {
      return 'VERBS';
    }
    if (wordType == 'number' || rawCat.contains('number')) {
      return 'NUMBERS';
    }
    if (wordType == 'pronoun' || rawCat.contains('pronoun')) {
      return 'PRONOUNS';
    }
    if (rawCat.contains('food') || rawCat.contains('drink')) {
      return 'FOOD';
    }
    if (rawCat.contains('home') || rawCat.contains('house')) {
      return 'HOME';
    }
    if (rawCat.contains('people') ||
        rawCat.contains('family') ||
        rawCat.contains('social')) {
      return 'PEOPLE';
    }
    if (rawCat.contains('place') ||
        rawCat.contains('city') ||
        rawCat.contains('geography') ||
        rawCat.contains('countries')) {
      return 'PLACES';
    }
    if (rawCat.contains('time') || rawCat.contains('calendar')) {
      return 'TIME';
    }
    if (rawCat.contains('grammar') || wordType == 'conjunction') {
      return 'GRAMMAR';
    }

    return 'GENERAL';
  }
}
