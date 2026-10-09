/// Typography and grid maths for the home screen's action tiles.
///
/// A tile paints its text inside a `FittedBox(fit: BoxFit.scaleDown)`, and
/// `RenderFittedBox.performLayout` lays that child out with *unbounded*
/// constraints before scaling it down to fit. Tile text therefore never
/// ellipsizes: a tile that runs short of width just paints its text smaller.
/// That makes "it fits" and "it is readable" one property, so the grid is
/// chosen from the measured copy instead of a viewport breakpoint. A
/// two-column grid on a 430 pt phone gave each tile 104 pt of text for copy
/// that needs ~274 pt, which is how every tile ended up rendered at 40–70 %
/// of its design size.
///
/// [measureTileTextBlock] and [chooseTileColumnCount] are pure so the fit rule
/// can be tested without a device; the sizes are also what `_buildActionCard`
/// renders, so measurement and paint can never drift apart.
library;
import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'home_tiles_data.dart';

const double tileTitleSize = 15.5;
const double tileSubtitleSize = 12.5;
const double tileBadgeSize = 9.5;
const double tileBadgeGap = 6.0;
const double tileBadgePaddingH = 10.0; // 5 pt each side
const double tileBadgePaddingV = 3.0; // 1.5 pt each side
const double tileLineGap = 2.0;
const double tileIconBox = 38.0;
const double tileIconTextGap = 10.0;
const double tileChevronWidth = 18.0;
const double tileHorizontalPadding = 10.0;
const double tileVerticalPadding = 5.0;

/// Width a tile spends on everything that is not text: ink padding, the icon
/// box, both gaps, the chevron, plus 4 pt slack for the card hairline and for
/// the gap between measured and painted text.
const double tileChromeWidth =
    2 * tileHorizontalPadding +
    tileIconBox +
    tileIconTextGap +
    tileChevronWidth +
    4.0;

/// Below this a column cannot hold two lines of tile copy at any readable
/// size, so grids stop here even when the text would technically squeeze in.
const double tileMinColumnWidth = 200.0;
const double tileMinCardHeight = 66.0;
const double tileMaxCardHeight = 120.0;

/// Intrinsic size of the text block a tile paints at full size: the wider of
/// `title + badge` and `subtitle`, over the tallest title+subtitle stack in
/// [items]. Mirrors `_buildActionCard`, which lays out one line of each.
Size measureTileTextBlock(List<HomeTileItem> items, TextScaler scaler) {
  final titleStyle = TextStyle(
    fontSize: scaler.scale(tileTitleSize),
    fontWeight: FontWeight.bold,
  );
  final subtitleStyle = TextStyle(
    fontSize: scaler.scale(tileSubtitleSize),
    fontWeight: FontWeight.w500,
  );
  final badgeStyle = TextStyle(
    fontSize: scaler.scale(tileBadgeSize),
    fontWeight: FontWeight.w700,
  );

  double width = 0;
  double height = 0;
  for (final item in items) {
    final titleSize = _measureText(item.title, titleStyle);
    final subtitleSize = _measureText(item.subtitle, subtitleStyle);

    double headWidth = titleSize.width;
    double headHeight = titleSize.height;
    final badge = item.badge;
    if (badge != null) {
      final badgeSize = _measureText(badge, badgeStyle);
      headWidth += tileBadgeGap + tileBadgePaddingH + badgeSize.width;
      headHeight = math.max(
        headHeight,
        badgeSize.height + tileBadgePaddingV,
      );
    }

    width = math.max(width, math.max(headWidth, subtitleSize.width));
    height = math.max(
      height,
      headHeight + tileLineGap + subtitleSize.height,
    );
  }
  return Size(width, height);
}

/// Tile columns that still give every tile a full-size line of text, trying
/// three, then two, then one. Narrow viewports and long copy land on one
/// full-width tile per row; grids survive only where the text fits at size.
int chooseTileColumnCount({
  required double availableWidth,
  required double textWidth,
  required double gutter,
}) {
  for (final columns in const <int>[3, 2]) {
    final columnWidth = (availableWidth - gutter * (columns - 1)) / columns;
    if (columnWidth >= tileMinColumnWidth &&
        columnWidth - tileChromeWidth >= textWidth) {
      return columns;
    }
  }
  return 1;
}

/// Card height that fits a measured [textBlock] plus the tile's own vertical
/// padding, so a large system text size keeps its size instead of shrinking.
double tileCardHeight(Size textBlock) => math.min(
  tileMaxCardHeight,
  math.max(tileMinCardHeight, textBlock.height + 2 * tileVerticalPadding),
);

Size _measureText(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return Size(painter.width, painter.height);
}
