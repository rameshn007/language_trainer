import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Helper utilities for detecting and adapting UI to the iPhone Duo screens
/// (both outside cover screen and inside unfolded screen).
///
/// Hardware specifications for iPhone Duo screens:
/// - Outside (Cover) Screen: 1398 x 2034 px @ scale 3.0 -> 466 x 678 pt (portrait) or 678 x 466 pt (landscape).
/// - Inside (Unfolded) Screen: 2007 x 2853 px @ scale 3.0 -> 669 x 951 pt (portrait) or 951 x 669 pt (landscape).
///
/// On both screens:
/// - The top-right corner features a prominent system status capsule with time and a circular Wi-Fi icon.
/// - The Wi-Fi icon is centered horizontally at approximately 38 pt from the screen's right edge.
/// - Floating action buttons are aligned to this vertical column (center = screenWidth - 38 pt)
///   to maintain visual harmony and avoid overlapping with primary card and list content.
/// - Main content preserves a reservation margin (76 pt) on the right to keep clear of the system
///   icon and the vertically aligned FABs.
class IPhoneDuoHelper {
  /// Expected logical width for the outside screen in portrait.
  static const double outsideWidthPortrait = 466.0;

  /// Expected logical height for the outside screen in portrait.
  static const double outsideHeightPortrait = 678.0;

  /// Expected logical width for the inside screen in portrait.
  static const double insideWidthPortrait = 669.0;

  /// Expected logical height for the inside screen in portrait.
  static const double insideHeightPortrait = 951.0;

  /// Center X offset of the top-right system Wi-Fi icon measured from the right screen edge.
  static const double wifiIconCenterFromRight = 38.0;

  /// Width of the system status icon reservation area in the top right.
  static const double systemIconReservedWidth = 76.0;

  /// Clearance margin for AppBar actions on the right to avoid colliding with the system icon.
  static const double appBarActionsRightPadding = 56.0;

  /// Checks if the current context is running on any iPhone Duo screen (outside or inside).
  static bool isDuo(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return isDuoSize(size);
  }

  /// Checks if the current context is running on the iPhone Duo outside screen (either portrait or landscape).
  static bool isDuoOutside(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return isDuoOutsidePortraitSize(size) || isDuoOutsideLandscapeSize(size);
  }

  /// Checks if the current context is in portrait on the iPhone Duo outside screen.
  static bool isDuoOutsidePortrait(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return isDuoOutsidePortraitSize(size);
  }

  /// Checks if the current context is in landscape on the iPhone Duo outside screen.
  static bool isDuoOutsideLandscape(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return isDuoOutsideLandscapeSize(size);
  }

  /// Checks if the current context is on the iPhone Duo inside screen (either portrait or landscape).
  static bool isDuoInside(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return isDuoInsideSize(size);
  }

  /// Checks if the current context is in landscape on the iPhone Duo inside screen.
  static bool isDuoInsideLandscape(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return isDuoInsideLandscapeSize(size);
  }

  /// Checks if the current context is in portrait on the iPhone Duo inside screen.
  static bool isDuoInsidePortrait(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return isDuoInsidePortraitSize(size);
  }

  static bool isDuoOutsidePortraitSize(Size size) {
    return (size.width - outsideWidthPortrait).abs() < 14 &&
        (size.height - outsideHeightPortrait).abs() < 14;
  }

  static bool isDuoOutsideLandscapeSize(Size size) {
    return (size.width - outsideHeightPortrait).abs() < 14 &&
        (size.height - outsideWidthPortrait).abs() < 14;
  }

  static bool isDuoInsidePortraitSize(Size size) {
    return (size.width - insideWidthPortrait).abs() < 16 &&
        (size.height - insideHeightPortrait).abs() < 16;
  }

  static bool isDuoInsideLandscapeSize(Size size) {
    return (size.width - insideHeightPortrait).abs() < 16 &&
        (size.height - insideWidthPortrait).abs() < 16;
  }

  static bool isDuoInsideSize(Size size) {
    return isDuoInsideLandscapeSize(size) || isDuoInsidePortraitSize(size);
  }

