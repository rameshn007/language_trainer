import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:language_trainer/main.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/services/notification_service.dart';
import 'package:language_trainer/services/verb_service.dart';
import 'package:language_trainer/ui/home_screen.dart';
import 'package:language_trainer/ui/home_tile_layout.dart';
import 'package:language_trainer/ui/home_tiles_data.dart';
import 'helpers/carplay_test_helpers.dart';

class _MockNotificationService extends Mock implements NotificationService {}

class _MockVerbService extends Mock implements VerbService {}

class _TestStorageService extends FakeStorageService {
  _TestStorageService({super.initialItems});

  @override
  List<int> getXPHistory([int days = 7]) => List.filled(days, 0);

  @override
  List<String> getXPHistoryLabels([int days = 7]) => List.filled(days, '');
}

/// Tile ids of the "Fast Practice" section, in the order they are added.
const List<String> _fastPracticeTileIds = [
  'vocab_flashcards',
  'fast_vocab_quiz',
  'fast_voice_trainer',
];

/// A tile whose two lines are longer than anything shipped: "Conjunctions &
/// Connectors" plus its `Connectors` badge measures 274 pt with SF Pro at
/// design sizes. Kept as a width rather than re-measured from
/// `home_tiles_data.dart`: flutter-test renders text with a font ~2.7x wider
/// than the device font, so a copy-derived figure would describe the test
/// environment, not a phone.
const double _longLineAtDesignSize = 274.0;

/// A short tile line, for reading the fit rule from the other end.
const double _shortLineAtDesignSize = 140.0;

/// Viewport widths the app is laid out at, compact phone to desktop window.
const List<double> _widthsUnderTest = [
  320.0,
  360.0,
  400.0,
  430.0,
  440.0,
  568.0,
  704.0,
  820.0,
  900.0,
  1024.0,
  1112.0,
  1326.0,
];

const List<double> _copyWidthsUnderTest = [
  _shortLineAtDesignSize,
  _longLineAtDesignSize,
];

/// Section gutter `_buildCategorySection` passes as `cardSpacing`.
const double _gutter = 10.0;

/// Text width a `columns`-wide grid leaves for tile copy: the column width
/// minus what a tile spends on icon box, gaps and chevron.
double _columnTextWidth(int columns, double availableWidth) =>
    (availableWidth - _gutter * (columns - 1)) / columns - tileChromeWidth;

int _columnsFor(double availableWidth, double textWidth) =>
    chooseTileColumnCount(
      availableWidth: availableWidth,
      textWidth: textWidth,
      gutter: _gutter,
    );

Widget _buildHome({required Size logicalSize, double textScale = 1.0}) {
  final fakeStorage = _TestStorageService(
    initialItems: [
      LanguageItem(
        id: 'item1',
        portuguese: 'obrigado',
        english: 'thank you',
        masteryLevel: 1,
      ),
    ],
  );
  fakeStorage.saveSetting('vocab_only_mode', true);
  fakeStorage.saveSetting('has_seen_enhanced_voice_prompt', true);

  final mockNotif = _MockNotificationService();
  when(() => mockNotif.requestPermissionsIfFirstTime()).thenAnswer(
    (_) async {},
  );
  when(() => mockNotif.handlePendingNotification()).thenAnswer((_) async {});

  final mockTts = MockTtsService();
  when(() => mockTts.isEnhancedPtVoiceAvailable).thenReturn(true);
  when(() => mockTts.initFuture).thenAnswer((_) async {});

  final mockVerb = _MockVerbService();
  when(() => mockVerb.loadVerbs()).thenAnswer((_) async => []);

  return ProviderScope(
    overrides: [
      storageServiceProvider.overrideWithValue(fakeStorage),
      notificationServiceProvider.overrideWithValue(mockNotif),
      ttsServiceProvider.overrideWithValue(mockTts),
      verbServiceProvider.overrideWithValue(mockVerb),
    ],
    child: MaterialApp(
      theme: ThemeData(platform: TargetPlatform.iOS),
      home: MediaQuery(
        data: MediaQueryData(
          size: logicalSize,
          textScaler: TextScaler.linear(textScale),
        ),
        child: const HomeScreen(),
      ),
    ),
  );
}

