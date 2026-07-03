import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';

class GrammarReferenceScreen extends ConsumerWidget {
  const GrammarReferenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsService = ref.read(ttsServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grammar Reference'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PronounsSection(ttsService: ttsService),
            const SizedBox(height: 24),
            _PresentContinuousSection(ttsService: ttsService),
            const SizedBox(height: 24),
            _RegularVerbsSection(ttsService: ttsService),
            const SizedBox(height: 24),
            _PronounPlacementSection(ttsService: ttsService),
            const SizedBox(height: 24),
            _ContractionsSection(ttsService: ttsService),
            const SizedBox(height: 24),
            _GenderPluralSection(ttsService: ttsService),
            const SizedBox(height: 24),
            _IrregularPresentSection(ttsService: ttsService),
            const SizedBox(height: 24),
            _IrregularPastSection(ttsService: ttsService),
          ],
        ),
      ),
    );
  }
}

class _PronounsSection extends StatelessWidget {
  final dynamic ttsService;
  const _PronounsSection({required this.ttsService});

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
            color: Colors.blue.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '1. Pronouns & The Formality Spectrum',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _pronounRow('Eu', 'I', 'Always used', context, ttsService),
                _pronounRow('Tu', 'You (informal)', 'Friends, family, colleagues of similar age', context, ttsService),
                _pronounRow('Você', 'You (semi-formal)', 'Caution: Often considered blunt or slightly rude in Portugal', context, ttsService),
                _pronounRow('O senhor / A senhora', 'You (formal)', 'Older people, strangers, formal service encounters', context, ttsService),
                _pronounRow('Ele / Ela', 'He / She', '3rd person singular', context, ttsService),
                _pronounRow('Nós', 'We', 'Standard for "we" (pt-PT rarely uses "a gente" formally)', context, ttsService),
                _pronounRow('Eles / Elas', 'They', '3rd person plural', context, ttsService),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pronounRow(String pronoun, String meaning, String usage, BuildContext context, dynamic ttsService) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              pronoun,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meaning,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  usage,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PresentContinuousSection extends StatelessWidget {
  final dynamic ttsService;
  const _PresentContinuousSection({required this.ttsService});

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
            color: Colors.green.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '2. Present Continuous (European Portuguese)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Golden Rule:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Estar (conjugated) + a + Infinitive Verb',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _exampleRow('Eu estou a comer', 'I am eating', context, ttsService),
                _exampleRow('Ela está a trabalhar', 'She is working', context, ttsService),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 20, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Never "estou comendo" (that\'s Brazilian Portuguese)',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _exampleRow(String pt, String en, BuildContext context, dynamic ttsService) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => ttsService.speak(pt, language: 'pt'),
        child: Row(
          children: [
            Icon(Icons.volume_up, size: 18, color: Colors.green.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Expanded(child: Text('$pt — $en', style: const TextStyle(fontSize: 15))),
          ],
        ),
      ),
    );
  }
}

