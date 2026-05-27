import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/services/markdown_parser.dart';
import 'package:language_trainer/models/language_item.dart';

void main() {
  late MarkdownParser parser;

  setUp(() {
    parser = MarkdownParser();
  });

  group('MarkdownParser.parseContent — Valid Tables', () {
    test('parses simple two-column table', () {
      const markdown = '''
| Portuguese | English |
|---|---|
| Olá | Hello |
| Adeus | Goodbye |
''';

      final result = parser.parseContent(markdown);

      expect(result, hasLength(2));
      expect(result[0].portuguese, 'Olá');
      expect(result[0].english, 'Hello');
      expect(result[1].portuguese, 'Adeus');
      expect(result[1].english, 'Goodbye');
    });

    test('parses table with notes column', () {
      const markdown = '''
| Portuguese | English | Notes |
|---|---|---|
| Olá | Hello | Greeting |
| Adeus | Goodbye | Farewell |
''';

      final result = parser.parseContent(markdown);

      expect(result, hasLength(2));
      expect(result[0].notes, 'Greeting');
      expect(result[1].notes, 'Farewell');
    });

    test('parses table with extra whitespace', () {
      const markdown = '''
|  Portuguese  |  English  |
|---|---|
|   Olá   |   Hello   |
|   Adeus   |   Goodbye   |
''';

      final result = parser.parseContent(markdown);

      expect(result, hasLength(2));
      expect(result[0].portuguese, 'Olá');
      expect(result[0].english, 'Hello');
    });

    test('parses single row table', () {
      const markdown = '''
| Portuguese | English |
|---|---|
| Sim | Yes |
''';

      final result = parser.parseContent(markdown);

      expect(result, hasLength(1));
      expect(result[0].portuguese, 'Sim');
      expect(result[0].english, 'Yes');
    });
  });

  group('MarkdownParser.parseContent — Empty / Invalid Input', () {
    test('empty string returns empty list', () {
      expect(parser.parseContent(''), isEmpty);
    });

    test('whitespace only returns empty list', () {
      expect(parser.parseContent('   \n  \n  '), isEmpty);
    });

    test('table without header pipe prefix returns empty list', () {
      const markdown = '''
Portuguese | English
Olá | Hello
''';

      expect(parser.parseContent(markdown), isEmpty);
    });

    test('random text returns empty list', () {
      const markdown = '''
This is just random text.
Nothing to parse here.
''';

      expect(parser.parseContent(markdown), isEmpty);
    });

    test('only header returns empty list', () {
      const markdown = '''
| Portuguese | English |
|---|---|
''';

      expect(parser.parseContent(markdown), isEmpty);
    });
  });

  group('MarkdownParser.parseContent — Malformed Rows', () {
    test('row with missing columns uses empty strings', () {
      const markdown = '''
| Portuguese | English |
|---|---|
| Olá |
| Adeus | Goodbye |
''';

      final result = parser.parseContent(markdown);

      expect(result, hasLength(2));
      expect(result[0].portuguese, 'Olá');
      expect(result[0].english, '');
    });

    test('row with extra columns uses third as notes', () {
      const markdown = '''
| Portuguese | English | Notes | Extra |
|---|---|---|---|
| Olá | Hello | Greeting | extra info |
''';

      final result = parser.parseContent(markdown);

      expect(result, hasLength(1));
      expect(result[0].notes, 'Greeting');
    });

    test('separator rows are skipped', () {
      const markdown = '''
| Portuguese | English |
|---|---|
| :--- | :--- |
| Olá | Hello |
''';

      final result = parser.parseContent(markdown);

      expect(result, hasLength(1));
      expect(result[0].portuguese, 'Olá');
    });

    test('empty row between data rows is handled', () {
      const markdown = '''
| Portuguese | English |
|---|---|
| Olá | Hello |

| Adeus | Goodbye |
''';

      final result = parser.parseContent(markdown);

      expect(result, hasLength(2));
    });
  });

  group('MarkdownParser.parseContent — Unicode', () {
    test('preserves accented characters', () {
      const markdown = '''
| Portuguese | English |
|---|---|
| Não | No |
| Cão | Dog |
| Pão | Bread |
''';

      final result = parser.parseContent(markdown);

      expect(result, hasLength(3));
      expect(result[0].portuguese, 'Não');
      expect(result[1].portuguese, 'Cão');
      expect(result[2].portuguese, 'Pão');
    });

    test('preserves special characters', () {
      const markdown = '''
| Portuguese | English |
|---|---|
| Açor | Azor |
| Exército | Army |
''';

      final result = parser.parseContent(markdown);

      expect(result[0].portuguese, 'Açor');
    });

    test('preserves non-Latin characters', () {
      const markdown = '''
| Portuguese | English |
|---|---|
| Olá 世界 | Hello World |
| Bonjour 世界 | Olá |
''';

      final result = parser.parseContent(markdown);

      expect(result[0].portuguese, 'Olá 世界');
    });
  });

  group('MarkdownParser.parseContent — Multiple Tables', () {
    test('parses multiple tables in one document', () {
      const markdown = '''
Some intro text

| Portuguese | English |
|---|---|
| Olá | Hello |

More text between tables

| Portuguese | English |
|---|---|
| Adeus | Goodbye |
''';

      final result = parser.parseContent(markdown);

      expect(result, hasLength(2));
      expect(result[0].portuguese, 'Olá');
      expect(result[1].portuguese, 'Adeus');
    });

    test('parses tables with different headers', () {
      const markdown = '''
| Portuguese | English |
|---|---|
| Olá | Hello |

| Portugues | English |
|---|---|
| Adeus | Goodbye |
''';

      final result = parser.parseContent(markdown);

      expect(result, hasLength(2));
    });
  });

  group('MarkdownParser.parseContent — Empty Content Filtering', () {
    test('rows with both Portuguese and English empty are skipped', () {
      const markdown = '''
| Portuguese | English |
|---|---|
|  |  |
| Olá | Hello |
''';

      final result = parser.parseContent(markdown);

      expect(result, hasLength(1));
      expect(result[0].portuguese, 'Olá');
    });

    test('rows with only Portuguese empty are kept', () {
      const markdown = '''
| Portuguese | English |
|---|---|
|  | Hello |
| Olá | |
| Olá | Hello |
''';

      final result = parser.parseContent(markdown);

      // Parser keeps rows where at least one field is non-empty
      expect(result, hasLength(3));
    });
  });

  group('MarkdownParser.parseContent — LanguageItem Properties', () {
    test('generated LanguageItem has correct properties', () {
      const markdown = '''
| Portuguese | English | Notes |
|---|---|---|
| Olá | Hello | Greeting |
''';

      final result = parser.parseContent(markdown);

      expect(result[0].id, isNotEmpty);
      expect(result[0].portuguese, 'Olá');
      expect(result[0].english, 'Hello');
      expect(result[0].notes, 'Greeting');
      expect(result[0].masteryLevel, 0);
    });

    test('LanguageItem is not empty', () {
      const markdown = '''
| Portuguese | English |
|---|---|
| Olá | Hello |
''';

      final result = parser.parseContent(markdown);
      expect(result[0].isEmpty, isFalse);
    });

    test('empty LanguageItem isEmpty returns true', () {
      final empty = LanguageItem.empty();
      expect(empty.isEmpty, isTrue);
    });
  });
}
