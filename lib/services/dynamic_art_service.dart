import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/language_item.dart';

class DynamicArtService {
  static double getPortugueseFontSize(int length) {
    if (length > 40) return 44;
    if (length > 25) return 54;
    return 80;
  }

  static double getEnglishFontSize(int length) {
    if (length > 50) return 36;
    if (length > 30) return 42;
    return 50;
  }

  static Future<Uri> generateWordArt(LanguageItem item) async {
    const double width = 800;
    const double height = 800;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, Rect.fromPoints(Offset.zero, const Offset(width, height)));

    // Background
    final Paint bgPaint = Paint()..color = const Color(0xFF1E1E2C);
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bgPaint);

    final cleanNotes = item.notes.trim();
    final bool hasNotes = cleanNotes.isNotEmpty;

    // Optional Grammar / Tense Pill Badge
    TextPainter? notePainter;
    double pillWidth = 0;
    double pillHeight = 0;
    const double pillHPad = 20;
    const double pillVPad = 8;
    const double pillBottomSpacing = 24;

    if (hasNotes) {
      notePainter = TextPainter(
        text: TextSpan(
          text: cleanNotes,
          style: const TextStyle(
            color: Color(0xFF93C5FD),
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(minWidth: 0, maxWidth: width - 120);

      pillWidth = notePainter.width + (pillHPad * 2);
      pillHeight = notePainter.height + (pillVPad * 2);
    }

    // Portuguese Text (Dynamic font size to prevent overflow)
    final double ptFontSize = getPortugueseFontSize(item.portuguese.length);
    final TextPainter ptPainter = TextPainter(
      text: TextSpan(
        text: item.portuguese,
        style: TextStyle(
          color: Colors.white,
          fontSize: ptFontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 4,
    )..layout(minWidth: 0, maxWidth: width - 80);

    // English Text (Faded, dynamically scaled)
    final double enFontSize = getEnglishFontSize(item.english.length);
    final TextPainter enPainter = TextPainter(
      text: TextSpan(
        text: item.english,
        style: TextStyle(
          color: Colors.white.withAlpha(178), // ~70% opacity
          fontSize: enFontSize,
          fontWeight: FontWeight.normal,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 4,
    )..layout(minWidth: 0, maxWidth: width - 80);

    // Dynamic Vertical Centering Calculation
    const double contentSpacing = 24;
    final double pillBlockHeight = hasNotes ? (pillHeight + pillBottomSpacing) : 0;
    final double totalHeight = pillBlockHeight + ptPainter.height + contentSpacing + enPainter.height;

    double currentY = (height - totalHeight) / 2;
    if (currentY < 40) currentY = 40; // Guard top padding

    // Render Grammar Pill
    if (hasNotes && notePainter != null) {
      final pillLeft = (width - pillWidth) / 2;
      final pillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(pillLeft, currentY, pillWidth, pillHeight),
        const Radius.circular(16),
      );

      final pillFill = Paint()..color = const Color(0xFF252B43);
      final pillBorder = Paint()
        ..color = const Color(0xFF3B82F6).withAlpha(128)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawRRect(pillRect, pillFill);
      canvas.drawRRect(pillRect, pillBorder);

      notePainter.paint(
        canvas,
        Offset((width - notePainter.width) / 2, currentY + pillVPad),
      );

      currentY += pillHeight + pillBottomSpacing;
    }

    // Render Portuguese Text
    ptPainter.paint(
      canvas,
      Offset((width - ptPainter.width) / 2, currentY),
    );
    currentY += ptPainter.height + contentSpacing;

    // Render English Text
    enPainter.paint(
      canvas,
      Offset((width - enPainter.width) / 2, currentY),
    );

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
