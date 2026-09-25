import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/utils/iphone_duo_helper.dart';

void main() {
  group('iPhone 17 Landscape and Dynamic Island Layout Tests', () {
    testWidgets('Landscape with Dynamic Island on left: content cleared and FABs at rightmost', (tester) async {
      // iPhone 17 Landscape Left (932 x 430) with Dynamic Island on left (59 pt)
      tester.view.physicalSize = const Size(2796, 1290);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 177, top: 0, right: 0, bottom: 63); // 59 pt left, 21 pt bottom
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      late EdgeInsets contentPadding;
      late FloatingActionButtonLocation fabLocation;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              contentPadding = IPhoneDuoHelper.getContentHorizontalPadding(context);
              fabLocation = IPhoneDuoHelper.getFabLocation(context);

              return Scaffold(
                floatingActionButtonLocation: fabLocation,
                floatingActionButton: FloatingActionButton(
                  onPressed: () {},
                  child: const Icon(Icons.star),
                ),
                body: Padding(
                  padding: EdgeInsets.fromLTRB(
                    contentPadding.left,
                    10,
                    contentPadding.right,
                    80,
                  ),
                  child: Container(
                    key: const Key('test_content_card'),
                    color: Colors.blue,
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Left inset must clear the Dynamic Island (59.0 pt) with margin
      expect(contentPadding.left, greaterThanOrEqualTo(75.0));

      // Right inset must leave a gutter for the FABs
      expect(contentPadding.right, greaterThanOrEqualTo(84.0));

      final contentRect = tester.getRect(find.byKey(const Key('test_content_card')));
      final fabRect = tester.getRect(find.byType(FloatingActionButton));

      // FAB must be strictly to the right of the content (no overlap)
      expect(fabRect.left, greaterThan(contentRect.right));

      // FAB right edge should be near the right screen edge (16 pt margin)
      expect(932.0 - fabRect.right, closeTo(16.0, 2.0));
    });

    testWidgets('Landscape with Dynamic Island on right: content cleared and FABs inside safe area', (tester) async {
      // iPhone 17 Landscape Right (932 x 430) with Dynamic Island on right (59 pt)
      tester.view.physicalSize = const Size(2796, 1290);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 0, top: 0, right: 177, bottom: 63); // 59 pt right
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      late EdgeInsets contentPadding;
      late FloatingActionButtonLocation fabLocation;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              contentPadding = IPhoneDuoHelper.getContentHorizontalPadding(context);
              fabLocation = IPhoneDuoHelper.getFabLocation(context);

              return Scaffold(
                floatingActionButtonLocation: fabLocation,
                floatingActionButton: FloatingActionButton(
                  onPressed: () {},
                  child: const Icon(Icons.star),
                ),
                body: Padding(
                  padding: EdgeInsets.fromLTRB(
                    contentPadding.left,
                    10,
                    contentPadding.right,
                    80,
                  ),
                  child: Container(
                    key: const Key('test_content_card_right'),
                    color: Colors.blue,
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Left inset is standard margin (20.0 pt)
      expect(contentPadding.left, equals(20.0));

      // Right inset must clear both the Dynamic Island (59 pt) and the FAB gutter (84 pt)
      expect(contentPadding.right, greaterThanOrEqualTo(143.0));

      final contentRect = tester.getRect(find.byKey(const Key('test_content_card_right')));
      final fabRect = tester.getRect(find.byType(FloatingActionButton));

      // FAB must be strictly to the right of the content (no overlap)
      expect(fabRect.left, greaterThan(contentRect.right));

      // FAB right edge must clear the Dynamic Island (59.0 pt from screen right) with 16 pt margin
      expect(932.0 - fabRect.right, closeTo(75.0, 2.0));
    });

    testWidgets('Portrait preserves standard 20 pt insets and endFloat location', (tester) async {
      // iPhone 17 Portrait (430 x 932)
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 0, top: 177, right: 0, bottom: 102);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      late EdgeInsets contentPadding;
      late FloatingActionButtonLocation fabLocation;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              contentPadding = IPhoneDuoHelper.getContentHorizontalPadding(context);
              fabLocation = IPhoneDuoHelper.getFabLocation(context);
              return Container();
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(contentPadding.left, equals(20.0));
      expect(contentPadding.right, equals(20.0));
      expect(fabLocation, equals(FloatingActionButtonLocation.endFloat));
    });
  });
}
