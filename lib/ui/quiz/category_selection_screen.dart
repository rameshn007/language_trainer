import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import '../../utils/iphone_duo_helper.dart';
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
    'Hobbies & Leisure',
    'Office & Work',
    'General',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final crossAxisCount = isLandscape ? 4 : 3;
    final safePadding = IPhoneDuoHelper.getContentHorizontalPadding(context);
    final horizontalPad = math.max(12.0, isLandscape ? safePadding.left : 12.0);
    final rightPad = math.max(12.0, isLandscape ? safePadding.right : 12.0);

    return Scaffold(
      appBar: AppBar(title: const Text('Select Category'), centerTitle: true),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontalPad, 12.0, rightPad, 12.0),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: isLandscape ? 1.35 : 1.02,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return FadeInUp(
                duration: const Duration(milliseconds: 300),
                delay: Duration(milliseconds: index * 40),
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
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.deepPurple.shade900, Colors.deepPurple.shade800]
                  : [Colors.deepPurple.shade100, Colors.deepPurple.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getIconForCategory(category),
                  size: isLandscape ? 30 : 28,
                  color: fgColor,
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: fgColor,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
      case 'Hobbies & Leisure':
        return Icons.sports_tennis;
      case 'Office & Work':
        return Icons.work_outline;
      case 'General':
        return Icons.grid_view;
      default:
        return Icons.all_inclusive;
    }
  }
}