/// Drives the home screen far enough that section content is laid out: the
/// loading spinner has to resolve and FadeInUp's 200 ms delay has to elapse,
/// and `pump(Duration)` only advances the fake clock once per call.
Future<void> _settleHome(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('chooseTileColumnCount', () {
    test('drops a two-column phone grid that cannot fit the copy at size', () {
      // iPhone 17 Pro Max portrait: 440 pt screen - 2 x 20 pt content
      // padding, so a paired row is 195 pt wide and leaves 105 pt of text.
      expect(_columnTextWidth(2, 400.0), closeTo(105.0, 0.5));
      expect(
        _columnsFor(400.0, _longLineAtDesignSize),
        1,
        reason: 'the longest tile line is 274 pt, so pairing would shrink it',
      );
    });

    test('keeps a grid only where a column really fits a full-size line', () {
      // iPad mini portrait (704 pt): 347 pt columns leave 257 pt of text,
      // still short of the longest line, so it stays a single column.
      expect(_columnTextWidth(2, 704.0), closeTo(257.0, 0.5));
      expect(_columnsFor(704.0, _longLineAtDesignSize), 1);
      // A 900 pt viewport pairs tiles; an 11" iPad landscape (1112 pt) is the
      // first whose three columns each hold the longest line at full size.
      expect(_columnsFor(900.0, _longLineAtDesignSize), 2);
      expect(_columnsFor(1112.0, _longLineAtDesignSize), 3);
      expect(_columnsFor(1326.0, _longLineAtDesignSize), 3);
    });

    test('never picks a grid that shrinks the copy or wastes width', () {
      // The same rule read from both ends over shipped viewport widths, with a
      // short and a long line: no grid whose columns are too narrow for the
      // copy (that is the silent 40-70% shrink this replaced), and no single
      // column kept where a wider grid would hold the text at full size.
      for (final width in _widthsUnderTest) {
        for (final copy in _copyWidthsUnderTest) {
          final columns = _columnsFor(width, copy);
          if (columns > 1) {
            expect(
              _columnTextWidth(columns, width),
              greaterThanOrEqualTo(copy - 0.5),
              reason: '$copy pt shrinks in a $columns-column grid at $width pt',
            );
          } else {
            final pairWidth = (width - _gutter) / 2;
            final pairFits = pairWidth >= tileMinColumnWidth &&
                _columnTextWidth(2, width) >= copy;
            expect(
              pairFits,
              isFalse,
              reason: 'two columns hold $copy pt at $width pt; one wastes it',
            );
          }
        }
      }
    });

    test('rejects columns below the readable floor even when text fits', () {
      // Three 198 pt columns: the copy squeezes in, but only shrunk.
      expect(_columnTextWidth(3, 614.0), lessThan(tileMinColumnWidth));
      expect(_columnsFor(614.0, 100.0), 2);
    });

    test('degrades to one column below a single tile width', () {
      expect(_columnsFor(120.0, 10.0), 1);
    });
  });

  group('tileCardHeight', () {
    test('grows the tile instead of shrinking text at a large text scale', () {
      final tiles = [
        const HomeTileItem(
          id: 'probe',
          title: 'All Topics Grid',
          subtitle: 'Browse all categories in a visual grid',
          icon: Icons.category_rounded,
          color: Color(0xFF333333),
          badge: 'Grid',
        ),
      ];
      final normal = measureTileTextBlock(tiles, TextScaler.noScaling);
      final large = measureTileTextBlock(tiles, const TextScaler.linear(2.0));

      expect(tileCardHeight(normal), tileMinCardHeight);
      expect(
        tileCardHeight(large),
        greaterThan(tileCardHeight(normal)),
        reason: '2x text needs a taller tile, not smaller text',
      );
      expect(tileCardHeight(large), lessThanOrEqualTo(tileMaxCardHeight));
    });
  });

  group('HomeScreen tile grid', () {
    setUpAll(registerCarPlayFallbackValues);

    testWidgets('stacks Fast Practice tiles full width on a 440 pt phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440 * 3, 956 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildHome(logicalSize: const Size(440, 956)));
      await _settleHome(tester);

      expect(tester.takeException(), isNull);

      final rects = <String, Rect>{};
      for (final id in _fastPracticeTileIds) {
        final finder = find.byKey(ValueKey(id));
        expect(finder, findsOneWidget, reason: 'tile $id must be rendered');
        rects[id] = tester.getRect(finder);
      }

      // A paired row is ~195 pt wide; full width is what keeps tile text at
      // its designed size instead of scaling it down to squeeze two in.
      for (final entry in rects.entries) {
        expect(
          entry.value.width,
          greaterThan(380.0),
          reason: '${entry.key} must span the content width',
        );
      }

      final ordered = _fastPracticeTileIds.map((id) => rects[id]!).toList();
      for (var i = 1; i < ordered.length; i++) {
        expect(
          ordered[i].top,
          greaterThanOrEqualTo(ordered[i - 1].bottom),
          reason: 'tile $i shares a row with the tile above it',
        );
      }
    });

    testWidgets('grows the tile for a 2x text scale instead of shrinking copy', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440 * 3, 956 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildHome(logicalSize: const Size(440, 956), textScale: 2.0),
      );
      await _settleHome(tester);

      expect(tester.takeException(), isNull);

      for (final id in _fastPracticeTileIds) {
        final tile = find.byKey(ValueKey(id));
        expect(tile, findsOneWidget, reason: 'tile $id must be rendered');

        // A FittedBox lays its child out unbounded, so the Column keeps its
        // natural height in the tree whatever it ends up painting. A tile at
        // least as tall as that block plus its own padding is a tile whose
        // height tracked the text: a fixed 72 pt card could only shrink a 2x
        // block, which is what the 40-70% scale used to mean in practice.
        final block = find
            .descendant(of: tile, matching: find.byType(Column))
            .first;
        final blockHeight = tester.getSize(block).height;
        final tileHeight = tester.getSize(tile).height;

        expect(
          tileHeight,
          greaterThanOrEqualTo(blockHeight + 2 * tileVerticalPadding - 1.0),
          reason: '$id packs a $blockHeight pt block into a $tileHeight pt tile',
        );
        expect(tileHeight, lessThanOrEqualTo(tileMaxCardHeight));
      }
    });

    testWidgets('keeps an odd last tile on the grid in a two-column section', (
      tester,
    ) async {
      // iPad Pro 12.9 portrait. Its content width is wide enough that Fast
      // Practice pairs up, which puts the third tile alone in its row - the
      // case where a lone Expanded used to stretch it across the screen.
      tester.view.physicalSize = const Size(1024 * 2, 1366 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildHome(logicalSize: const Size(1024, 1366)));
      await _settleHome(tester);

      expect(tester.takeException(), isNull);

      final rects = <String, Rect>{};
      for (final id in _fastPracticeTileIds) {
        final finder = find.byKey(ValueKey(id));
        expect(finder, findsOneWidget, reason: 'tile $id must be rendered');
        rects[id] = tester.getRect(finder);
      }

      // Premise, so the check below cannot go vacuous: at this width the
      // section pairs up and the third tile lands alone in its row. If this
      // stops holding, the grid rule or the test font changed - not the
      // alignment - so look at the column count before editing the numbers.
      final firstRowTop = rects.values.first.top;
      expect(
        rects.values.where((rect) => rect.top == firstRowTop).length,
        2,
        reason: 'no two-column row to align to: $rects',
      );

      final widths = rects.values.map((rect) => rect.width).toList();
      final widest = widths.reduce((a, b) => a > b ? a : b);
      final narrowest = widths.reduce((a, b) => a < b ? a : b);
      // Every tile stays one column wide: an odd last row keeps its empty slot
      // instead of stretching over the row, which is ~2x and reads as a bug
      // even though nothing overflows.
      expect(
        widest / narrowest,
        lessThan(1.05),
        reason: 'a tile gave up the column width: $rects',
      );
    });
  });
}
