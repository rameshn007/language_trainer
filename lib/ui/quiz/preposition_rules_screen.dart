import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

class PrepositionRulesScreen extends StatelessWidget {
  const PrepositionRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preposition Rules'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            FadeInDown(
              child: const Text(
                'Portuguese Preposition Usage',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            FadeInDown(
              delay: const Duration(milliseconds: 100),
              child: Text(
                'A quick guide to when and how to use common prepositions.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: _buildRulesTable(context),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesTable(BuildContext context) {
    final List<_RuleEntry> rules = [
      _RuleEntry(
        'a',
        'At (specific time/hours), to (direction or movement), to (indirect object).',
      ),
      _RuleEntry(
        'ao / à',
        'At the / to the. Used when combined with masculine (o) or feminine (a) articles.',
      ),
      _RuleEntry(
        'de',
        'Of, from (origin), by (possession), or about (subject).',
      ),
      _RuleEntry(
        'do / da',
        'Of the / from the. Used when combined with masculine (o) or feminine (a) articles.',
      ),
      _RuleEntry(
        'em',
        'In, on, at. Used for general location or position in space and time.',
      ),
      _RuleEntry(
        'no / na',
        'In the / on the / at the. Used for specific location with articles.',
      ),
      _RuleEntry(
        'por',
        'For (duration), through, by, across, via. Expresses cause, motive, or route.',
      ),
      _RuleEntry('pelo / pela', 'By the / through the. (por + o/a)'),
      _RuleEntry(
        'para',
        'For (purpose), to (final destination), towards. Expresses intent or target.',
      ),
      _RuleEntry('com', 'With. Accompaniment or instrument.'),
      _RuleEntry('sem', 'Without. Absence of something.'),
      _RuleEntry('sob', 'Under, beneath.'),
      _RuleEntry('sobre', 'On, over, about (concerning).'),
      _RuleEntry('entre', 'Between, among.'),
      _RuleEntry('desde', 'Since, from (starting point in time or space).'),
      _RuleEntry('até', 'Until, up to, as far as.'),
    ];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Preposition',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    'Usage / Explanation',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...rules.asMap().entries.map((entry) {
            final rule = entry.value;
            final isLast = entry.key == rules.length - 1;
            return Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: isLast
                      ? BorderSide.none
                      : BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.1),
                        ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      rule.prep,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: Text(
                      rule.explanation,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RuleEntry {
  final String prep;
  final String explanation;

  const _RuleEntry(this.prep, this.explanation);
}
