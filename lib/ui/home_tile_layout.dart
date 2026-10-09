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
/// Badge box padding, per side, like [tileHorizontalPadding]. A badge adds two
/// of each to the text it wraps, and both the measurement below and the tile's
/// `EdgeInsets.symmetric` spell that `2 *` out instead of halving a total.
const double tileBadgePaddingHorizontal = 5.0;
const double tileBadgePaddingVertical = 1.5;
const double tileLineGap = 2.0;

/// Line-height multiplier the tile's three text styles paint with, and the one
/// [measureTileTextBlock] measures with. `_buildActionCard` states it instead
/// of inheriting the theme's `bodyMedium` (also 1.43): with no `height` of its
/// own the measurement ran ~43% shorter than the painted block, which only
/// bites once text is scaled - at 2x system text a 66 pt tile was asked to
/// hold an 82 pt block, so the FittedBox shrank the copy to fit the height.
const double tileLineHeight = 1.43;
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
    height: tileLineHeight,
    fontWeight: FontWeight.bold,
  );
  final subtitleStyle = TextStyle(
    fontSize: scaler.scale(tileSubtitleSize),
    height: tileLineHeight,
    fontWeight: FontWeight.w500,
  );
  final badgeStyle = TextStyle(
    fontSize: scaler.scale(tileBadgeSize),
    height: tileLineHeight,
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
      headWidth += tileBadgeGap + 2 * tileBadgePaddingHorizontal + badgeSize.width;
      headHeight = math.max(
        headHeight,
        badgeSize.height + 2 * tileBadgePaddingVertical,
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

/// Measures one line with a style whose `fontSize` the caller already ran
/// through the active [TextScaler]. `TextPainter.textScaler` defaults to
/// `TextScaler.noScaling`, so this scales once; the tile paints the same size by
/// handing `Text` its design size and letting `MediaQuery.textScaler` scale it
/// once. Scaling on both sides doubles it, which is what made a tile at 1.5x
/// system text paint at 2.25x and then get shrunk back by the FittedBox.
Size _measureText(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return Size(painter.width, painter.height);
}
