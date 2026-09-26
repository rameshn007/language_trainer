import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/ui/quiz/category_selection_screen.dart';
import 'package:language_trainer/utils/iphone_duo_helper.dart';

void main() {
  Widget buildTestWidget() {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: const CategorySelectionScreen(),
      ),
    );
  }

  group('CategorySelectionScreen Responsive Grid Tests', () {
    tearDown(() {
      IPhoneDuoHelper.resetForTesting();
    });

    testWidgets('renders 3 columns in portrait mode (iPhone 17 Pro 430x932) with symmetric geometry', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(3), reason: 'Portrait mode should have 3 columns');
      expect(delegate.mainAxisExtent, equals(106.0));

      final gridRect = tester.getRect(find.byType(GridView));
      expect(gridRect.left, closeTo(16.0, 1.0));
      expect(gridRect.right, closeTo(430.0 - 16.0, 1.0));

      final cardFinders = find.byType(Card);
      expect(cardFinders, findsWidgets);
      for (final card in tester.widgetList<Card>(cardFinders)) {
        final cardRect = tester.getRect(find.byWidget(card));
        expect(cardRect.left, greaterThanOrEqualTo(gridRect.left - 0.5));
        expect(cardRect.right, lessThanOrEqualTo(gridRect.right + 0.5));
        expect(cardRect.height, closeTo(106.0, 1.0));
      }
    });

    testWidgets('renders 4 columns in landscape mode (iPhone 17 Pro 932x430, 0 insets) with symmetric geometry', (tester) async {
      tester.view.physicalSize = const Size(2796, 1290);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(4), reason: 'Landscape mode should have 4 columns');
      expect(delegate.mainAxisExtent, equals(94.0));

      final gridRect = tester.getRect(find.byType(GridView));
      expect(gridRect.left, closeTo(16.0, 1.0));
      expect(gridRect.right, closeTo(932.0 - 16.0, 1.0));

      final cardFinders = find.byType(Card);
      expect(cardFinders, findsWidgets);
      for (final card in tester.widgetList<Card>(cardFinders)) {
        final cardRect = tester.getRect(find.byWidget(card));
        expect(cardRect.left, greaterThanOrEqualTo(gridRect.left - 0.5));
        expect(cardRect.right, lessThanOrEqualTo(gridRect.right + 0.5));
        expect(cardRect.height, closeTo(94.0, 1.0));
      }
    });

    testWidgets('avoids double-counting insets on landscape iPhone with 59pt cutout insets', (tester) async {
      tester.view.physicalSize = const Size(2796, 1290);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 177, top: 0, right: 177, bottom: 63);
      tester.view.viewPadding = const FakeViewPadding(left: 177, top: 0, right: 177, bottom: 63);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final gridRect = tester.getRect(find.byType(GridView));
      // 59pt safe area inset + 16pt gutter = 75pt left and right
      expect(gridRect.left, closeTo(75.0, 1.5));
      expect(gridRect.right, closeTo(932.0 - 75.0, 1.5));

      // Assert perfectly centered layout without dead 202pt right gutter
      final leftGutter = gridRect.left;
      final rightGutter = 932.0 - gridRect.right;
      expect((leftGutter - rightGutter).abs(), lessThan(2.0),
          reason: 'Grid must be symmetrically centered across cutout insets');
    });

    testWidgets('renders gracefully on compact iPhone SE (320x568) in portrait without overflow', (tester) async {
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(3));
      expect(delegate.mainAxisExtent, equals(106.0));

      final cardFinders = find.byType(Card);
      expect(cardFinders, findsWidgets);
      for (final card in tester.widgetList<Card>(cardFinders)) {
        final cardRect = tester.getRect(find.byWidget(card));
        expect(cardRect.left, greaterThanOrEqualTo(0.0));
        expect(cardRect.right, lessThanOrEqualTo(320.0 + 0.5));
      }
    });

    testWidgets('renders gracefully on compact iPhone SE (568x320) in landscape without overflow', (tester) async {
      tester.view.physicalSize = const Size(1136, 640);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(4));
      expect(delegate.mainAxisExtent, equals(94.0));

      final cardFinders = find.byType(Card);
      expect(cardFinders, findsWidgets);
      for (final card in tester.widgetList<Card>(cardFinders)) {
        final cardRect = tester.getRect(find.byWidget(card));
        expect(cardRect.left, greaterThanOrEqualTo(0.0));
        expect(cardRect.right, lessThanOrEqualTo(568.0 + 0.5));
      }
    });

    testWidgets('renders correctly on Duo outside landscape (678x466) with debugOverride', (tester) async {
      IPhoneDuoHelper.debugOverride = DuoScreenOverride.outsideLandscape;
      tester.view.physicalSize = const Size(678 * 2.5, 466 * 2.5);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        IPhoneDuoHelper.resetForTesting();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(4));

      final cardFinders = find.byType(Card);
      expect(cardFinders, findsWidgets);
      for (final card in tester.widgetList<Card>(cardFinders)) {
        final cardRect = tester.getRect(find.byWidget(card));
        expect(cardRect.left, greaterThanOrEqualTo(0.0));
        expect(cardRect.right, lessThanOrEqualTo(678.0 + 0.5));
      }
    });
  });
}
