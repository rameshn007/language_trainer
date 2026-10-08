import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../models/flashcard_item.dart';
import '../../models/progress_data.dart';
import '../../services/progress_service.dart';
import '../../services/storage_service.dart';
import '../../services/tts_service.dart';
import 'widgets/flashcard_card_widget.dart';

/// Interactive Flashcards Learning Screen for European Portuguese.
class FlashcardsScreen extends ConsumerStatefulWidget {
  final String? initialCategory;
  final bool initialShuffle;
  final List<FlashcardItem>? initialCards;

  const FlashcardsScreen({
    super.key,
    this.initialCategory,
    this.initialShuffle = true,
    this.initialCards,
  });

  @override
  ConsumerState<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends ConsumerState<FlashcardsScreen>
    with SingleTickerProviderStateMixin {
  // Intentionally process-lifetime in-memory cache for bundled flashcard deck data.
  // Deck items are static asset-bundled data and do not change during runtime.
  static List<FlashcardItem>? _cachedAllCards;

  // Master card list & filtered deck
  List<FlashcardItem> _allCards = [];
  List<FlashcardItem> _deck = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  // Filters
  String _selectedCategory = 'ALL';
  bool _filterFlaggedOnly = false;
  bool _isShuffled = false;

  // Flip Animation
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFlipped = false;

  // Audio & Speed
  late final TtsService _ttsService;
  late final StorageService _storageService;
  late final ProgressService _progressService;
  bool _isSpeaking = false;
  bool _autoSpeak = true;
  double _speechRate = 0.8; // 0.8x default for clear EP pronunciation

  // Auto-advance loop state & cancellation token
  bool _isAutoAdvancing = false;
  int _autoAdvanceGeneration = 0;
  Timer? _recallTimer;
  Timer? _autoAdvanceTimer;
  double _autoAdvanceProgress = 0.0;
  Timer? _autoAdvanceTicker;
  Completer<void>? _stepCompleter;
  final Set<String> _cardsStudiedThisPass = {};
  bool _hasAwardedCompletionThisPass = false;
  int _sessionXpEarned = 0;
  DateTime _sessionStartTime = DateTime.now();

  // Cached metadata for current card to prevent frame-by-frame Hive scans
  int _currentCardMastery = 0;
  bool _isCurrentCardFlagged = false;
  final Set<String> _ratedCardKeysThisSession = {};

  final List<String> _availableCategories = [
    'ALL',
    'EXPLANATION',
    'VERBS',
    'FOOD',
    'HOME',
    'PEOPLE',
    'PLACES',
    'TIME',
    'NUMBERS',
    'PRONOUNS',
    'GRAMMAR',
    'GENERAL',
  ];

  @override
  void initState() {
    super.initState();
    _ttsService = ref.read(ttsServiceProvider);
    _storageService = ref.read(storageServiceProvider);
    _progressService = ref.read(progressServiceProvider.notifier);

    _isShuffled = widget.initialShuffle;
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!.toUpperCase();
    }

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
    );

