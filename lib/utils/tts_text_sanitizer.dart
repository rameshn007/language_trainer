class TtsTextSanitizer {
  /// Sanitizes Portuguese text before passing it to the TTS synthesizer.
  static String sanitizePt(String text) {
    if (text.isEmpty) return '';

    String cleaned = text;

    // Remove markdown escapes (e.g. \-, \+, \*, \_)
    cleaned = cleaned.replaceAllMapped(RegExp(r'\\([+\-*_\[\]()])'), (m) => m[1]!);

    // Remove grammatical gender/number abbreviations in parentheses, e.g. (m.), (f.), (pl.)
    cleaned = cleaned.replaceAll(
      RegExp(r'\((m|f|pl|sing|prep|adj|adv|v)\.?\)', caseSensitive: false),
      '',
    );

    // Replace slashes between alternatives with ' ou ' (e.g., 'cá/lá' -> 'cá ou lá')
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([^\s/,()]+)\s*/\s*([^\s/,()]+)'),
      (m) => '${m[1]} ou ${m[2]}',
    );

    // Remove remaining brackets and parenthesis contents if they look like notes
    cleaned = cleaned.replaceAll(RegExp(r'\[.*?\]'), '');

    // Normalize multiple spaces and punctuation
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  /// Sanitizes English text before passing it to the TTS synthesizer.
  static String sanitizeEn(String text) {
    if (text.isEmpty) return '';

    String cleaned = text;

    // Remove markdown escapes
    cleaned = cleaned.replaceAllMapped(RegExp(r'\\([+\-*_\[\]()])'), (m) => m[1]!);

    // Replace literal escaped dashes or pluses with commas or clean separators
    cleaned = cleaned.replaceAll(RegExp(r'\s*-\s*used to indicate\b', caseSensitive: false), ', used to indicate');
    cleaned = cleaned.replaceAll(RegExp(r'\s*-\s*indicates\b', caseSensitive: false), ', indicates');

    // Strip explanatory parentheticals at the end of definitions
    // e.g. "inheritors (receive inheritance)" -> "inheritors"
    // "since (specific with hour, year)" -> "since"
    cleaned = cleaned.replaceAll(RegExp(r'\s*\([^)]*\)'), '');

    // Strip bracket notations like [nome] or [verb]
    cleaned = cleaned.replaceAll(RegExp(r'\[.*?\]'), '');

    // Replace slashes between alternatives with ' or ' (e.g., 'here/there' -> 'here or there')
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([^\s/,()]+)\s*/\s*([^\s/,()]+)'),
      (m) => '${m[1]} or ${m[2]}',
    );

    // Clean up multiple hyphens, trailing punctuation, and whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'^[-–—\s]+|[-–—\s]+$'), '');
    return cleaned;
  }
}
