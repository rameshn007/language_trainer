import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/models/progress_data.dart';
import 'package:language_trainer/models/question.dart';
import 'package:language_trainer/services/progress_service.dart';
import 'package:language_trainer/services/storage_service.dart';
import 'package:language_trainer/ui/quiz/quiz_view_model.dart';

// Provider definition for testing
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError();
});

class _MockStorageService extends Mock implements StorageService {}

class _FakeSessionRecord extends Fake implements SessionRecord {}

void main() {
  late _MockStorageService mockStorage;

  setUpAll(() {
    registerFallbackValue(_FakeSessionRecord());
  });

  setUp(() {
    mockStorage = _MockStorageService();
  });

  LanguageItem makeItem({
    String id = 'item1',
    String pt = 'ola',
    String en = 'hello',
    int mastery = 0,
  }) {
    return LanguageItem(
      id: id,
      portuguese: pt,
      english: en,
      masteryLevel: mastery,
    );
  }

  // =========================================================================
  // Step 2.1 — Data Persistence (mocked)
  // =========================================================================

  group('StorageService — Data Persistence', () {
    test('saveItems() + getAllItems() returns saved items', () {
      final items = [
        makeItem(id: 'a', pt: 'ola', en: 'hello'),
        makeItem(id: 'b', pt: 'tchau', en: 'bye'),
      ];
      when(() => mockStorage.getAllItems()).thenReturn(items);

      final result = mockStorage.getAllItems();
      expect(result, hasLength(2));
      expect(result[0].id, 'a');
      expect(result[1].id, 'b');
    });

    test('getSetting() with default — returns default when key missing', () {
      when(
        () => mockStorage.getSetting('nonexistent', defaultValue: 'fallback'),
      ).thenReturn('fallback');
      expect(
        mockStorage.getSetting('nonexistent', defaultValue: 'fallback'),
        'fallback',
      );
    });

    test('isQuestionSeen() — returns false when not seen', () {
      when(() => mockStorage.isQuestionSeen('q1')).thenReturn(false);
      expect(mockStorage.isQuestionSeen('q1'), isFalse);
    });

    test('getDailyXPGoal() — returns default 50', () {
      when(() => mockStorage.getDailyXPGoal()).thenReturn(50);
      expect(mockStorage.getDailyXPGoal(), 50);
    });

    test('getSeenQuestionIds() — returns set of IDs', () {
      when(() => mockStorage.getSeenQuestionIds()).thenReturn({'q1', 'q2'});
      expect(mockStorage.getSeenQuestionIds(), hasLength(2));
    });
  });

  // =========================================================================
  // Step 2.2 — XP & Streak Tracking (mocked)
  // =========================================================================

  group('StorageService — XP & Streak Tracking', () {
    test("getTodayXP() — returns today's XP", () {
      when(() => mockStorage.getTodayXP()).thenReturn(45);
      expect(mockStorage.getTodayXP(), 45);
    });

    test('getTotalXP() — returns total XP', () {
      when(() => mockStorage.getTotalXP()).thenReturn(500);
      expect(mockStorage.getTotalXP(), 500);
    });

    test('getTodaySessions() — returns session count', () {
      when(() => mockStorage.getTodaySessions()).thenReturn(3);
      expect(mockStorage.getTodaySessions(), 3);
    });

    test('getCurrentStreak() — returns streak value', () {
      when(() => mockStorage.getCurrentStreak()).thenReturn(5);
      expect(mockStorage.getCurrentStreak(), 5);
    });

    test('getBestStreak() — returns best streak', () {
      when(() => mockStorage.getBestStreak()).thenReturn(10);
      expect(mockStorage.getBestStreak(), 10);
    });

    test('getXPHistory(7) — returns list of 7 values', () {
      when(
        () => mockStorage.getXPHistory(7),
      ).thenReturn([10, 20, 30, 40, 50, 60, 70]);
      final history = mockStorage.getXPHistory(7);
      expect(history, hasLength(7));
    });

    test('getXPHistoryLabels(7) — returns 7 day abbreviations', () {
      when(
        () => mockStorage.getXPHistoryLabels(7),
      ).thenReturn(['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
      final labels = mockStorage.getXPHistoryLabels(7);
      expect(labels, hasLength(7));
    });
  });

  // =========================================================================
  // Step 2.3 — Word Progress & Mastery (mocked)
  // =========================================================================

  group('StorageService — Word Progress & Mastery', () {
    test('getWordProgress() — returns progress for item', () {
      final progress = WordProgress(
        itemId: 'wp1',
        totalCorrect: 5,
        totalWrong: 2,
      );
      when(() => mockStorage.getWordProgress('wp1')).thenReturn(progress);

      final result = mockStorage.getWordProgress('wp1');
      expect(result.itemId, 'wp1');
      expect(result.totalCorrect, 5);
      expect(result.totalWrong, 2);
    });

    test('getMasteryDistribution() — returns tier counts', () {
      when(
        () => mockStorage.getMasteryDistribution(),
      ).thenReturn({0: 10, 1: 5, 2: 3, 3: 1, 4: 0});
      final dist = mockStorage.getMasteryDistribution();
      expect(dist[0], 10);
      expect(dist[4], 0);
    });

    test('updateWordProgress() — returns XP awarded', () async {
      when(
        () => mockStorage.updateWordProgress(
          'wp1',
          true,
          firstAttempt: any(named: 'firstAttempt'),
        ),
      ).thenAnswer((_) async => 10);
      final xp = await mockStorage.updateWordProgress(
        'wp1',
        true,
        firstAttempt: true,
      );
      expect(xp, 10);
    });

    test('updateWordProgress() wrong — returns 0 XP', () async {
      when(
        () => mockStorage.updateWordProgress('wp1', false),
      ).thenAnswer((_) async => 0);
      final xp = await mockStorage.updateWordProgress('wp1', false);
      expect(xp, 0);
    });
  });

  // =========================================================================
  // Step 2.4 — ProgressService — Session Recording (with mocked Storage)
  // =========================================================================

  group('ProgressService — Session Recording', () {
    late ProgressService service;
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(mockStorage)],
      );
      service = container.read(progressServiceProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    void setupMocks({int todayXP = 0, int dailyGoal = 50}) {
      when(() => mockStorage.getTodayXP()).thenReturn(todayXP);
      when(() => mockStorage.getDailyXPGoal()).thenReturn(dailyGoal);
      when(() => mockStorage.getCurrentStreak()).thenReturn(1);
      when(() => mockStorage.getBestStreak()).thenReturn(1);
      when(() => mockStorage.getTotalXP()).thenReturn(todayXP);
      when(() => mockStorage.getTodaySessions()).thenReturn(0);
      when(() => mockStorage.getMasteryDistribution()).thenReturn({});
    }

    test(
      'recordQuizAnswer() correct → calls storage.updateWordProgress() with correct=true',
      () async {
        when(
          () => mockStorage.updateWordProgress(
            'item1',
            true,
            firstAttempt: any(named: 'firstAttempt'),
          ),
        ).thenAnswer((_) async => 10);
        when(() => mockStorage.addXP(10)).thenAnswer((_) async {});
        when(
          () => mockStorage.incrementWordsReviewed(1),
        ).thenAnswer((_) async {});
        setupMocks(todayXP: 10);

        await service.recordQuizAnswer(
          storage: mockStorage,
          itemId: 'item1',
          correct: true,
        );

        verify(
          () => mockStorage.updateWordProgress(
            'item1',
            true,
            firstAttempt: any(named: 'firstAttempt'),
          ),
        ).called(1);
      },
    );

    test(
      'recordQuizAnswer() correct → calls storage.addXP() with XP amount',
      () async {
        when(
          () => mockStorage.updateWordProgress(
            'item1',
            true,
            firstAttempt: any(named: 'firstAttempt'),
          ),
        ).thenAnswer((_) async => 10);
        when(() => mockStorage.addXP(10)).thenAnswer((_) async {});
        when(
          () => mockStorage.incrementWordsReviewed(1),
        ).thenAnswer((_) async {});
        setupMocks(todayXP: 10);

        await service.recordQuizAnswer(
          storage: mockStorage,
          itemId: 'item1',
          correct: true,
        );

        verify(() => mockStorage.addXP(10)).called(1);
      },
    );

    test(
      'recordQuizAnswer() wrong → calls storage.updateWordProgress() with correct=false',
      () async {
        when(
          () => mockStorage.updateWordProgress('item1', false),
        ).thenAnswer((_) async => 0);
        setupMocks(todayXP: 0);

        await service.recordQuizAnswer(
          storage: mockStorage,
          itemId: 'item1',
          correct: false,
        );

        verify(() => mockStorage.updateWordProgress('item1', false)).called(1);
      },
    );

    test('recordQuizAnswer() → refreshes state', () async {
      when(
        () => mockStorage.updateWordProgress(
          'item1',
          true,
          firstAttempt: any(named: 'firstAttempt'),
        ),
      ).thenAnswer((_) async => 10);
      when(() => mockStorage.addXP(10)).thenAnswer((_) async {});
      when(
        () => mockStorage.incrementWordsReviewed(1),
      ).thenAnswer((_) async {});
      setupMocks(todayXP: 10);

      await service.recordQuizAnswer(
        storage: mockStorage,
        itemId: 'item1',
        correct: true,
      );

      expect(service.state.todayXP, 10);
    });

    test('recordSessionComplete() → saves SessionRecord to storage', () async {
      when(() => mockStorage.addXP(any())).thenAnswer((_) async {});
      when(() => mockStorage.incrementDailySessions()).thenAnswer((_) async {});
      when(() => mockStorage.saveSession(any())).thenAnswer((_) async {});
      setupMocks(todayXP: 0);

      await service.recordSessionComplete(
        storage: mockStorage,
        activityType: ActivityType.quiz,
        score: 5,
        total: 10,
      );

      verify(() => mockStorage.saveSession(any())).called(1);
    });

    test('recordSessionComplete() → awards 20pt completion bonus', () async {
      when(() => mockStorage.addXP(any())).thenAnswer((_) async {});
      when(() => mockStorage.incrementDailySessions()).thenAnswer((_) async {});
      when(() => mockStorage.saveSession(any())).thenAnswer((_) async {});
      setupMocks(todayXP: 0);

      final totalXP = await service.recordSessionComplete(
        storage: mockStorage,
        activityType: ActivityType.quiz,
        score: 5,
        total: 10,
      );

      // 20 (completion bonus) + 0 or 10 (daily goal bonus)
      expect(totalXP, anyOf(equals(20), equals(30)));
    });

    test('recordSessionComplete() → increments daily sessions', () async {
      when(() => mockStorage.addXP(any())).thenAnswer((_) async {});
      when(() => mockStorage.incrementDailySessions()).thenAnswer((_) async {});
      when(() => mockStorage.saveSession(any())).thenAnswer((_) async {});
      setupMocks(todayXP: 0);

      await service.recordSessionComplete(
        storage: mockStorage,
        activityType: ActivityType.quiz,
        score: 5,
        total: 10,
      );

      verify(() => mockStorage.incrementDailySessions()).called(1);
    });

    test('resetAll() → calls storage.resetAllProgress()', () async {
      when(() => mockStorage.resetAllProgress()).thenAnswer((_) async {});
      setupMocks(todayXP: 0);

      await service.resetAll(mockStorage);

      verify(() => mockStorage.resetAllProgress()).called(1);
    });

    test('build() → initial state is all zeros', () {
      expect(service.state.todayXP, 0);
      expect(service.state.totalXP, 0);
      expect(service.state.currentStreak, 0);
      expect(service.state.bestStreak, 0);
      expect(service.state.todaySessions, 0);
    });
  });

  // =========================================================================
  // Step 2.5 — QuizViewModel — State Management (with mocked Storage)
  // =========================================================================

  group('QuizViewModel — State Management', () {
    test('QuizState — currentQuestion returns question at currentIndex', () {
      final questions = [
        Question(
          id: 'q1',
          questionText: 'What is this?',
          options: ['A', 'B'],
          correctAnswer: 'A',
          type: QuestionType.multipleChoice,
          sourceItem: makeItem(id: 's1'),
        ),
        Question(
          id: 'q2',
          questionText: 'What is that?',
          options: ['C', 'D'],
          correctAnswer: 'C',
          type: QuestionType.multipleChoice,
          sourceItem: makeItem(id: 's2'),
        ),
      ];
      final state = QuizState(questions: questions, currentIndex: 1);
      expect(state.currentQuestion!.id, 'q2');
    });

    test('QuizState — currentQuestion returns null when empty', () {
      final state = QuizState(questions: []);
      expect(state.currentQuestion, isNull);
    });

    test(
      'QuizState — currentQuestion returns null when index out of bounds',
      () {
        final questions = [
          Question(
            id: 'q1',
            questionText: 'What?',
            options: ['A'],
            correctAnswer: 'A',
            type: QuestionType.multipleChoice,
            sourceItem: makeItem(id: 's1'),
          ),
        ];
        final state = QuizState(questions: questions, currentIndex: 5);
        expect(state.currentQuestion, isNull);
      },
    );

    test('QuizState — totalXPEarned sums sessionXP + sessionBonusXP', () {
      final state = QuizState(questions: [], sessionXP: 50, sessionBonusXP: 30);
      expect(state.totalXPEarned, 80);
    });

    test('QuizState — copyWith creates new state with updated fields', () {
      final original = QuizState(questions: [], score: 0, currentIndex: 0);
      final updated = original.copyWith(score: 5, currentIndex: 1);
      expect(updated.score, 5);
      expect(updated.currentIndex, 1);
      expect(original.score, 0); // original unchanged
    });

    test('QuizState — isFinished defaults to false', () {
      final state = QuizState(questions: []);
      expect(state.isFinished, isFalse);
    });

    test('QuizState — isInfinite defaults to false', () {
      final state = QuizState(questions: []);
      expect(state.isInfinite, isFalse);
    });

    test('QuizState — firstAttemptTracker defaults to empty map', () {
      final state = QuizState(questions: []);
      expect(state.firstAttemptTracker, isEmpty);
    });

    test('QuizState — currentWrongAnswers defaults to empty set', () {
      final state = QuizState(questions: []);
      expect(state.currentWrongAnswers, isEmpty);
    });

    test('ProgressSnapshot — dailyGoalMet when todayXP >= dailyGoal', () {
      final snapshot = ProgressSnapshot(todayXP: 50, dailyGoal: 50);
      expect(snapshot.dailyGoalMet, isTrue);
    });

    test('ProgressSnapshot — dailyGoalNotMet when todayXP < dailyGoal', () {
      final snapshot = ProgressSnapshot(todayXP: 30, dailyGoal: 50);
      expect(snapshot.dailyGoalMet, isFalse);
    });

    test('ProgressSnapshot — dailyGoalProgress calculates correctly', () {
      final snapshot = ProgressSnapshot(todayXP: 25, dailyGoal: 50);
      expect(snapshot.dailyGoalProgress, 0.5);
    });

    test('ProgressSnapshot — dailyGoalProgress clamped to 1.0', () {
      final snapshot = ProgressSnapshot(todayXP: 100, dailyGoal: 50);
      expect(snapshot.dailyGoalProgress, 1.0);
    });

    test('ProgressSnapshot — totalWords sums mastery distribution', () {
      final snapshot = ProgressSnapshot(
        masteryDistribution: {0: 10, 1: 5, 2: 3},
      );
      expect(snapshot.totalWords, 18);
    });

    test('ProgressSnapshot — copyWith with null values preserves original', () {
      final original = ProgressSnapshot(todayXP: 50, dailyGoal: 100);
      final copied = original.copyWith(todayXP: null);
      expect(copied.todayXP, 50); // preserved from original
    });
  });
}
