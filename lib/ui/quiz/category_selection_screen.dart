import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'quiz_screen.dart';

class CategorySelectionScreen extends ConsumerWidget {
  const CategorySelectionScreen({super.key});

  final List<String> categories = const [
    'All',
    'Basics',
    'Family',
    'Food & Drink',
    'Travel & Directions',
    'Time & Numbers',
    'Grammar & Verbs',
    'General',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Category'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return FadeInUp(
              duration: const Duration(milliseconds: 300),
              delay: Duration(milliseconds: index * 50),
              child: _CategoryCard(
                category: category,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizScreen(
                        category: category == 'All' ? null : category,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? Colors.deepPurple.shade100 : Colors.deepPurple;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.deepPurple.shade900, Colors.deepPurple.shade800]
                  : [Colors.deepPurple.shade100, Colors.deepPurple.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getIconForCategory(category), size: 40, color: fgColor),
              const SizedBox(height: 12),
              Text(
                category,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: fgColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Basics':
        return Icons.chat_bubble_outline;
      case 'Family':
        return Icons.family_restroom;
      case 'Food & Drink':
        return Icons.restaurant;
      case 'Travel & Directions':
        return Icons.map;
      case 'Time & Numbers':
        return Icons.schedule;
      case 'Grammar & Verbs':
        return Icons.school;
      case 'General':
        return Icons.grid_view;
      default:
        return Icons.all_inclusive;
    }
  }
}
