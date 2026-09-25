import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/ui/home_screen.dart';

void main() {
  testWidgets('SectionContent places chevron at the far right and toggles correctly', (tester) async {
    tester.view.physicalSize = const Size(1398, 2034);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 76, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: SectionContent(
                    title: 'Vocabulary & Flashcards',
                    icon: Icons.menu_book,
                    initiallyExpanded: true,
                    isDark: true,
                    children: [
                      Container(color: Colors.blue),
                      Container(color: Colors.purple),
                      Container(color: Colors.orange),
                    ],
                  ),
                ),
                Card(
                  child: SectionContent(
                    title: 'Grammar & Verbs',
                    icon: Icons.school,
                    initiallyExpanded: false,
                    isDark: true,
                    children: [
                      Container(color: Colors.red),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final card0Rect = tester.getRect(find.byType(Card).at(0));
    final card1Rect = tester.getRect(find.byType(Card).at(1));
    final icon0Rect = tester.getRect(find.byIcon(Icons.expand_more).at(0));
    final icon1Rect = tester.getRect(find.byIcon(Icons.expand_more).at(1));

    // Chevron should be at the far right of the card: card.right - 16 = icon.right
    expect(icon0Rect.right, closeTo(card0Rect.right - 16.0, 5.0));
    expect(icon1Rect.right, closeTo(card1Rect.right - 16.0, 5.0));

    // Test toggle of Card 1 (initially collapsed)
    await tester.tap(find.text('Grammar & Verbs'));
    await tester.pumpAndSettle();

    final redBox = find.byWidgetPredicate((w) => w is Container && w.color == Colors.red);
    expect(redBox, findsOneWidget);
  });
}
