import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';

class InterrogativeReferenceScreen extends ConsumerWidget {
  const InterrogativeReferenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsService = ref.read(ttsServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final referenceData = [
      {'pt': 'O que', 'en': 'What', 'note': 'Standard form'},
      {'pt': 'Que', 'en': 'What', 'note': 'Short form, often before nouns'},
      {'pt': 'O que é que', 'en': 'What', 'note': 'Emphatic form (common in Portugal)'},
      {'pt': 'Qual', 'en': 'Which / What', 'note': 'Singular'},
      {'pt': 'Quais', 'en': 'Which / What', 'note': 'Plural'},
      {'pt': 'Quanto', 'en': 'How much', 'note': 'Masculine Singular'},
      {'pt': 'Quanta', 'en': 'How much', 'note': 'Feminine Singular'},
      {'pt': 'Quantos', 'en': 'How many', 'note': 'Masculine Plural'},
      {'pt': 'Quantas', 'en': 'How many', 'note': 'Feminine Plural'},
      {'pt': 'Quem', 'en': 'Who', 'note': ''},
      {'pt': 'De quem', 'en': 'Whose', 'note': 'Literally "Of whom"'},
      {'pt': 'Onde', 'en': 'Where', 'note': 'At a place (static)'},
      {'pt': 'Aonde', 'en': 'Where', 'note': 'To a place (motion)'},
      {'pt': 'Donde', 'en': 'Where', 'note': 'From a place (origin)'},
      {'pt': 'Por que', 'en': 'Why', 'note': 'Standard question form'},
      {'pt': 'Por quê', 'en': 'Why', 'note': 'Used at the end of a sentence'},
      {'pt': 'Como', 'en': 'How', 'note': ''},
      {'pt': 'Quando', 'en': 'When', 'note': ''},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Interrogative Words'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: isDark ? Colors.white10 : Colors.grey.shade100,
              child: const Row(
                children: [
                  Expanded(flex: 15, child: Text('Portuguese', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey))),
                  Expanded(flex: 10, child: Text('English', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey))),
                  Expanded(flex: 15, child: Text('Usage / Note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey))),
                ],
              ),
            ),
            ...referenceData.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isEven = index % 2 == 0;
              final ptColor = isDark ? Colors.cyan.shade200 : Colors.cyan.shade800;

              return InkWell(
                onTap: () => ttsService.speak(item['pt']!, language: 'pt'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isEven 
                        ? Colors.transparent 
                        : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.cyan.withValues(alpha: 0.03)),
                    border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade100)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 15,
                        child: Text(
                          item['pt']!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 17, 
                            color: ptColor,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 10,
                        child: Text(
                          item['en']!,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      Expanded(
                        flex: 15,
                        child: Text(
                          item['note']!,
                          style: TextStyle(
                            fontSize: 13, 
                            color: colorScheme.outline,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.volume_up, 
                        size: 20, 
                        color: ptColor.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