  static bool isDuoSize(Size size) {
    return isDuoOutsidePortraitSize(size) ||
        isDuoOutsideLandscapeSize(size) ||
        isDuoInsideLandscapeSize(size) ||
        isDuoInsidePortraitSize(size);
  }

  /// FloatingActionButtonLocation that vertically aligns the FAB with the system Wi-Fi icon.
  static const FloatingActionButtonLocation fabLocation = DuoAlignedFabLocation();

  /// Returns the appropriate FAB location based on whether the device is Duo or in landscape.
  /// In landscape on standard iPhones, positions the FAB at the far right so it does not overlap content.
  static FloatingActionButtonLocation getFabLocation(
    BuildContext context, {
    double landscapeRightMargin = 16.0,
  }) {
    if (isDuo(context)) {
      return fabLocation;
    }
    final media = MediaQuery.of(context);
    if (media.orientation == Orientation.landscape) {
      return LandscapeRightFabLocation(
        rightMargin: media.padding.right + landscapeRightMargin,
      );
    }
    return FloatingActionButtonLocation.endFloat;
  }

  /// Returns horizontal insets (left, right) for main content to avoid Dynamic Island
  /// obstruction and prevent overlap with right-aligned FABs in landscape or on Duo.
  static EdgeInsets getContentHorizontalPadding(BuildContext context) {
    if (isDuo(context)) {
      return const EdgeInsets.only(
        left: 20.0,
        right: systemIconReservedWidth,
      );
    }
    final mediaPadding = MediaQuery.paddingOf(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final double left =
        math.max(20.0, mediaPadding.left + (isLandscape ? 16.0 : 0.0));
    final double right = isLandscape
        ? mediaPadding.right + 84.0
        : math.max(20.0, mediaPadding.right);

    return EdgeInsets.only(left: left, right: right);
  }

  /// Clearance margin for AppBar actions on the right to avoid colliding with
  /// the system icon on Duo or Dynamic Island in landscape.
  static double getAppBarActionsRightPadding(BuildContext context) {
    if (isDuo(context)) {
      return appBarActionsRightPadding;
    }
    final mediaPadding = MediaQuery.paddingOf(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (isLandscape) {
      return math.max(16.0, mediaPadding.right);
    }
    return 0.0;
  }
}

/// Floating action button location aligned with the iPhone Duo screen's system Wi-Fi icon.
class DuoAlignedFabLocation extends FloatingActionButtonLocation {
  final double fabCenterFromRight;
  final double bottomMargin;

  const DuoAlignedFabLocation({
    this.fabCenterFromRight = IPhoneDuoHelper.wifiIconCenterFromRight,
    this.bottomMargin = 16.0,
  });

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX = scaffoldGeometry.scaffoldSize.width -
        fabCenterFromRight -
        (scaffoldGeometry.floatingActionButtonSize.width / 2);
    final double bottomPadding = scaffoldGeometry.minViewPadding.bottom > 0
        ? scaffoldGeometry.minViewPadding.bottom
        : scaffoldGeometry.minInsets.bottom;
    final double fabY = scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.floatingActionButtonSize.height -
        bottomMargin -
        bottomPadding;
    return Offset(fabX, fabY);
  }
}

/// Floating action button location positioned at the rightmost edge for landscape orientations.
class LandscapeRightFabLocation extends FloatingActionButtonLocation {
  final double rightMargin;
  final double bottomMargin;

  const LandscapeRightFabLocation({
    this.rightMargin = 16.0,
    this.bottomMargin = 16.0,
  });

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX = scaffoldGeometry.scaffoldSize.width -
        rightMargin -
        scaffoldGeometry.floatingActionButtonSize.width;
    final double bottomPadding = scaffoldGeometry.minViewPadding.bottom > 0
        ? scaffoldGeometry.minViewPadding.bottom
        : scaffoldGeometry.minInsets.bottom;
    final double fabY = scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.floatingActionButtonSize.height -
        bottomMargin -
        bottomPadding;
    return Offset(fabX, fabY);
  }
}
