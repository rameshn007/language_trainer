import 'package:flutter/material.dart';

/// Renders the 6-person present tense verb conjugation table matching
/// the back face of European Portuguese flashcards.
class ConjugationTableWidget extends StatelessWidget {
  final Map<String, String> conjugations;
  final Color accentColor;
  final VoidCallback? onSpeak;
  final bool isSpeaking;

  const ConjugationTableWidget({
    super.key,
    required this.conjugations,
    this.accentColor = const Color(0xFF0288D1),
    this.onSpeak,
    this.isSpeaking = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final eu = conjugations['eu'] ?? '';
    final tu = conjugations['tu'] ?? '';
    final ele = conjugations['ele_ela_voce'] ?? conjugations['ele'] ?? '';
    final nos = conjugations['nos'] ?? '';
    final voces = conjugations['voces_eles'] ?? conjugations['voces'] ?? conjugations['eles'] ?? '';

    if (eu.isEmpty && tu.isEmpty && ele.isEmpty && nos.isEmpty && voces.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.22),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.grid_view_rounded,
                    size: 16,
                    color: accentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Presente do Indicativo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (onSpeak != null)
                IconButton(
                  icon: Icon(
                    isSpeaking
                        ? Icons.volume_up_rounded
                        : Icons.volume_up_outlined,
                    size: 18,
                    color: accentColor,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Listen to conjugations',
                  onPressed: onSpeak,
                ),
            ],
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Singular Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCell('Eu', eu, isDark, accentColor),
                      const SizedBox(height: 8),
                      _buildCell('Tu', tu, isDark, accentColor),
                      const SizedBox(height: 8),
                      _buildCell('Ele/Ela', ele, isDark, accentColor),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  color: theme.dividerColor.withValues(alpha: 0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                ),
                // Plural Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCell('Nós', nos, isDark, accentColor),
                      const SizedBox(height: 8),
                      _buildCell('Eles/Vocês', voces, isDark, accentColor),
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

  Widget _buildCell(String pronoun, String form, bool isDark, Color accentColor) {
    if (form.trim().isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          pronoun,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : Colors.black54,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            form,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
