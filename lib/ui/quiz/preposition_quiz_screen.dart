import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'quiz_screen.dart';
import 'preposition_reference_screen.dart';

class PrepositionQuizScreen extends ConsumerWidget {
  const PrepositionQuizScreen({super.key});

  static const List<_PrepositionCategory> _categories = [
    _PrepositionCategory(
      label: 'All Mixed',
      subtitle: 'Tudo misturado',
      icon: Icons.shuffle,
      filter: null,
      color: Colors.deepPurple,
    ),
    _PrepositionCategory(
      label: 'Preposição A',
      subtitle: 'ao, à, aos, às',
      icon: Icons.access_time,
      filter: 'preposition_a',
      color: Colors.blue,
    ),
    _PrepositionCategory(
      label: 'Preposição DE',
      subtitle: 'do, da, dos, das',
      icon: Icons.wb_sunny_outlined,
      filter: 'preposition_de',
      color: Colors.orange,
    ),
    _PrepositionCategory(
      label: 'Preposição EM',
      subtitle: 'no, na, nos, nas',
      icon: Icons.calendar_today,
      filter: 'preposition_em',
      color: Colors.green,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prepositions Quiz'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_outlined),
            tooltip: 'Reference Table',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrepositionReferenceScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            return FadeInUp(
              duration: const Duration(milliseconds: 300),
              delay: Duration(milliseconds: index * 50),
              child: _CategoryCard(
                category: cat,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizScreen(
                        isPrepositionQuiz: true,
                        category: cat.filter,
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

class _PrepositionCategory {
  final String label;
  final String subtitle;
  final IconData icon;
  final String? filter;
  final MaterialColor color;

  const _PrepositionCategory({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.filter,
    required this.color,
  });
}

class _CategoryCard extends StatelessWidget {
  final _PrepositionCategory category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? category.color[100]! : category.color[900]!;

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
                  ? [category.color[900]!, category.color[800]!]
                  : [category.color[100]!, category.color[50]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, size: 36, color: fgColor),
              const SizedBox(height: 10),
              Text(
                category.label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: fgColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                category.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: fgColor.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
