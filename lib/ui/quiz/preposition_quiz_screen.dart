import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'quiz_screen.dart';
import 'preposition_reference_screen.dart';
import 'preposition_rules_screen.dart';

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
        title: const Text('Prepositions'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _StudyButton(
                    label: 'Study Table',
                    icon: Icons.table_chart_outlined,
                    color: Colors.pink,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PrepositionReferenceScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StudyButton(
                    label: 'Usage Rules',
                    icon: Icons.rule_rounded,
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PrepositionRulesScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Practice Quizzes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16.0),
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
        ],
      ),
    );
  }
}

class _StudyButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StudyButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
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
