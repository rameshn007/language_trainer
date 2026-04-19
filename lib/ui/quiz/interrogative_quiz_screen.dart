import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'quiz_screen.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_outlined),
            tooltip: 'Reference Table',
            onPressed: () => _showReferenceTable(context),
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
    );
  }

  void _showReferenceTable(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const referenceData = [
      {'pt': 'O que', 'en': 'What', 'example': 'O que é isso?'},
      {'pt': 'Por que / Porquê', 'en': 'Why', 'example': 'Por que você está triste?'},
      {'pt': 'Quem', 'en': 'Who', 'example': 'Quem é ela?'},
      {'pt': 'Quando', 'en': 'When', 'example': 'Quando é o seu aniversário?'},
      {'pt': 'Onde', 'en': 'Where', 'example': 'Onde fica a estação?'},
      {'pt': 'Como', 'en': 'How', 'example': 'Como você está?'},
      {'pt': 'Qual / Quais', 'en': 'Which / What', 'example': 'Qual é o seu favorito?'},
      {'pt': 'Quanto(a)', 'en': 'How much', 'example': 'Quanto custa isto?'},
      {'pt': 'Quantos(as)', 'en': 'How many', 'example': 'Quantos anos você tem?'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    'Interrogative Words',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Palavras Interrogativas',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: referenceData.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: isDark ? Colors.white12 : Colors.grey.shade200,
                      ),
                      itemBuilder: (context, index) {
                        final item = referenceData[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['pt']!,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.cyan.shade200
                                            : Colors.cyan.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['example']!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  item['en']!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
