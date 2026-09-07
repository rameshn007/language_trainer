import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/services/dynamic_art_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('dynamic_art_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getTemporaryDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DynamicArtService font scaling rules', () {
    test('Portuguese font scales down for long phrases to prevent clipping', () {
      expect(DynamicArtService.getPortugueseFontSize(10), 80);
      expect(DynamicArtService.getPortugueseFontSize(25), 80);
      expect(DynamicArtService.getPortugueseFontSize(26), 54);
      expect(DynamicArtService.getPortugueseFontSize(40), 54);
      expect(DynamicArtService.getPortugueseFontSize(41), 44);
      expect(DynamicArtService.getPortugueseFontSize(80), 44);
    });

    test('English font scales down for long translations', () {
      expect(DynamicArtService.getEnglishFontSize(15), 50);
      expect(DynamicArtService.getEnglishFontSize(30), 50);
      expect(DynamicArtService.getEnglishFontSize(31), 42);
      expect(DynamicArtService.getEnglishFontSize(50), 42);
      expect(DynamicArtService.getEnglishFontSize(51), 36);
      expect(DynamicArtService.getEnglishFontSize(90), 36);
    });
  });

  group('DynamicArtService.generateWordArt image synthesis', () {
    test('generates valid PNG for simple word without notes', () async {
      final item = LanguageItem(
        id: 'simple_word_1',
        portuguese: 'Obrigado',
        english: 'Thank you',
        notes: '',
      );

      final uri = await DynamicArtService.generateWordArt(item);
      final file = File.fromUri(uri);

      expect(file.existsSync(), isTrue);
      final bytes = await file.readAsBytes();
      expect(bytes.isNotEmpty, isTrue);
      // Verify PNG header [0x89, 0x50, 0x4E, 0x47]
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });

    test('generates valid PNG for word with grammar pill notes', () async {
      final item = LanguageItem(
        id: 'grammar_word_2',
        portuguese: 'Falou',
        english: 'He spoke',
        notes: 'Preterite Perfect - Ele/Ela',
      );

      final uri = await DynamicArtService.generateWordArt(item);
      final file = File.fromUri(uri);

      expect(file.existsSync(), isTrue);
      final bytes = await file.readAsBytes();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });

    test('generates valid PNG for long sentence (> 25 chars) with notes', () async {
      final item = LanguageItem(
        id: 'long_phrase_3',
        portuguese: 'Eu gostaria de pedir uma conta',
        english: 'I would like to ask for the bill',
        notes: 'Polite conditional request',
      );

      final uri = await DynamicArtService.generateWordArt(item);
      final file = File.fromUri(uri);

      expect(file.existsSync(), isTrue);
      final bytes = await file.readAsBytes();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });

    test('generates valid PNG for very long sentence (> 40 chars)', () async {
      final item = LanguageItem(
        id: 'very_long_phrase_4',
        portuguese: 'Onde fica a paragem de autocarro mais próxima daqui?',
        english: 'Where is the nearest bus stop from here?',
        notes: 'Directions & Questions',
      );

      final uri = await DynamicArtService.generateWordArt(item);
      final file = File.fromUri(uri);

      expect(file.existsSync(), isTrue);
      final bytes = await file.readAsBytes();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });
  });
}
