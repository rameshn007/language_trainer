import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'quiz_screen.dart';
import 'interrogative_reference_screen.dart';

class InterrogativeQuizScreen extends ConsumerWidget {
  const InterrogativeQuizScreen({super.key});

  static const List<_InterrogativeCategory> _categories = [
    _InterrogativeCategory(
      label: 'All Mixed',
      subtitle: 'Tudo misturado',
      icon: Icons.shuffle,
      filter: null,
    ),
    _InterrogativeCategory(
      label: 'O que',
      subtitle: 'What',
      icon: Icons.help_outline,
      filter: 'what',
    ),
    _InterrogativeCategory(
      label: 'Por que',
      subtitle: 'Why',
      icon: Icons.psychology,
      filter: 'why',
    ),
    _InterrogativeCategory(
      label: 'Quem',
      subtitle: 'Who',
      icon: Icons.person_search,
      filter: 'who',
    ),
    _InterrogativeCategory(
      label: 'Quando',
      subtitle: 'When',
      icon: Icons.schedule,
      filter: 'when',
    ),
    _InterrogativeCategory(
      label: 'Onde',
      subtitle: 'Where',
      icon: Icons.place,
      filter: 'where',
    ),
    _InterrogativeCategory(
      label: 'Como',
      subtitle: 'How',
      icon: Icons.build_outlined,
      filter: 'how',
    ),
    _InterrogativeCategory(
      label: 'Qual',
      subtitle: 'Which',
      icon: Icons.compare_arrows,
      filter: 'which',
    ),
    _InterrogativeCategory(
      label: 'Quanto',
      subtitle: 'How much / many',
      icon: Icons.payments,
      filter: 'how_much',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interrogatives'),
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
                    label: 'Reference Table',
                    icon: Icons.table_chart_outlined,
                    color: Colors.cyan,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const InterrogativeReferenceScreen()),
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
                  child: _InterrogativeCard(
                    category: cat,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuizScreen(
                            isInterrogativeQuiz: true,
                            interrogativeCategory: cat.filter,
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

class _InterrogativeCategory {
  final String label;
  final String subtitle;
  final IconData icon;
  final String? filter;

  const _InterrogativeCategory({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.filter,
  });
}

class _InterrogativeCard extends StatelessWidget {
  final _InterrogativeCategory category;
  final VoidCallback onTap;

  const _InterrogativeCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? Colors.cyan.shade100 : Colors.cyan.shade900;

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
                  ? [Colors.cyan.shade900, Colors.cyan.shade800]
                  : [Colors.cyan.shade100, Colors.cyan.shade50],
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
