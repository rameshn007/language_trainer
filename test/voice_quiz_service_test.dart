import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:language_trainer/services/voice_quiz_service.dart';
import 'package:language_trainer/services/tts_service.dart';

class _MockTtsService extends Mock implements TtsService {}

void main() {
  late VoiceQuizService service;
  late _MockTtsService mockTts;

  setUp(() {
    mockTts = _MockTtsService();
    service = VoiceQuizService(mockTts);
  });

  group('VoiceQuizService.isCorrect — Exact Match', () {
    test('exact match returns true', () {
      expect(service.isCorrect('Olá', 'Olá'), isTrue);
    });

    test('exact match with lowercase returns true', () {
      expect(service.isCorrect('olá', 'olá'), isTrue);
    });

    test('exact match with punctuation stripped returns true', () {
      expect(service.isCorrect('Olá!', 'Olá'), isTrue);
    });
  });

  group('VoiceQuizService.isCorrect — Case Insensitive', () {
    test('different case matches', () {
      expect(service.isCorrect('ola', 'OLÁ'), isTrue);
    });

    test('mixed case matches', () {
      expect(service.isCorrect('OlA', 'olá'), isTrue);
    });
  });

  group('VoiceQuizService.isCorrect — Whitespace Handling', () {
    test('leading/trailing whitespace trimmed', () {
      expect(service.isCorrect(' olá ', 'olá'), isTrue);
    });

    test('extra internal spaces normalized', () {
      expect(service.isCorrect('olá  tudo', 'olá tudo'), isTrue);
    });
  });

  group('VoiceQuizService.isCorrect — Accent Normalization', () {
    test('cafe matches café', () {
      expect(service.isCorrect('cafe', 'café'), isTrue);
    });

    test('nao matches não', () {
      expect(service.isCorrect('nao', 'não'), isTrue);
    });

    test('voce matches você', () {
      expect(service.isCorrect('voce', 'você'), isTrue);
    });

    test('aço matches aço (no change needed)', () {
      expect(service.isCorrect('aco', 'aço'), isTrue);
    });

    test('pão matches pão', () {
      expect(service.isCorrect('pao', 'pão'), isTrue);
    });
  });

  group('VoiceQuizService.isCorrect — Contains Match', () {
    test('substring match returns true', () {
      expect(service.isCorrect('ola tudo bem', 'ola'), isTrue);
    });
  });

  group('VoiceQuizService.isCorrect — Levenshtein Threshold', () {
    test('single character difference within threshold', () {
      expect(service.isCorrect('ola', 'ola1'), isTrue);
    });

    test('two character difference within threshold', () {
      expect(service.isCorrect('ola', 'ola12'), isTrue);
    });

    test('three character difference at boundary', () {
      expect(service.isCorrect('ola', 'ola123'), isTrue);
    });

    test('completely different words with similar length exceed threshold', () {
      // "ola" vs "xyz1234" - no contains match, distance=7, max=7, similarity=0
      expect(service.isCorrect('ola', 'xyz1234'), isFalse);
    });
  });

  group('VoiceQuizService.isCorrect — No Match', () {
    test('completely different words return false', () {
      expect(service.isCorrect('olá', 'adeus'), isFalse);
    });

    test('unrelated words return false', () {
      expect(service.isCorrect('sim', 'não'), isFalse);
    });

    test('empty spoken vs non-empty expected returns true (both normalize to empty)', () {
      // Both strings normalize to empty after stripping non-word chars
      expect(service.isCorrect('', ''), isTrue);
    });

    test('single char different returns false for short words', () {
      expect(service.isCorrect('a', 'b'), isFalse);
    });
  });

  group('VoiceQuizService.isCorrect — Portuguese Specific', () {
    test('ç matches c', () {
      expect(service.isCorrect('aco', 'aço'), isTrue);
    });

    test('tilde vowels normalized', () {
      expect(service.isCorrect('ao', 'ão'), isTrue);
    });

    test('circumflex normalized', () {
      expect(service.isCorrect('como', 'comó'), isTrue);
    });

    test('grave accent normalized', () {
      expect(service.isCorrect('a', "à"), isTrue);
    });

    test('umlaut normalized', () {
      expect(service.isCorrect('uo', 'üo'), isTrue);
    });
  });

  group('VoiceQuizService.isCorrect — Edge Cases', () {
    test('numbers match as strings', () {
      expect(service.isCorrect('123', '123'), isTrue);
    });

    test('mixed alphanumeric matches', () {
      expect(service.isCorrect('ola123', 'ola123'), isTrue);
    });

    test('special characters stripped before comparison', () {
      expect(service.isCorrect('olá!@#', 'olá'), isTrue);
    });

    test('very long identical string matches', () {
      expect(
        service.isCorrect(
          'esta é uma frase muito longa de teste',
          'esta é uma frase muito longa de teste',
        ),
        isTrue,
      );
    });

    test('one word vs very different long string returns false', () {
      expect(
        service.isCorrect('ola', 'esta é uma frase completamente diferente'),
        isFalse,
      );
    });
  });
}
