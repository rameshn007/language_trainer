import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final tts = FlutterTts();
  final voices = await tts.getVoices;
  print('==== VOICES ====');
  for (var v in voices) {
    if (v['locale'].toString().contains('pt')) {
      print('PT Voice: ${v['name']} - ${v['identifier']} - ${v['quality']}');
    }
  }
  print('================');
}
