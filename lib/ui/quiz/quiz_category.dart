import 'package:flutter/material.dart';

/// Single source of truth for quiz category metadata across the app.
class QuizCategoryInfo {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;

  const QuizCategoryInfo({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

/// The 13 topical quiz categories matching `questions.json` `cat` fields.
const List<QuizCategoryInfo> kQuizCategories = [
  QuizCategoryInfo(
    id: 'food_drink',
    name: 'Food & Drink',
    subtitle: 'Meals, dining & ingredients',
    icon: Icons.restaurant,
    color: Colors.deepOrange,
  ),
  QuizCategoryInfo(
    id: 'house_rooms',
    name: 'House & Rooms',
    subtitle: 'Rooms & parts of the home',
    icon: Icons.home_rounded,
    color: Colors.green,
  ),
  QuizCategoryInfo(
    id: 'travel_directions',
    name: 'Travel & Directions',
    subtitle: 'Navigation, transit & places',
    icon: Icons.map,
    color: Colors.teal,
  ),
  QuizCategoryInfo(
    id: 'body_health',
    name: 'Body & Health',
    subtitle: 'Anatomy, symptoms & wellness',
    icon: Icons.health_and_safety_rounded,
    color: Colors.red,
  ),
  QuizCategoryInfo(
    id: 'family',
    name: 'Family',
    subtitle: 'Relatives & relationships',
    icon: Icons.family_restroom,
    color: Colors.purple,
  ),
  QuizCategoryInfo(
    id: 'time_numbers',
    name: 'Time & Numbers',
    subtitle: 'Hours, dates, days & counting',
    icon: Icons.schedule,
    color: Colors.indigo,
  ),
  QuizCategoryInfo(
    id: 'everyday_items',
    name: 'Everyday Items',
    subtitle: 'Objects, clothing & gear',
    icon: Icons.backpack_rounded,
    color: Colors.orange,
  ),
  QuizCategoryInfo(
    id: 'household_items',
    name: 'Household Items',
    subtitle: 'Furniture & appliances',
    icon: Icons.kitchen_rounded,
    color: Colors.cyan,
  ),
  QuizCategoryInfo(
    id: 'office_work',
    name: 'Office & Work',
    subtitle: 'Professions & workplace',
    icon: Icons.work_outline,
    color: Colors.amber,
  ),
  QuizCategoryInfo(
    id: 'hobbies_leisure',
    name: 'Hobbies & Leisure',
    subtitle: 'Sports, music & free time',
    icon: Icons.sports_tennis,
    color: Colors.pink,
  ),
  QuizCategoryInfo(
    id: 'basics',
    name: 'Basics',
    subtitle: 'Greetings & essentials',
    icon: Icons.chat_bubble_outline,
    color: Colors.blue,
  ),
  QuizCategoryInfo(
    id: 'grammar_verbs',
    name: 'Grammar & Verbs',
    subtitle: 'Conjugations & syntax',
    icon: Icons.school,
    color: Colors.deepPurple,
  ),
  QuizCategoryInfo(
    id: 'general',
    name: 'General',
    subtitle: 'Mixed vocabulary questions',
    icon: Icons.grid_view,
    color: Colors.blueGrey,
  ),
];

/// The full list of categories used by [CategorySelectionScreen], starting with 'All'.
List<String> get kAllQuizCategoryNames => [
  'All',
  ...kQuizCategories.map((c) => c.name),
];

/// Helper to get the canonical icon for a category string.
IconData getIconForQuizCategory(String category) {
  if (category == 'All') return Icons.all_inclusive;
  for (final info in kQuizCategories) {
    if (info.name == category) return info.icon;
  }
  return Icons.all_inclusive;
}
