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
    final Map<String, Verb> verbsMap = {};
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

            final verb = Verb(
              infinitive: portugueseVerb,
              translation: englishTranslation,
              conjugations: {
                'eu': eu,
                'tu': tu,
                'você, ela, ele': voceElaEle,
                'nós': nos,
                'vocês, elas, eles': vocesElasEles,
              },
            );
            verbsMap[portugueseVerb.toLowerCase()] = verb;
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
          final infinitive = item['portuguese']?.toString() ?? '';
          if (infinitive.isEmpty) continue;

          final presentTense = item['present_tense'] as Map<String, dynamic>?;
          final pastTense = item['past_tense'] as Map<String, dynamic>?;

          Map<String, String>? conjugations;

          if (presentTense != null) {
            conjugations = {
              'eu': presentTense['eu']?.toString() ?? '',
              'tu': presentTense['tu']?.toString() ?? '',
              'você, ela, ele': presentTense['ele_ela_voce']?.toString() ?? '',
              'nós': presentTense['nos']?.toString() ?? '',
              'vocês, elas, eles': presentTense['voces_eles']?.toString() ?? '',
            };
          } else if (item['present_eu'] != null) {
            // Handle flat format
            conjugations = {
              'eu': item['present_eu']?.toString() ?? '',
              'tu': item['present_tu']?.toString() ?? '',
              'você, ela, ele': item['present_ele']?.toString() ?? '',
              'nós': item['present_nos']?.toString() ?? '',
              'vocês, elas, eles': item['present_voces']?.toString() ?? '',
            };
          }

          if (conjugations != null) {
            Map<String, String>? pastConjugations;
            if (pastTense != null) {
              pastConjugations = {
                'eu': pastTense['eu']?.toString() ?? '',
                'tu': pastTense['tu']?.toString() ?? '',
                'você, ela, ele': pastTense['ele_ela_voce']?.toString() ?? '',
                'nós': pastTense['nos']?.toString() ?? '',
                'vocês, elas, eles': pastTense['voces_eles']?.toString() ?? '',
              };
            } else if (item['past_eu'] != null) {
              pastConjugations = {
                'eu': item['past_eu']?.toString() ?? '',
                'tu': item['past_tu']?.toString() ?? '',
                'você, ela, ele': item['past_ele']?.toString() ?? '',
                'nós': item['past_nos']?.toString() ?? '',
                'vocês, elas, eles': item['past_voces']?.toString() ?? '',
              };
            }

            final key = infinitive.toLowerCase();
            final existingVerb = verbsMap[key];
            
            if (existingVerb != null) {
              // Merge: Prefer JSON data as it's often more complete
              verbsMap[key] = Verb(
                infinitive: existingVerb.infinitive, // keep original case if possible
                translation: item['english']?.toString() ?? existingVerb.translation,
                conjugations: conjugations,
                pastConjugations: pastConjugations ?? existingVerb.pastConjugations,
              );
            } else {
              verbsMap[key] = Verb(
                infinitive: infinitive,
                translation: item['english']?.toString() ?? '',
                conjugations: conjugations,
                pastConjugations: pastConjugations,
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading vocabulary.json in VerbService: $e');
    }

    return verbsMap.values.toList();
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
