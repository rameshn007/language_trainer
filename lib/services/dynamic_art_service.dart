import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/language_item.dart';

class DynamicArtService {
  static Future<Uri> generateWordArt(LanguageItem item) async {
    final double width = 800;
    final double height = 800;
    
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, Rect.fromPoints(Offset(0, 0), Offset(width, height)));
    
    // Background
    final Paint paint = Paint()..color = const Color(0xFF1E1E2C); // Dark blue/gray background
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);
    
    // Portuguese Text (Brighter, Bigger)
    final TextSpan ptSpan = TextSpan(
      text: item.portuguese,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 80,
        fontWeight: FontWeight.bold,
      ),
    );
    
    final TextPainter ptPainter = TextPainter(
      text: ptSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 4,
    );
    
    ptPainter.layout(minWidth: 0, maxWidth: width - 80);
    final double ptY = (height / 2) - ptPainter.height - 10;
    ptPainter.paint(canvas, Offset((width - ptPainter.width) / 2, ptY));
    
    // English Text (Faded, Smaller)
    final TextSpan enSpan = TextSpan(
      text: item.english,
      style: TextStyle(
        color: Colors.white.withAlpha(153), // 0.6 * 255
        fontSize: 50,
        fontWeight: FontWeight.normal,
      ),
    );
    
    final TextPainter enPainter = TextPainter(
      text: enSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 4,
    );
    
    enPainter.layout(minWidth: 0, maxWidth: width - 80);
    final double enY = (height / 2) + 20;
    enPainter.paint(canvas, Offset((width - enPainter.width) / 2, enY));
    
    // Convert to Image
    final ui.Image image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List pngBytes = byteData!.buffer.asUint8List();
    
    // Save to temp directory with per-word filename to avoid race conditions
    final safeId = item.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/album_art_$safeId.png');
    await file.writeAsBytes(pngBytes);

    return file.uri;
  }
}
