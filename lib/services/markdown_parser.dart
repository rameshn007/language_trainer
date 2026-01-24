import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/language_item.dart';

class MarkdownParser {
  Future<List<LanguageItem>> loadAndParseRawData(String assetPath) async {
    final String content = await rootBundle.loadString(assetPath);
    return parseContent(content);
  }

  List<LanguageItem> parseContent(String content) {
    final List<LanguageItem> items = [];
    final List<String> lines = content.split('\n');

    // Simple state to track table parsing
    bool inTable = false;
    List<String> headers = [];

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Check if it's a table row
      if (line.startsWith('|')) {
        // Split by pipe and remove first/last empty elements if present
        var parts = line.split('|').map((e) => e.trim()).toList();

        // Remove empty strings resulting from leading/trailing pipes
        if (parts.isNotEmpty && parts.first.isEmpty) parts.removeAt(0);
        if (parts.isNotEmpty && parts.last.isEmpty) parts.removeLast();

        if (parts.isEmpty) continue;

        // Detect Header Row
        if (parts.contains('Portugues') || parts.contains('English')) {
          headers = parts;
          inTable = true;
          continue;
        }

        // Detect Separator Row (e.g. | :--- |)
        if (line.contains('---')) {
          continue;
        }

        if (inTable && headers.isNotEmpty) {
          // It's a data row
          try {
            String pt = parts.isNotEmpty ? parts[0] : '';
            String en = parts.length > 1 ? parts[1] : '';
            if (pt.isEmpty && en.isEmpty) continue;

            String notes = parts.length > 2 ? parts[2] : '';

            // Clean up markdown formatting if needed
            pt = _cleanCell(pt);
            en = _cleanCell(en);
            notes = _cleanCell(notes);

            items.add(
              LanguageItem(
                id: '${pt}_$en'.hashCode.toString(), // Simple hash as ID
                portuguese: pt,
                english: en,
                notes: notes,
              ),
            );
          } catch (e) {
            debugPrint('Error parsing line: $line - $e');
          }
        }
      } else {
        // Line doesn't start with pipe, probably a header or random text.
        // We could reset table state if strictly following multiple tables,
        // but for now we assume all tables are relevant.
      }
    }
    return items;
  }

  String _cleanCell(String cell) {
    // Remove bold/italics markers if simple text is preferred
    // cell = cell.replaceAll('**', '').replaceAll('*', '');
    // Handle escaped pipes or other markdown chars if necessary
    return cell;
  }
}
