import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/services/silence_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('silence_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SilenceAudioService - Pause Calculations', () {
    test('calculateBetweenWordsPause returns 2.5s for short single word', () {
      final item = LanguageItem(id: '1', portuguese: 'obrigado', english: 'thank you');
      expect(SilenceAudioService.calculateBetweenWordsPause(item), 2.5);
    });

    test('calculateBetweenWordsPause returns 2.5s for 2 short words', () {
      final item = LanguageItem(id: '2', portuguese: 'bom dia', english: 'good morning');
      expect(SilenceAudioService.calculateBetweenWordsPause(item), 2.5);
    });

    test('calculateBetweenWordsPause scales up for long phrase', () {
      final item = LanguageItem(
        id: '3',
        portuguese: 'Como é que se diz isto em português?',
        english: 'How do you say this in Portuguese?',
      );
      final pause = SilenceAudioService.calculateBetweenWordsPause(item);
      expect(pause, greaterThanOrEqualTo(4.0));
      expect(pause, lessThanOrEqualTo(5.0));
    });

    test('calculateRepetitionPause scales up for long phrase', () {
      final single = LanguageItem(id: '1', portuguese: 'cão', english: 'dog');
      expect(SilenceAudioService.calculateRepetitionPause(single), 2.2);

      final phrase = LanguageItem(
        id: '4',
        portuguese: 'Gostaria de reservar uma mesa para duas pessoas',
        english: 'I would like to reserve a table for two people',
      );
      final pause = SilenceAudioService.calculateRepetitionPause(phrase);
      expect(pause, greaterThanOrEqualTo(3.5));
      expect(pause, lessThanOrEqualTo(4.4));
    });
  });

  group('SilenceAudioService - WAV Generation and Caching', () {
    test('createWavSilenceBytes produces valid WAV header with expected size', () {
      final bytes = SilenceAudioService.createWavSilenceBytes(1.0);
      // Header: 44 bytes. 44100 samples * 2 bytes/sample = 88200 data bytes. Total = 88244.
      expect(bytes.length, 88244);
      // 'RIFF'
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      // 'WAVE'
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      // 'fmt '
      expect(String.fromCharCodes(bytes.sublist(12, 16)), 'fmt ');
      // 'data'
      expect(String.fromCharCodes(bytes.sublist(36, 40)), 'data');
    });

    test('getSilenceFilePath creates and caches file in targetDir', () async {
      final path1 = await SilenceAudioService.getSilenceFilePath(
        durationSeconds: 2.0,
        targetDir: tempDir,
      );

      final file1 = File(path1);
      expect(file1.existsSync(), isTrue);
      expect(file1.lengthSync(), 44 + 44100 * 2 * 2);

      final modifiedBefore = file1.lastModifiedSync();
      // Second call should return the exact same path without modifying
      final path2 = await SilenceAudioService.getSilenceFilePath(
        durationSeconds: 2.0,
        targetDir: tempDir,
      );

      expect(path2, path1);
      expect(file1.lastModifiedSync(), modifiedBefore);
    });
  });
}
