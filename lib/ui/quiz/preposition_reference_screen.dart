import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import '../../main.dart';

class PrepositionReferenceScreen extends ConsumerWidget {
  const PrepositionReferenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsService = ref.read(ttsServiceProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prepositions Reference'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              child: _ReferenceSection(
                title: 'Preposição "a"',
                color: Colors.blue,
                combinations: [
                  {'formula': 'a + o', 'result': 'ao'},
                  {'formula': 'a + a', 'result': 'à'},
                  {'formula': 'a + os', 'result': 'aos'},
                  {'formula': 'a + as', 'result': 'às'},
                ],
                rules: [
                  {'context': 'horas', 'example': 'Ele sai às 17:00.'},
                  {'context': 'partes do dia', 'example': 'À noite, ele ouve música.'},
                  {'context': 'dias da semana (rotinas)', 'example': 'À segunda-feira, ele tem aula de português.'},
                ],
                ttsService: ttsService,
              ),
            ),
            const SizedBox(height: 24),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: _ReferenceSection(
                title: 'Preposição "de"',
                color: Colors.orange,
                combinations: [
                  {'formula': 'de + o', 'result': 'do'},
                  {'formula': 'de + a', 'result': 'da'},
                  {'formula': 'de + os', 'result': 'dos'},
                  {'formula': 'de + as', 'result': 'das'},
                ],
                rules: [
                  {'context': 'partes do dia', 'example': 'Ao sábado de manhã, a Joana tem aula de ballet mas, de tarde, sai com os amigos.'},
                  {'context': 'horas + partes do dia', 'example': 'Ele chega às cinco da tarde.'},
                ],
                ttsService: ttsService,
              ),
            ),
            const SizedBox(height: 24),
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: _ReferenceSection(
                title: 'Preposição "em"',
                color: Colors.green,
                combinations: [
                  {'formula': 'em + o', 'result': 'no'},
                  {'formula': 'em + a', 'result': 'na'},
                  {'formula': 'em + os', 'result': 'nos'},
                  {'formula': 'em + as', 'result': 'nas'},
                ],
                rules: [
                  {'context': 'dias da semana (ações pontuais)', 'example': 'No domingo, vamos ao Porto?'},
                ],
                ttsService: ttsService,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceSection extends StatelessWidget {
  final String title;
  final Color color;
  final List<Map<String, String>> combinations;
  final List<Map<String, String>> rules;
  final dynamic ttsService;

  const _ReferenceSection({
    required this.title,
    required this.color,
    required this.combinations,
    required this.rules,
    required this.ttsService,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: color.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Combinations grid
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: combinations.map((combo) => _CombinationChip(
                    formula: combo['formula']!,
                    result: combo['result']!,
                    color: color,
                  )).toList(),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                // Rules table
                ...rules.map((rule) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    onTap: () => ttsService.speak(rule['example']!, language: 'pt'),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            rule['context']!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.outline,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: Text(
                            rule['example']!,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(Icons.volume_up, size: 18, color: color.withValues(alpha: 0.5)),
                      ],
                    ),
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CombinationChip extends StatelessWidget {
  final String formula;
  final String result;
  final Color color;

  const _CombinationChip({
    required this.formula,
    required this.result,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formula,
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(width: 6),
          const Text('=', style: TextStyle(color: Colors.grey)),
          const SizedBox(width: 6),
          Text(
            result,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
