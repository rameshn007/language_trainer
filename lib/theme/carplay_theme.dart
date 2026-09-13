import 'package:flutter/material.dart';

/// Design tokens extracted from the CarPlay / Listen & Repeat brand specification.
///
/// Base OKLch references:
/// - bg: oklch(13.5% 0.012 285) -> near-black, cool-tinted canvas
/// - surface: oklch(22.5% 0.014 285) -> flashcard / raised card fill
/// - surface2: button fill
/// - fg: oklch(96% 0.004 285) -> primary text (off-white)
/// - muted: oklch(65% 0.015 285) -> translation, captions, secondary icons
/// - border: oklch(30% 0.014 285) -> hairlines, unselected control borders
/// - accent: oklch(73% 0.155 295) -> light violet (header actions, selected tab, badge)
/// - glow: steel-blue radial halo behind the flashcard
class CarPlayTheme {
  CarPlayTheme._();

  // Color Tokens
  static const Color bg = Color(0xFF14131A);
  static const Color surface = Color(0xFF24222B);
  static const Color surface2 = Color(0xFF2E2C38);
  static const Color fg = Color(0xFFF5F4F7);
  static const Color muted = Color(0xFF9895A2);
  static const Color border = Color(0xFF363442);
  static const Color accent = Color(0xFFB587FA);
  static const Color accentSoft = Color(0x28B587FA);
  static const Color accentLine = Color(0x99B587FA);
  static const Color glow = Color(0x3D3B68A8); // Steel-blue halo
  static const Color glowStrong = Color(0x663B68A8);
  static const Color starGold = Color(0xFFFFD166);

  // Border Radii
  static const double cardRadius = 24.0;
  static const double pillRadius = 999.0;
  static const double badgeRadius = 14.0;

  // Typography
  static const TextStyle headerTitle = TextStyle(
    color: fg,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const TextStyle headerAction = TextStyle(
    color: accent,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle sectionHeader = TextStyle(
    color: muted,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  static const TextStyle cardTitle = TextStyle(
    color: fg,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle cardSubtitle = TextStyle(
    color: muted,
    fontSize: 13,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle phraseText = TextStyle(
    color: fg,
    fontSize: 34,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );

  static const TextStyle translationText = TextStyle(
    color: muted,
    fontSize: 18,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle badgeText = TextStyle(
    color: Color(0xFFD6C2FD),
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const TextStyle metaText = TextStyle(
    color: muted,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );
}
