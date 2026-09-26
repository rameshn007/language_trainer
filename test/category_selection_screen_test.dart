import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/ui/quiz/category_selection_screen.dart';

void main() {
  Widget buildTestWidget({required Size physicalSize, required double devicePixelRatio}) {
    return ProviderScope(
      child: MaterialApp(
        home: const CategorySelectionScreen(),
      ),
    );
  }

  group('CategorySelectionScreen Responsive Grid Tests', () {
    testWidgets('renders 3 columns in portrait mode (iPhone 17 Pro 430x932)', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(
        physicalSize: const Size(1290, 2796),
        devicePixelRatio: 3.0,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(3), reason: 'Portrait mode should have 3 columns');

      // Verify cards render without exception
      expect(find.byType(Card), findsWidgets);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Basics'), findsOneWidget);
      expect(find.text('Travel & Directions'), findsOneWidget);
    });

    testWidgets('renders 4 columns in landscape mode (iPhone 17 Pro 932x430)', (tester) async {
      tester.view.physicalSize = const Size(2796, 1290);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(
        physicalSize: const Size(2796, 1290),
        devicePixelRatio: 3.0,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(4), reason: 'Landscape mode should have 4 columns');

      expect(find.byType(Card), findsWidgets);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Basics'), findsOneWidget);
      expect(find.text('Travel & Directions'), findsOneWidget);
    });

    testWidgets('renders gracefully on compact iPhone SE (320x568) in portrait without overflow', (tester) async {
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(
        physicalSize: const Size(640, 1136),
        devicePixelRatio: 2.0,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(3));
    });

    testWidgets('renders gracefully on compact iPhone SE (568x320) in landscape without overflow', (tester) async {
      tester.view.physicalSize = const Size(1136, 640);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(
        physicalSize: const Size(1136, 640),
        devicePixelRatio: 2.0,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(4));
    });
  });
}
