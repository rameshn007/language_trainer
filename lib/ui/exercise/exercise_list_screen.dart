import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'exercise_screen.dart';
import '../vocabulary/vocabulary_list_screen.dart';

class ExerciseListScreen extends StatelessWidget {
  const ExerciseListScreen({super.key});

  final List<Map<String, String>> units = const [
    {
      'title': 'Unit 2: Irregular Verbs (Part 1)',
      'subtitle': 'Presente do Indicativo: Sentir, Dormir, etc.',
      'path': 'assets/data/exercises/unit_2.json',
      'hintPath': 'assets/images/unit_2_hint.png',
      'icon': 'school',
    },
    {
      'title': 'Unit 3: Verbo Ser',
      'subtitle': 'Identity vs Location (Ser vs Ficar)',
      'path': 'assets/data/exercises/unit_3.json',
      'hintPath': 'assets/images/unit_3_hint.png',
      'icon': 'person',
    },
    {
      'title': 'Unit 4: Irregular Verbs (Part 2)',
      'subtitle': 'Ter, Ver, Fazer, Dizer, etc.',
      'path': 'assets/data/exercises/unit_4.json',
      'hintPath': 'assets/images/unit_4_hint.png',
      'icon': 'build',
    },
    {
      'title': 'Unit 5: Regular Verbs',
      'subtitle': 'Presente do Indicativo: -ar, -er, -ir',
      'path': 'assets/data/exercises/unit_5.json',
      'hintPath': 'assets/images/unit_5_hint.png',
      'icon': 'chat',
    },
    {
      'title': 'Unit 6: New Vocabulary',
      'subtitle': 'Practice new vocabulary from new.md',
      'path': 'assets/data/exercises/unit_6.json',
      'icon': 'book',
    },
    {
      'title': 'Unit 7: Even More Vocabulary',
      'subtitle': 'Practice new vocabulary from Even_More_words.md',
      'path': 'assets/data/exercises/unit_7.json',
      'icon': 'book',
    },
    {
      'title': 'Unit 8: Monday Mar 9 Vocabulary',
      'subtitle':
          'Practice new words and related phrases from mon_mar_9_words.md',
      'path': 'assets/data/exercises/unit_8.json',
      'icon': 'book',
    },
    {
      'title': 'Verb Conjugation Quiz',
      'subtitle': '50 questions to test your verb conjugation skills',
      'path': 'assets/data/exercises/verb_conjugation_50.json',
      'icon': 'school',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercises'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'vocabulary') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VocabularyListScreen(),
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) {
              return const [
                PopupMenuItem<String>(
                  value: 'vocabulary',
                  child: Text('Vocabulary'),
                ),
              ];
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: units.length,
        itemBuilder: (context, index) {
          final unit = units[index];
          return FadeInUp(
            duration: const Duration(milliseconds: 300),
            delay: Duration(milliseconds: index * 100),
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(
                    _getIcon(unit['icon']!),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  unit['title']!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(unit['subtitle']!),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExerciseScreen(
                        unitName: unit['title']!,
                        unitPath: unit['path']!,
                        hintPath: unit['hintPath'],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'school':
        return Icons.school;
      case 'person':
        return Icons.person;
      case 'build':
        return Icons.build;
      case 'chat':
        return Icons.chat_bubble_outline;
      default:
        return Icons.book;
    }
  }
}
