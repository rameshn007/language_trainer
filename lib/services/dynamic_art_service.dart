import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/language_item.dart';
import '../theme/carplay_theme.dart';

class DynamicArtService {
  static const int _maxCacheSize = 64;
  static final Map<String, Uri> _memoryCache = {};

  @visibleForTesting
  static void clearMemoryCacheForTesting() {
    _memoryCache.clear();
  }

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

  static Path _createStarPath(double cx, double cy, double outerRadius, double innerRadius) {
    final path = Path();
    const double step = pi / 5;
    for (int i = 0; i < 10; i++) {
      final double radius = i.isEven ? outerRadius : innerRadius;
      final double angle = i * step - (pi / 2);
      final double x = cx + radius * cos(angle);
      final double y = cy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  static Future<Uri> generateWordArt(
    LanguageItem item, {
    bool isFlagged = false,
    int? wordIndex,
    int? totalWords,
  }) async {
    final cleanNotes = item.notes.trim();
    final safeId = item.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final contentHash = '${item.portuguese}_${item.english}_$cleanNotes'.hashCode.toRadixString(36);
    final flagTag = isFlagged ? 'f1' : 'f0';
    final progressTag = wordIndex != null ? 'w${wordIndex}_$totalWords' : 'w0';
    final cacheKey = '${item.id}_${contentHash}_${flagTag}_$progressTag';

    if (_memoryCache.containsKey(cacheKey)) {
      final cachedUri = _memoryCache[cacheKey]!;
      if (File.fromUri(cachedUri).existsSync()) {
        return cachedUri;
      }
      _memoryCache.remove(cacheKey);
    }

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/album_art_${safeId}_${contentHash}_$flagTag.png');

    // Fast-path: return cached image if already synthesized and non-empty
    if (await file.exists() && await file.length() > 0) {
      if (_memoryCache.length >= _maxCacheSize) {
        _memoryCache.remove(_memoryCache.keys.first);
      }
      _memoryCache[cacheKey] = file.uri;
      return file.uri;
    }

    const double width = 800;
    const double height = 800;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder, Rect.fromPoints(Offset.zero, const Offset(width, height)));

    // 1. App background canvas (--bg)
    final Paint bgPaint = Paint()..color = CarPlayTheme.bg;
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bgPaint);

    // 2. Ambient steel-blue radial halo glow behind card
    final Paint haloPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(width / 2, height / 2),
        360,
        [
          const Color(0x553B68A8),
          const Color(0x223B68A8),
          Colors.transparent,
        ],
        [0.0, 0.55, 1.0],
      );
    canvas.drawCircle(const Offset(width / 2, height / 2), 360, haloPaint);

    // 3. Center Flashcard (--surface)
    const double cardLeft = 64;
    const double cardTop = 64;
    const double cardWidth = width - (cardLeft * 2);
    const double cardHeight = height - (cardTop * 2);
    final cardRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight),
      const Radius.circular(CarPlayTheme.cardRadius + 4),
    );

    final Paint cardPaint = Paint()..color = CarPlayTheme.surface;
    final Paint cardBorderPaint = Paint()
      ..color = CarPlayTheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(cardRRect, cardPaint);
    canvas.drawRRect(cardRRect, cardBorderPaint);

    // 4. Star Bookmark Indicator (top-right of card)
    const double starCx = cardLeft + cardWidth - 44;
    const double starCy = cardTop + 44;
    final starPath = _createStarPath(starCx, starCy, 16, 8);
    if (isFlagged) {
      final starFill = Paint()..color = CarPlayTheme.starGold;
      canvas.drawPath(starPath, starFill);
    } else {
      final starOutline = Paint()
        ..color = const Color(0xFF5A5868)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawPath(starPath, starOutline);
    }

    final bool hasNotes = cleanNotes.isNotEmpty;

    // 5. Grammar / Tense Pill Badge
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
            color: Color(0xFFD6C2FD),
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(minWidth: 0, maxWidth: cardWidth - 140);

      pillWidth = notePainter.width + (pillHPad * 2);
      pillHeight = notePainter.height + (pillVPad * 2);
    }

    // 6. Portuguese Text (Dynamic font size)
    final double ptFontSize = getPortugueseFontSize(item.portuguese.length);
    final TextPainter ptPainter = TextPainter(
      text: TextSpan(
        text: item.portuguese,
        style: TextStyle(
          color: CarPlayTheme.fg,
          fontSize: ptFontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 4,
    )..layout(minWidth: 0, maxWidth: cardWidth - 80);

    // 7. English Text (Muted, dynamic font size)
    final double enFontSize = getEnglishFontSize(item.english.length);
    final TextPainter enPainter = TextPainter(
      text: TextSpan(
        text: item.english,
        style: TextStyle(
          color: CarPlayTheme.muted,
          fontSize: enFontSize,
          fontWeight: FontWeight.normal,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 4,
    )..layout(minWidth: 0, maxWidth: cardWidth - 80);

    // 8. Dynamic Vertical Centering Calculation
    const double contentSpacing = 20;
    final double pillBlockHeight = hasNotes ? (pillHeight + pillBottomSpacing) : 0;
    final double totalContentHeight = pillBlockHeight + ptPainter.height + contentSpacing + enPainter.height;

    double currentY = cardTop + ((cardHeight - totalContentHeight) / 2);
    if (currentY < cardTop + 40) currentY = cardTop + 40;

    // Render Grammar Pill
    if (hasNotes && notePainter != null) {
      final pillLeft = (width - pillWidth) / 2;
      final pillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(pillLeft, currentY, pillWidth, pillHeight),
        const Radius.circular(16),
      );

      final pillFill = Paint()..color = const Color(0xFF2E2C3D);
      final pillBorder = Paint()
        ..color = const Color(0x66B587FA)
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

    // 9. Bottom progress counter / dots if provided
    if (wordIndex != null && totalWords != null && totalWords > 0) {
      final int dotCount = totalWords.clamp(1, 14);
      final int activeDot = (wordIndex - 1).clamp(0, dotCount - 1);
      const double dotRadius = 4.0;
      const double dotSpacing = 14.0;
      final double totalDotsWidth = (dotCount * dotRadius * 2) + ((dotCount - 1) * (dotSpacing - (dotRadius * 2)));
      double dotX = (width - totalDotsWidth) / 2;
      final double dotY = cardTop + cardHeight - 36;

      for (int d = 0; d < dotCount; d++) {
        final isCur = d == activeDot;
        final Paint dotPaint = Paint()
          ..color = isCur ? CarPlayTheme.accent : const Color(0xFF464455);
        canvas.drawCircle(Offset(dotX + dotRadius, dotY), dotRadius, dotPaint);
        dotX += dotSpacing;
      }
    }

    // Convert to Image
    final ui.Image image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final Uint8List pngBytes = byteData!.buffer.asUint8List();

    // Save to temp directory with per-word filename
    await file.writeAsBytes(pngBytes);
    if (_memoryCache.length >= _maxCacheSize) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[cacheKey] = file.uri;

    return file.uri;
  }
}
