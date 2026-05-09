import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/verb.dart';
import 'storage_service.dart';
import '../main.dart'; // for storageServiceProvider

final verbServiceProvider = Provider<VerbService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return VerbService(storage);
});

class VerbService {
  final StorageService storage;

  VerbService(this.storage);

  Future<List<Verb>> loadVerbs() async {
    final List<Verb> verbs = [];
    final bool vocabOnly = storage.getSetting('vocab_only_mode', defaultValue: false) == true;
    
    if (!vocabOnly) {
      try {
      final String content = await rootBundle.loadString('assets/data/verbs.csv');
      final lines = content.split('\n');

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
      } catch (e) {
        debugPrint('Error loading verbs.csv: $e');
      }
    }

    try {
      final String jsonContent = await rootBundle.loadString('assets/vocabulary.json');
      final List<dynamic> jsonList = jsonDecode(jsonContent);
      for (var item in jsonList) {
        if (item['word_type'] == 'verb' || item['word_type'] == 'verbs / food and meals') {
          final presentTense = item['present_tense'] as Map<String, dynamic>?;
          final pastTense = item['past_tense'] as Map<String, dynamic>?;

          if (presentTense != null) {
            Map<String, String>? pastConjugations;
            if (pastTense != null) {
              pastConjugations = {
                'eu': pastTense['eu']?.toString() ?? '',
                'tu': pastTense['tu']?.toString() ?? '',
                'você, ela, ele': pastTense['ele_ela_voce']?.toString() ?? '',
                'nós': pastTense['nos']?.toString() ?? '',
                'vocês, elas, eles': pastTense['voces_eles']?.toString() ?? '',
              };
            }

            verbs.add(
              Verb(
                infinitive: item['portuguese']?.toString() ?? '',
                translation: item['english']?.toString() ?? '',
                conjugations: {
                  'eu': presentTense['eu']?.toString() ?? '',
                  'tu': presentTense['tu']?.toString() ?? '',
                  'você, ela, ele': presentTense['ele_ela_voce']?.toString() ?? '',
                  'nós': presentTense['nos']?.toString() ?? '',
                  'vocês, elas, eles': presentTense['voces_eles']?.toString() ?? '',
                },
                pastConjugations: pastConjugations,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading vocabulary.json in VerbService: $e');
    }

    return verbs;
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
