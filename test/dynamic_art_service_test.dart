import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/services/dynamic_art_service.dart';

class PixelReader {
  final int width;
  final int height;
  final Uint8List rgba;

  PixelReader({required this.width, required this.height, required this.rgba});

  static Future<PixelReader> fromFile(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return PixelReader(
      width: image.width,
      height: image.height,
      rgba: byteData!.buffer.asUint8List(),
    );
  }

  List<int> getPixel(int x, int y) {
    assert(x >= 0 && x < width && y >= 0 && y < height);
    final offset = (y * width + x) * 4;
    return [
      rgba[offset],
      rgba[offset + 1],
      rgba[offset + 2],
      rgba[offset + 3],
    ];
  }
}

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

    test('reuses existing cached file on repeat synthesis of same word', () async {
      final item = LanguageItem(
        id: 'cached_word_5',
        portuguese: 'Bom dia',
        english: 'Good morning',
        notes: 'Greeting',
      );

      final uri1 = await DynamicArtService.generateWordArt(item);
      final file1 = File.fromUri(uri1);
      final modTime1 = file1.lastModifiedSync();

      // Second call should return cached file without modifying or re-synthesizing.
      // Clear memory cache first to explicitly test the disk-cache fast path.
      DynamicArtService.clearMemoryCacheForTesting();
      final uri2 = await DynamicArtService.generateWordArt(item);
      expect(uri2, uri1);
      final modTime2 = file1.lastModifiedSync();
      expect(modTime2, modTime1);
    });

    test('generates valid PNG with flagged star and word progress indicator', () async {
      final item = LanguageItem(
        id: 'flagged_word_6',
        portuguese: 'Nós vamos ouvir',
        english: 'We are going to hear',
        notes: 'Futuro (vamos) • nós',
      );

      final uri = await DynamicArtService.generateWordArt(
        item,
        isFlagged: true,
        wordIndex: 8,
        totalWords: 12,
      );
      final file = File.fromUri(uri);

      expect(file.existsSync(), isTrue);
      final bytes = await file.readAsBytes();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });

    test('pixel probe verifies flagged star (gold) vs unflagged star (surface)', () async {
      final item = LanguageItem(
        id: 'flag_probe_item',
        portuguese: 'Obrigado',
        english: 'Thank you',
        notes: '',
      );

      final unflaggedUri = await DynamicArtService.generateWordArt(
        item,
        isFlagged: false,
        wordIndex: 1,
        totalWords: 12,
      );
      final unflaggedPixels = await PixelReader.fromFile(File.fromUri(unflaggedUri));
      final unflaggedStarCenter = unflaggedPixels.getPixel(692, 108);
      // Unflagged star center is dark surface: R, G, B < 60
      expect(unflaggedStarCenter[0], lessThan(60));
      expect(unflaggedStarCenter[1], lessThan(60));

      final flaggedUri = await DynamicArtService.generateWordArt(
        item,
        isFlagged: true,
        wordIndex: 1,
        totalWords: 12,
      );
      final flaggedPixels = await PixelReader.fromFile(File.fromUri(flaggedUri));
      final flaggedStarCenter = flaggedPixels.getPixel(692, 108);
      // Flagged star center is gold (0xFFFFD166): R > 240, G > 190, B < 120
      expect(flaggedStarCenter[0], greaterThan(240));
      expect(flaggedStarCenter[1], greaterThan(190));
      expect(flaggedStarCenter[2], lessThan(120));
    });

    test('pixel probe verifies active vs inactive dot colors and deck-wrap disk caching', () async {
      final item = LanguageItem(
        id: 'dot_probe_item',
        portuguese: 'Nós vamos ouvir',
        english: 'We are going to hear',
        notes: 'Futuro (vamos) • nós',
      );

      // 1. Synthesize at word 1 of 12
      final uri1 = await DynamicArtService.generateWordArt(
        item,
        wordIndex: 1,
        totalWords: 12,
      );
      final pixels1 = await PixelReader.fromFile(File.fromUri(uri1));
      // Dot 0 center (323, 700) should be active violet (0xFFB587FA: R ~ 181, B ~ 250)
      final dot0Word1 = pixels1.getPixel(323, 700);
      expect(dot0Word1[0], greaterThan(160));
      expect(dot0Word1[2], greaterThan(230));

      // Dot 1 center (337, 700) should be inactive slate (0xFF464455: R ~ 70, B ~ 85)
      final dot1Word1 = pixels1.getPixel(337, 700);
      expect(dot1Word1[0], lessThan(90));
      expect(dot1Word1[2], lessThan(100));

      // 2. Synthesize SAME item at word 2 of 12 (must not be served stale word 1 art from disk)
      DynamicArtService.clearMemoryCacheForTesting();
      final uri2 = await DynamicArtService.generateWordArt(
        item,
        wordIndex: 2,
        totalWords: 12,
      );
      expect(uri2.toString(), isNot(equals(uri1.toString())));
      final pixels2 = await PixelReader.fromFile(File.fromUri(uri2));

      // Now Dot 0 must be inactive slate
      final dot0Word2 = pixels2.getPixel(323, 700);
      expect(dot0Word2[0], lessThan(90));
      expect(dot0Word2[2], lessThan(100));

      // And Dot 1 must be active violet
      final dot1Word2 = pixels2.getPixel(337, 700);
      expect(dot1Word2[0], greaterThan(160));
      expect(dot1Word2[2], greaterThan(230));

      // 3. Deck wrap: wordIndex 14 with 12 words wraps to position 2
      DynamicArtService.clearMemoryCacheForTesting();
      final uriWrap = await DynamicArtService.generateWordArt(
        item,
        wordIndex: 14,
        totalWords: 12,
      );
      final pixelsWrap = await PixelReader.fromFile(File.fromUri(uriWrap));
      final dot1Wrap = pixelsWrap.getPixel(337, 700);
      expect(dot1Wrap[0], greaterThan(160));
      expect(dot1Wrap[2], greaterThan(230));
    });
  });
}
