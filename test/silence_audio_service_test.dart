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
    test('calculateBetweenWordsPause returns 1.4s for short single word', () {
      final item = LanguageItem(id: '1', portuguese: 'obrigado', english: 'thank you');
      expect(SilenceAudioService.calculateBetweenWordsPause(item), 1.4);
    });

    test('calculateBetweenWordsPause returns 1.4s for 2 short words', () {
      final item = LanguageItem(id: '2', portuguese: 'bom dia', english: 'good morning');
      expect(SilenceAudioService.calculateBetweenWordsPause(item), 1.4);
    });

    test('calculateBetweenWordsPause scales up for long phrase, capped at 2.4s', () {
      final item = LanguageItem(
        id: '3',
        portuguese: 'Como é que se diz isto em português?',
        english: 'How do you say this in Portuguese?',
      );
      final pause = SilenceAudioService.calculateBetweenWordsPause(item);
      expect(pause, greaterThanOrEqualTo(2.0));
      expect(pause, lessThanOrEqualTo(2.4));
    });

    test('calculateRepetitionPause scales up for long phrase, capped at 3.4s', () {
      final single = LanguageItem(id: '1', portuguese: 'cão', english: 'dog');
      expect(SilenceAudioService.calculateRepetitionPause(single), 2.0);

      final phrase = LanguageItem(
        id: '4',
        portuguese: 'Gostaria de reservar uma mesa para duas pessoas',
        english: 'I would like to reserve a table for two people',
      );
      final pause = SilenceAudioService.calculateRepetitionPause(phrase);
      expect(pause, greaterThanOrEqualTo(2.8));
      expect(pause, lessThanOrEqualTo(3.4));
    });
  });

  group('SilenceAudioService - WAV Generation and Caching', () {
    test('calculateExpectedWavBytes calculates exact byte size', () {
      expect(SilenceAudioService.calculateExpectedWavBytes(1.0), 44 + 44100 * 2);
      expect(SilenceAudioService.calculateExpectedWavBytes(2.0), 44 + 88200 * 2);
    });

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
      expect(file1.lengthSync(), SilenceAudioService.calculateExpectedWavBytes(2.0));

      final modifiedBefore = file1.lastModifiedSync();
      // Second call should return the exact same path without modifying
      final path2 = await SilenceAudioService.getSilenceFilePath(
        durationSeconds: 2.0,
        targetDir: tempDir,
      );

      expect(path2, path1);
      expect(file1.lastModifiedSync(), modifiedBefore);
    });

    test('getSilenceFilePath evicts and recreates truncated or corrupted cached file', () async {
      final ms = (1.5 * 1000).round();
      final corruptedFile = File('${tempDir.path}/silence_${ms}ms.wav');
      // Write corrupted partial bytes (e.g. only 100 bytes, larger than 44 but not full length)
      await corruptedFile.writeAsBytes(List.filled(100, 0));
      expect(corruptedFile.lengthSync(), 100);

      final path = await SilenceAudioService.getSilenceFilePath(
        durationSeconds: 1.5,
        targetDir: tempDir,
      );

      final healedFile = File(path);
      expect(healedFile.lengthSync(), SilenceAudioService.calculateExpectedWavBytes(1.5));
    });
  });
}
