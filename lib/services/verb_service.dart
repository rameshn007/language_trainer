import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/verb.dart';

final verbServiceProvider = Provider<VerbService>((ref) {
  return VerbService();
});

class VerbService {
  Future<List<Verb>> loadVerbs() async {
    try {
      final String content = await rootBundle.loadString('assets/data/verbs.csv');
      final lines = content.split('\n');
      final List<Verb> verbs = [];

      // Skip the header row
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final row = _parseCsvRow(line);
        if (row.length >= 7) {
          final portugueseVerb = row[0];
          final eu = row[1];
          final tu = row[2];
          final voceElaEle = row[3];
          final nos = row[4];
          final vocesElasEles = row[5];
          final englishTranslation = row[6];

          verbs.add(
            Verb(
              infinitive: portugueseVerb,
              translation: englishTranslation,
              conjugations: {
                'eu': eu,
                'tu': tu,
                'você, ela, ele': voceElaEle,
                'nós': nos,
                'vocês, elas, eles': vocesElasEles,
              },
            ),
          );
        }
      }

      return verbs;
    } catch (e) {
      print('Error loading verbs: $e');
      return [];
    }
  }

  /// A simple CSV row parser that handles quoted commas
  List<String> _parseCsvRow(String row) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;
    
    for (int i = 0; i < row.length; i++) {
        var char = row[i];
        if (char == '"') {
            inQuotes = !inQuotes;
        } else if (char == ',' && !inQuotes) {
            result.add(current.toString().trim());
            current.clear();
        } else {
            current.write(char);
        }
    }
    result.add(current.toString().trim());
    return result;
  }
}