class _RegularVerbsSection extends StatelessWidget {
  final dynamic ttsService;
  const _RegularVerbsSection({required this.ttsService});

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
            color: Colors.orange.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.format_list_bulleted, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '3. Regular Present Tense Verbs',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _verbTableHeader(context),
                const SizedBox(height: 4),
                _verbRow('Eu', 'falo (-ar)', 'como (-er)', 'parto (-ir)', context),
                _verbRow('Tu', 'falas', 'comes', 'partes', context),
                _verbRow('Ele/Ela/Senhor', 'fala', 'come', 'parte', context),
                _verbRow('Nós', 'falamos', 'comemos', 'partimos', context),
                _verbRow('Eles/Elas/Senhores', 'falam', 'comem', 'partem', context),
                const SizedBox(height: 12),
                Text(
                  'Examples: falar (to speak), comer (to eat), partir (to leave)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _verbTableHeader(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text('Subject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Theme.of(context).colorScheme.outline))),
        const SizedBox(width: 12),
        Expanded(child: Text('-AR (Falar)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange))),
        const SizedBox(width: 12),
        Expanded(child: Text('-ER (Comer)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange))),
        const SizedBox(width: 12),
        Expanded(child: Text('-IR (Partir)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange))),
      ],
    );
  }

  Widget _verbRow(String subject, String ar, String er, String ir, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(subject, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          const SizedBox(width: 12),
          Expanded(child: Text(ar, style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 12),
          Expanded(child: Text(er, style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 12),
          Expanded(child: Text(ir, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _PronounPlacementSection extends StatelessWidget {
  final dynamic ttsService;
  const _PronounPlacementSection({required this.ttsService});

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
            color: Colors.purple.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.swap_horiz, color: Colors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '4. Pronoun Placement (The Hyphen Rule)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'Default (Enclisis): Pronoun attaches to the END of the verb with a hyphen',
                    style: TextStyle(fontSize: 14, color: Colors.purple.shade700),
                  ),
                ),
                const SizedBox(height: 12),
                _exampleRow('Chamo-me João.', 'I call myself João.', context, ttsService),
                _exampleRow('Dá-me o livro.', 'Give me the book.', context, ttsService),
                const SizedBox(height: 16),
                Text(
                  'Exceptions (Proclisis) — pronoun jumps BEFORE the verb:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _exceptionRow('Negative words', 'Não me chamo João.', context, ttsService),
                _exceptionRow('Question words', 'Como te chamas?', context, ttsService),
                _exceptionRow('Certain adverbs', 'Já me disseste.', context, ttsService),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _exampleRow(String pt, String en, BuildContext context, dynamic ttsService) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => ttsService.speak(pt, language: 'pt'),
        child: Row(
          children: [
            Icon(Icons.volume_up, size: 18, color: Colors.purple.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Expanded(child: Text('$pt — $en', style: const TextStyle(fontSize: 14))),
          ],
        ),
      ),
    );
  }

  Widget _exceptionRow(String condition, String example, BuildContext context, dynamic ttsService) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
            ),
            child: Text(
              condition,
              style: TextStyle(fontSize: 11, color: Colors.red.shade700),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: InkWell(
              onTap: () => ttsService.speak(example, language: 'pt'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volume_up, size: 14, color: Colors.red.withValues(alpha: 0.4)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(example, style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractionsSection extends StatelessWidget {
  final dynamic ttsService;
  const _ContractionsSection({required this.ttsService});

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
            color: Colors.teal.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.merge_type, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '5. Mandatory Preposition Contractions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _contractionGroup('De (of/from)', [
                  {'formula': 'de + o', 'result': 'do', 'example': 'O livro do João'},
                  {'formula': 'de + a', 'result': 'da', 'example': 'A casa da mãe'},
                ], context, ttsService),
                const SizedBox(height: 16),
                _contractionGroup('Em (in/on/at)', [
                  {'formula': 'em + o', 'result': 'no', 'example': 'Moro no Porto'},
                  {'formula': 'em + a', 'result': 'na', 'example': 'Moro na cidade'},
                ], context, ttsService),
                const SizedBox(height: 16),
                _contractionGroup('A (to/at)', [
                  {'formula': 'a + o', 'result': 'ao', 'example': 'Vou ao mercado'},
                  {'formula': 'a + a', 'result': 'à', 'example': 'Vou à escola'},
                ], context, ttsService),
                const SizedBox(height: 16),
                _contractionGroup('Por (by/for)', [
                  {'formula': 'por + o', 'result': 'pelo', 'example': 'Vou pelo parque'},
                  {'formula': 'por + a', 'result': 'pela', 'example': 'Vou pela praia'},
                ], context, ttsService),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contractionGroup(String title, List<Map<String, String>> items, BuildContext context, dynamic ttsService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => _contractionRow(
          item['formula']!,
          item['result']!,
          item['example']!,
          context,
          ttsService,
        )),
      ],
    );
  }

  Widget _contractionRow(String formula, String result, String example, BuildContext context, dynamic ttsService) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(formula, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          const Text('=', style: TextStyle(color: Colors.grey)),
          const SizedBox(width: 8),
          Text(
            result,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: InkWell(
              onTap: () => ttsService.speak(example, language: 'pt'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volume_up, size: 14, color: Colors.teal.withValues(alpha: 0.4)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(example, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderPluralSection extends StatelessWidget {
  final dynamic ttsService;
  const _GenderPluralSection({required this.ttsService});

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
            color: Colors.amber.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.category, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '6. Gender & Plural Basics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gender',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Words ending in -o → usually masculine',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Words ending in -ção, -dade → usually feminine',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plurals',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.purple),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Words ending in a vowel → add -s',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Words ending in -m → change -m to -ns',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _exampleRow('um homem → uns homens', '-m changes to -ns', context, ttsService),
                _exampleRow('um livro → livros', 'add -s to vowel-ending words', context, ttsService),
                _exampleRow('a cidade → as cidades', '-dade is feminine, add -s', context, ttsService),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _exampleRow(String pt, String note, BuildContext context, dynamic ttsService) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => ttsService.speak(pt.split('→').first.trim(), language: 'pt'),
        child: Row(
          children: [
            Icon(Icons.volume_up, size: 18, color: Colors.amber.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Expanded(child: Text(pt, style: const TextStyle(fontSize: 14))),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                note,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IrregularPresentSection extends StatelessWidget {
  final dynamic ttsService;
  const _IrregularPresentSection({required this.ttsService});

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
            color: Colors.deepPurple.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.star_outline, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '7. Irregular Verbs — Present Tense',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _verbConjugationTable(
                  context: context,
                  title: 'Ser (to be - permanent) / Estar (to be - temp) / Ter (to have) / Ir (to go) / Fazer (to do/make)',
                  pronouns: ['Eu', 'Tu', 'Ele/Ela/Senhor', 'Nós', 'Eles/Elas/Senhores'],
                  conjugations: [
                    ['sou', 'estou', 'tenho', 'vou', 'faço'],
                    ['és', 'estás', 'tens', 'vais', 'fazas'],
                    ['é', 'está', 'tem', 'vai', 'faz'],
                    ['somos', 'estamos', 'temos', 'vamos', 'fazemos'],
                    ['são', 'estão', 'têm', 'vão', 'fazem'],
                  ],
                  colors: [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ser vs Estar',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ser = Permanent / Identity (origin, profession, traits, time)',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        'Estar = Temporary / State / Location (location, emotions, weather, present continuous)',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.cyan.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ter (Hidden Uses)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.cyan),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Age: Tenho 40 anos. = I am 40 years old',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        'Obligation: Tenho de ir. = I have to go (use "ter de", not "ter que" in Portugal)',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.pink.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.pink.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Near Future Hack: Ir + Infinitive',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.pink),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => ttsService.speak('Vou cozinhar.', language: 'pt'),
                        child: Row(
                          children: [
                            Icon(Icons.volume_up, size: 14, color: Colors.pink.withValues(alpha: 0.5)),
                            const SizedBox(width: 4),
                            Expanded(child: Text('Vou cozinhar. = I am going to cook', style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fazer (Weather/Time)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => ttsService.speak('Faz sol.', language: 'pt'),
                        child: Row(
                          children: [
                            Icon(Icons.volume_up, size: 14, color: Colors.red.withValues(alpha: 0.5)),
                            const SizedBox(width: 4),
                            Expanded(child: Text('Faz sol. = It\'s sunny', style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => ttsService.speak('Faz dois anos que moro aqui.', language: 'pt'),
                        child: Row(
                          children: [
                            Icon(Icons.volume_up, size: 14, color: Colors.red.withValues(alpha: 0.5)),
                            const SizedBox(width: 4),
                            Expanded(child: Text('Faz dois anos que moro aqui. = It\'s been two years...', style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.record_voice_over, size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pronunciation Tip: "têm" (they have) sounds like nasal "tãym" vs "tem" (he has) sounds like nasal "tãing". The circumflex makes the difference!',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _verbConjugationTable({
    required BuildContext context,
    required String title,
    required List<String> pronouns,
    required List<List<String>> conjugations,
    required List<Color> colors,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 8),
        // Header row
        Row(
          children: [
            SizedBox(width: 80, child: Text('Pronoun', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Theme.of(context).colorScheme.outline))),
            const SizedBox(width: 6),
            Expanded(child: Text('Ser', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colors[0]), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            Expanded(child: Text('Estar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colors[1]), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            Expanded(child: Text('Ter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colors[2]), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            Expanded(child: Text('Ir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colors[3]), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            Expanded(child: Text('Fazer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: colors[4]), overflow: TextOverflow.ellipsis)),
          ],
        ),
        const Divider(height: 20),
        // Data rows
        ...List.generate(pronouns.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(width: 80, child: Text(pronouns[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                const SizedBox(width: 6),
                Expanded(child: Text(conjugations[i][0], style: TextStyle(fontSize: 12, color: colors[0]), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Expanded(child: Text(conjugations[i][1], style: TextStyle(fontSize: 12, color: colors[1]), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Expanded(child: Text(conjugations[i][2], style: TextStyle(fontSize: 12, color: colors[2]), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Expanded(child: Text(conjugations[i][3], style: TextStyle(fontSize: 12, color: colors[3]), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Expanded(child: Text(conjugations[i][4], style: TextStyle(fontSize: 12, color: colors[4]), overflow: TextOverflow.ellipsis)),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _IrregularPastSection extends StatelessWidget {
  final dynamic ttsService;
  const _IrregularPastSection({required this.ttsService});

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
            color: Colors.indigo.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.history, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '8. Irregular Verbs — Simple Past (Pretérito Perfeito)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'Use for completed actions in the past with a clear beginning and end.',
                    style: TextStyle(fontSize: 14, color: Colors.indigo.shade700),
                  ),
                ),
                const SizedBox(height: 12),
                _pastTenseTable(
                  context: context,
                  title: 'Ser / Ir (To be / To go) — share the SAME conjugations',
                  pronouns: ['Eu', 'Tu', 'Ele/Ela/Senhor', 'Nós', 'Eles/Elas/Senhores'],
                  conjugations: ['fui', 'foste', 'foi', 'fomos', 'foram'],
                  color: Colors.blue,
                ),
                const SizedBox(height: 12),
                _pastTenseTable(
                  context: context,
                  title: 'Estar (To be - temporary)',
                  pronouns: ['Eu', 'Tu', 'Ele/Ela/Senhor', 'Nós', 'Eles/Elas/Senhores'],
                  conjugations: ['estive', 'estiveste', 'esteve', 'estivemos', 'estiveram'],
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                _pastTenseTable(
                  context: context,
                  title: 'Ter (To have)',
                  pronouns: ['Eu', 'Tu', 'Ele/Ela/Senhor', 'Nós', 'Eles/Elas/Senhores'],
                  conjugations: ['tive', 'tiveste', 'teve', 'tivemos', 'tiveram'],
                  color: Colors.orange,
                ),
                const SizedBox(height: 12),
                _pastTenseTable(
                  context: context,
                  title: 'Fazer (To do/make)',
                  pronouns: ['Eu', 'Tu', 'Ele/Ela/Senhor', 'Nós', 'Eles/Elas/Senhores'],
                  conjugations: ['fiz', 'fizeste', 'fez', 'fizemos', 'fizeram'],
                  color: Colors.purple,
                ),
                const SizedBox(height: 16),
                _exampleRow('O jantar foi excelente.', 'The dinner was excellent. (ser - past)', context, ttsService),
                _exampleRow('Ela foi a Lisboa ontem.', 'She went to Lisbon yesterday. (ir - past)', context, ttsService),
                _exampleRow('Onde é que estiveste?', 'Where were you? (estar - past)', context, ttsService),
                _exampleRow('Ontem o meu filho teve febre.', 'Yesterday my son had a fever. (ter - past)', context, ttsService),
                _exampleRow('O que é que fizeste?', 'What did you do? (fazer - past)', context, ttsService),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.record_voice_over, size: 20, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'European Portuguese Pronunciation: The "e" at the end of "tu" conjugations (foste, estiveste, tiveste, fizeste) is almost entirely swallowed or silent in Portugal. The "s" before "t" sounds like an English "sh" (fosh-te, shtivesh-te, fihzesh-te).',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pastTenseTable({
    required BuildContext context,
    required String title,
    required List<String> pronouns,
    required List<String> conjugations,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(5, (i) {
            return Expanded(
              child: Column(
                children: [
                  Text(
                    pronouns[i],
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      conjugations[i],
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _exampleRow(String pt, String en, BuildContext context, dynamic ttsService) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => ttsService.speak(pt, language: 'pt'),
        child: Row(
          children: [
            Icon(Icons.volume_up, size: 18, color: Colors.indigo.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Expanded(child: Text(pt, style: const TextStyle(fontSize: 14))),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                en,
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