    if (widget.initialCards != null) {
      _allCards = List.from(widget.initialCards!);
      _applyFilters();
      _isLoading = false;
      if (_deck.isNotEmpty && _autoSpeak) {
        _speakCurrent();
      }
    } else {
      _loadAllCards();
    }
  }

  @override
  void dispose() {
    _stopAutoAdvance(updateState: false);
    _flipController.dispose();
    _ttsService.stop();
    super.dispose();
  }

  /// Load grammar cards and vocabulary items from bundled JSON (or memory cache)
  Future<void> _loadAllCards() async {
    if (_cachedAllCards != null && _cachedAllCards!.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _allCards = List.from(_cachedAllCards!);
        _applyFilters();
        _isLoading = false;
      });
      if (_deck.isNotEmpty && _autoSpeak) {
        _speakCurrent();
      }
      return;
    }

    try {
      final List<FlashcardItem> loaded = [];

      // 1. Load #G1 through #G7 Grammar Cards
      try {
        final grammarRaw = await rootBundle.loadString(
          'assets/data/grammar_flashcards.json',
        );
        final List<dynamic> grammarList = jsonDecode(grammarRaw);
        for (final item in grammarList) {
          loaded.add(FlashcardItem.fromGrammarJson(item));
        }
      } catch (e) {
        debugPrint('Error loading grammar flashcards: $e');
      }

      // 2. Load Vocabulary items (#1 to #858+)
      try {
        final vocabRaw = await rootBundle.loadString('assets/vocabulary.json');
        final List<dynamic> vocabList = jsonDecode(vocabRaw);
        for (final item in vocabList) {
          loaded.add(FlashcardItem.fromVocabJson(item));
        }
      } catch (e) {
        debugPrint('Error loading vocabulary.json: $e');
      }

      _cachedAllCards = loaded;

      if (!mounted) return;

      setState(() {
        _allCards = loaded;
        _applyFilters();
        _isLoading = false;
      });

      // Speak initial card if auto-speak enabled
      if (_deck.isNotEmpty && _autoSpeak) {
        _speakCurrent();
      }
    } catch (e) {
      debugPrint('Error initializing flashcards: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Update cached metadata for the current card to avoid per-frame Hive scans
  void _updateCurrentCardMetadata() {
    if (_deck.isEmpty || _currentIndex >= _deck.length) {
      _currentCardMastery = 0;
      _isCurrentCardFlagged = false;
      return;
    }
    final item = _deck[_currentIndex];
    final flagKey = item.languageItemId ?? item.id;
    _isCurrentCardFlagged = _storageService.isItemFlagged(flagKey);

    if (item.isGrammarCard || item.languageItemId == null) {
      _currentCardMastery = 0;
    } else {
      _currentCardMastery =
          _storageService.getItem(item.languageItemId!)?.masteryLevel ?? 0;
    }
  }

  /// Filter cards by category, and flagged status
  void _applyFilters() {
    _stopAutoAdvance(updateState: false);
    _cardsStudiedThisPass.clear();
    _hasAwardedCompletionThisPass = false;
    List<FlashcardItem> result = List.from(_allCards);

    // Filter by Category
    if (_selectedCategory != 'ALL') {
      result = result
          .where((c) => c.category.toUpperCase() == _selectedCategory)
          .toList();
    }

    // Filter by Flagged / Bookmarked
    if (_filterFlaggedOnly) {
      result = result.where((c) {
        final flagKey = c.languageItemId ?? c.id;
        return _storageService.isItemFlagged(flagKey);
      }).toList();
    }

    // Apply Shuffle or Natural Card Ordering
    if (_isShuffled) {
      result.shuffle();
    } else {
      // Natural order: Grammar cards first (#G1..#G7), then numbered cards (#1..#858)
      result.sort((a, b) {
        if (a.isGrammarCard && !b.isGrammarCard) return -1;
        if (!a.isGrammarCard && b.isGrammarCard) return 1;
        final aNum = int.tryParse(a.id) ?? 9999;
        final bNum = int.tryParse(b.id) ?? 9999;
        return aNum.compareTo(bNum);
      });
    }

    _deck = result;
    _currentIndex = 0;
    _resetFlip();
    _updateCurrentCardMetadata();
  }

  void _resetFlip() {
    _flipController.reset();
    _isFlipped = false;
  }

  void _toggleFlip() {
    if (_flipController.isAnimating) return;
    final willBeFlipped = !_isFlipped;
    setState(() {
      if (_isFlipped) {
        _flipController.reverse();
        _isFlipped = false;
        _ttsService.stop();
        _isSpeaking = false;
      } else {
        _flipController.forward();
        _isFlipped = true;
        if (_deck.isNotEmpty && _currentIndex < _deck.length) {
          _cardsStudiedThisPass.add(_deck[_currentIndex].id);
        }
      }
    });

    if (willBeFlipped && _autoSpeak) {
      _speakCurrentEnglish();
    }
  }

  /// Speaks only the Portuguese word/phrase (white text on the front of the card).
  /// The phonetic pronunciation guide underneath (e.g. [TAHN-too... KOH-moo]) is
  /// strictly visual for learner reference and is never read aloud.
  Future<void> _speakCurrent({double? rate}) async {
    if (_deck.isEmpty || _currentIndex >= _deck.length) return;
    final item = _deck[_currentIndex];

    // Only speak the Portuguese text shown in white.
    // Strip any bracketed pronunciation guides if present and smooth out ellipses.
    String text = item.portuguese;
    text = text.replaceAll(RegExp(r'\[.*?\]'), '');
    text = text.replaceAll('...', ' ').replaceAll('…', ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return;

    setState(() => _isSpeaking = true);
    try {
      await _ttsService.stop();
      await _ttsService.speak(
        text,
        language: 'pt-PT',
        rate: rate ?? _speechRate,
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  Future<void> _speakCurrentEnglish({double? rate}) async {
    if (_deck.isEmpty || _currentIndex >= _deck.length) return;
    final item = _deck[_currentIndex];
    final text = item.english;
    if (text.trim().isEmpty) return;

    final cleanText = text.replaceAll('/', ', ');

    setState(() => _isSpeaking = true);
    try {
      await _ttsService.stop();
      await _ttsService.speak(
        cleanText,
        language: 'en-US',
        rate: rate ?? 1.0,
      );

      // If there is an example use in a sentence, read it in both pt-PT and en-US
      if (item.examplePt != null && item.examplePt!.trim().isNotEmpty) {
        if (!_isSpeaking || !mounted) return;
        await Future.delayed(const Duration(milliseconds: 350));
        if (!_isSpeaking || !mounted) return;
        await _ttsService.speak(
          item.examplePt!.trim(),
          language: 'pt-PT',
          rate: rate ?? _speechRate,
        );

        if (item.exampleEn != null && item.exampleEn!.trim().isNotEmpty) {
          if (!_isSpeaking || !mounted) return;
          await Future.delayed(const Duration(milliseconds: 300));
          if (!_isSpeaking || !mounted) return;
          await _ttsService.speak(
            item.exampleEn!.trim(),
            language: 'en-US',
            rate: rate ?? 1.0,
          );
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  void _nextCard() {
    if (_deck.isEmpty) return;
    if (_isAutoAdvancing) {
      _stopAutoAdvance(updateState: false);
    }
    _ttsService.stop();
    _isSpeaking = false;
    if (_currentIndex < _deck.length - 1) {
      setState(() {
        _currentIndex++;
        _resetFlip();
        _updateCurrentCardMetadata();
      });
      if (_autoSpeak) {
        _speakCurrent();
      }
    } else {
      _showCompletionDialog();
    }
  }

  void _prevCard() {
    if (_deck.isEmpty) return;
    if (_isAutoAdvancing) {
      _stopAutoAdvance(updateState: false);
    }
    _ttsService.stop();
    _isSpeaking = false;
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _resetFlip();
        _updateCurrentCardMetadata();
      });
      if (_autoSpeak) {
        _speakCurrent();
      }
    }
  }

  /// Auto-Advance Mode: Plays audio -> flips to back -> waits -> advances to next card
  void _toggleAutoAdvance() {
    if (_isAutoAdvancing) {
      _stopAutoAdvance();
    } else {
      setState(() {
        _isAutoAdvancing = true;
      });
      _runAutoAdvanceStep();
    }
  }

  void _stopAutoAdvance({bool updateState = true}) {
    _autoAdvanceGeneration++;
    _recallTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTicker?.cancel();
    _recallTimer = null;
    _autoAdvanceTimer = null;
    _autoAdvanceTicker = null;
    _ttsService.stop();
    _isSpeaking = false;
    if (_stepCompleter != null && !_stepCompleter!.isCompleted) {
      _stepCompleter!.complete();
    }
    _stepCompleter = null;
    _isAutoAdvancing = false;
    _autoAdvanceProgress = 0.0;
    if (updateState && mounted) {
      setState(() {});
    }
  }

  void _runAutoAdvanceStep() async {
    if (!_isAutoAdvancing || !mounted || _deck.isEmpty) return;
    final stepGen = ++_autoAdvanceGeneration;

    // 1. Ensure front face is showing
    if (_isFlipped) {
      _resetFlip();
    }

    // 2. Speak Portuguese and await completion
    if (_autoSpeak) {
      await _speakCurrent();
    }
    if (!_isAutoAdvancing || !mounted || _autoAdvanceGeneration != stepGen || _deck.isEmpty) return;

    // 3. Recall countdown with progress bar before flipping to back face
    final currentCard = _deck[_currentIndex];
    final bool hasPronunciation = currentCard.formattedPronunciation != null &&
        currentCard.formattedPronunciation!.trim().isNotEmpty;
    final bool hasLongPhrase = currentCard.portuguese.length > 25 || currentCard.isGrammarCard;
    final int recallMillis = hasLongPhrase
        ? 2600
        : (hasPronunciation ? 2200 : 2000);
    const int tickMillis = 50;
    int recallElapsed = 0;
    final recallCompleter = Completer<void>();
    _stepCompleter = recallCompleter;

    _recallTimer?.cancel();
    _recallTimer = Timer.periodic(
      const Duration(milliseconds: tickMillis),
      (timer) {
        if (!_isAutoAdvancing || !mounted || _autoAdvanceGeneration != stepGen || _deck.isEmpty) {
          timer.cancel();
          if (!recallCompleter.isCompleted) recallCompleter.complete();
          return;
        }
        recallElapsed += tickMillis;
        setState(() {
          _autoAdvanceProgress = (recallElapsed / recallMillis).clamp(0.0, 1.0);
        });
        if (recallElapsed >= recallMillis) {
          timer.cancel();
          if (!recallCompleter.isCompleted) recallCompleter.complete();
        }
      },
    );

    await recallCompleter.future;
    if (!_isAutoAdvancing || !mounted || _autoAdvanceGeneration != stepGen || _deck.isEmpty) return;

    setState(() => _autoAdvanceProgress = 0.0);

    // 4. Flip to back face
    setState(() {
      _flipController.forward();
      _isFlipped = true;
      if (_deck.isNotEmpty && _currentIndex < _deck.length) {
        _cardsStudiedThisPass.add(_deck[_currentIndex].id);
      }
    });

    // 5. Speak English (and example sentence in PT & EN) and await completion so audio is NEVER truncated
    if (_autoSpeak) {
      await _speakCurrentEnglish();
    }
    if (!_isAutoAdvancing || !mounted || _autoAdvanceGeneration != stepGen || _deck.isEmpty) return;

    // 6. Reading countdown with progress bar post speech reading
    final cardBack = _deck[_currentIndex];
    final hasExample = cardBack.examplePt != null && cardBack.examplePt!.trim().isNotEmpty;
    final int totalMillis = cardBack.isGrammarCard
        ? 2200
        : (hasExample ? 2000 : 1400);
    int elapsed = 0;
    final readingCompleter = Completer<void>();
    _stepCompleter = readingCompleter;

    _autoAdvanceTicker?.cancel();
    _autoAdvanceTicker = Timer.periodic(
      const Duration(milliseconds: tickMillis),
      (timer) {
        if (!_isAutoAdvancing || !mounted || _autoAdvanceGeneration != stepGen || _deck.isEmpty) {
          timer.cancel();
          if (!readingCompleter.isCompleted) readingCompleter.complete();
          return;
        }
        elapsed += tickMillis;
        setState(() {
          _autoAdvanceProgress = (elapsed / totalMillis).clamp(0.0, 1.0);
        });
        if (elapsed >= totalMillis) {
          timer.cancel();
          if (!readingCompleter.isCompleted) readingCompleter.complete();
        }
      },
    );

    await readingCompleter.future;
    if (!_isAutoAdvancing || !mounted || _autoAdvanceGeneration != stepGen || _deck.isEmpty) return;

    setState(() => _autoAdvanceProgress = 0.0);

    // 7. Advance to next card without redundant _speakCurrent()
    if (_currentIndex < _deck.length - 1) {
      setState(() {
        _currentIndex++;
        _resetFlip();
        _updateCurrentCardMetadata();
      });
      _runAutoAdvanceStep();
    } else {
      _stopAutoAdvance();
      _showCompletionDialog();
    }
  }

  /// Toggle Flag / Bookmark for the current card in StorageService
  Future<void> _toggleFlagCurrent() async {
    if (_deck.isEmpty) return;
    final item = _deck[_currentIndex];
    final key = item.languageItemId ?? item.id;
    await _storageService.toggleItemFlagged(key);
    setState(() {
      _updateCurrentCardMetadata();
    });
  }

  /// Self-assessment rating: records quiz answer via ProgressService (earns real XP, obeys tier thresholds)
  Future<void> _rateCurrent(int level) async {
    if (_deck.isEmpty) return;
    final item = _deck[_currentIndex];
    if (item.isGrammarCard || item.languageItemId == null) return;
    final key = item.languageItemId!;

    final alreadyRated = _ratedCardKeysThisSession.contains(key);
    final isCorrect = level >= 3;

    if (!alreadyRated) {
      _cardsStudiedThisPass.add(item.id);
      _ratedCardKeysThisSession.add(key);
      final xp = await _progressService.recordQuizAnswer(
        storage: _storageService,
        itemId: key,
        correct: isCorrect,
        firstAttempt: true,
      );
      _sessionXpEarned += xp;

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isCorrect ? Icons.star_rounded : Icons.refresh_rounded,
                  color: isCorrect ? Colors.amber : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  xp > 0
                      ? 'Progress saved! +$xp XP awarded'
                      : (isCorrect ? 'Marked as known' : 'Marked for practice'),
                ),
              ],
            ),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card already reviewed this session'),
            duration: Duration(milliseconds: 900),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    setState(() {
      _updateCurrentCardMetadata();
    });
  }

  void _showCompletionDialog() {
    if (_deck.isEmpty) return;
    final theme = Theme.of(context);
    final durationSeconds =
        DateTime.now().difference(_sessionStartTime).inSeconds;
    final cardsReviewed = _cardsStudiedThisPass.length;

    // Guard: Only award session completion once per pass, and only if cards were actually studied
    if (!_hasAwardedCompletionThisPass && cardsReviewed > 0) {
      _hasAwardedCompletionThisPass = true;
      _progressService.recordSessionComplete(
        storage: _storageService,
        activityType: ActivityType.flashcards,
        score: cardsReviewed,
        total: cardsReviewed,
        durationSeconds: durationSeconds,
        sessionXP: _sessionXpEarned,
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text('Deck Completed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parabéns! You finished studying the ${_selectedCategory.toLowerCase()} deck.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Text(
              'Cards reviewed: $cardsReviewed\nXP Earned: $_sessionXpEarned XP',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _currentIndex = 0;
                _resetFlip();
                _cardsStudiedThisPass.clear();
                _ratedCardKeysThisSession.clear();
                _hasAwardedCompletionThisPass = false;
                _sessionXpEarned = 0;
                _sessionStartTime = DateTime.now();
                _updateCurrentCardMetadata();
              });
            },
            child: const Text('Restart Deck'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _cycleSpeechSpeed() {
    setState(() {
      if (_speechRate >= 1.0) {
        _speechRate = 0.5; // Slow
      } else if (_speechRate >= 0.75) {
        _speechRate = 1.0; // Normal
      } else {
        _speechRate = 0.8; // Clear
      }
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Speech Speed: ${_speechRate}x"),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF13161C) : const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Flashcards',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            if (_deck.isNotEmpty)
              Text(
                'Card ${_currentIndex + 1} of ${_deck.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
          ],
        ),
        actions: [
          // Speech Speed Button
          IconButton(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              child: Text(
                '${_speechRate}x',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            tooltip: 'Change speech speed (${_speechRate}x)',
            onPressed: _cycleSpeechSpeed,
          ),
          // Auto-Speak Toggle
          IconButton(
            icon: Icon(
              _autoSpeak ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: _autoSpeak ? theme.colorScheme.primary : Colors.grey,
            ),
            tooltip: _autoSpeak ? 'Auto-speak ON' : 'Auto-speak OFF',
            onPressed: () {
              setState(() => _autoSpeak = !_autoSpeak);
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_autoSpeak ? 'Auto-speak enabled' : 'Auto-speak muted'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          // Shuffle Toggle
          IconButton(
            icon: Icon(
              Icons.shuffle_rounded,
              color: _isShuffled ? theme.colorScheme.primary : Colors.grey,
            ),
            tooltip: _isShuffled ? 'Shuffled (tap for sequential)' : 'Sequential (tap to shuffle)',
            onPressed: () {
              setState(() {
                _isShuffled = !_isShuffled;
                _applyFilters();
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Deck Filter Row
                _buildFilterBar(),

                // Linear Deck Progress Indicator
                if (_deck.isNotEmpty)
                  LinearProgressIndicator(
                    value: (_currentIndex + 1) / _deck.length,
                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _deck[_currentIndex].categoryColor,
                    ),
                    minHeight: 3,
                  ),

                // Auto-Advance countdown bar
                if (_isAutoAdvancing)
                  LinearProgressIndicator(
                    value: _autoAdvanceProgress,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isFlipped
                          ? Colors.amber.shade600
                          : _deck[_currentIndex].categoryColor,
                    ),
                    minHeight: 3.5,
                  ),

                // Main Flashcard View
                Expanded(
                  child: _deck.isEmpty
                      ? _buildEmptyState()
                      : _buildCardGestureArea(),
                ),

                // Bottom Action Bar
                _buildBottomControls(),
              ],
            ),
    );
  }

  /// Horizontal scrolling category chips & bookmark toggle
  Widget _buildFilterBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // Bookmark Filter Chip
          FilterChip(
            label: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bookmark_rounded, size: 14, color: Colors.amber),
                SizedBox(width: 4),
                Text('Bookmarked'),
              ],
            ),
            selected: _filterFlaggedOnly,
            onSelected: (selected) {
              setState(() {
                _filterFlaggedOnly = selected;
                _applyFilters();
              });
            },
          ),
          const SizedBox(width: 8),

          // Categories
          ..._availableCategories.map((cat) {
            final isSelected = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(
                  cat == 'ALL' ? 'All (${_allCards.length})' : cat,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                selected: isSelected,
                selectedColor: isDark
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                    : Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                checkmarkColor: Theme.of(context).colorScheme.primary,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedCategory = cat;
                      _applyFilters();
                    });
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Flashcard interactive gesture area (Swipe left/right, Tap to flip)
  Widget _buildCardGestureArea() {
    final currentItem = _deck[_currentIndex];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe Left -> Next Card
          if (details.primaryVelocity != null && details.primaryVelocity! < -250) {
            _nextCard();
          }
          // Swipe Right -> Previous Card
          else if (details.primaryVelocity != null && details.primaryVelocity! > 250) {
            _prevCard();
          }
        },
        child: AnimatedBuilder(
          animation: _flipAnimation,
          builder: (context, child) {
            return FlashcardCardWidget(
              item: currentItem,
              flipProgress: _flipAnimation.value,
              onFlip: _toggleFlip,
              onSpeak: () => _speakCurrent(),
              onSpeakSlow: () => _speakCurrent(rate: 0.5),
              onSpeakEnglish: () => _speakCurrentEnglish(),
              isSpeaking: _isSpeaking,
              isFlagged: _isCurrentCardFlagged,
              onToggleFlag: _toggleFlagCurrent,
              onRateMastery: _rateCurrent,
              currentMastery: _currentCardMastery,
              autoAdvanceProgress: _autoAdvanceProgress,
              isAutoAdvancing: _isAutoAdvancing,
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.style_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No cards found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try clearing your active filters or bookmarks.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () {
              setState(() {
                _selectedCategory = 'ALL';
                _filterFlaggedOnly = false;
                _applyFilters();
              });
            },
            child: const Text('Reset Filters'),
          ),
        ],
      ),
    );
  }

  /// Bottom navigation controls (Previous, Flip, Auto-Advance, Next)
  Widget _buildBottomControls() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Previous Card
            IconButton.filledTonal(
              icon: const Icon(Icons.chevron_left_rounded, size: 28),
              tooltip: 'Previous Card (Swipe Right)',
              onPressed: _currentIndex > 0 ? _prevCard : null,
            ),

            // Tap to Flip
            OutlinedButton.icon(
              onPressed: _toggleFlip,
              icon: Icon(
                _isFlipped
                    ? Icons.flip_to_front_rounded
                    : Icons.flip_to_back_rounded,
                size: 20,
              ),
              label: Text(_isFlipped ? 'Show Front' : 'Flip Card'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            // Auto-Advance Play / Pause
            IconButton.filled(
              icon: Icon(
                _isAutoAdvancing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 26,
              ),
              tooltip: _isAutoAdvancing
                  ? 'Pause Auto-Advance'
                  : 'Start Auto-Advance (Hands-Free)',
              style: IconButton.styleFrom(
                backgroundColor: _isAutoAdvancing
                    ? Colors.amber.shade700
                    : theme.colorScheme.primary,
              ),
              onPressed: _deck.isNotEmpty ? _toggleAutoAdvance : null,
            ),

            // Next Card
            IconButton.filledTonal(
              icon: const Icon(Icons.chevron_right_rounded, size: 28),
              tooltip: 'Next Card (Swipe Left)',
              onPressed: _currentIndex < _deck.length - 1 ? _nextCard : null,
            ),
          ],
        ),
      ),
    );
  }
}
