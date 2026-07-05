import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/language_item.dart';
import '../../main.dart';

class ListenRepeatState {
  final LanguageItem? currentItem;
  final List<LanguageItem> pool;
  final List<LanguageItem> shuffledPool;
  final bool isPlaying;
  final int totalWordsSeen;

  ListenRepeatState({
    this.currentItem,
    this.pool = const [],
    this.shuffledPool = const [],
    this.isPlaying = false,
    this.totalWordsSeen = 0,
  });

  ListenRepeatState copyWith({
    LanguageItem? currentItem,
    List<LanguageItem>? pool,
    List<LanguageItem>? shuffledPool,
    bool? isPlaying,
    int? totalWordsSeen,
  }) {
    return ListenRepeatState(
      currentItem: currentItem ?? this.currentItem,
      pool: pool ?? this.pool,
      shuffledPool: shuffledPool ?? this.shuffledPool,
      isPlaying: isPlaying ?? this.isPlaying,
      totalWordsSeen: totalWordsSeen ?? this.totalWordsSeen,
    );
  }
}

class ListenRepeatViewModel extends Notifier<ListenRepeatState> {
  final Random _random = Random();

  @override
  ListenRepeatState build() {
    return ListenRepeatState();
  }

  Future<void> startSession() async {
    final storage = ref.read(storageServiceProvider);
    final allItems = storage.getAllItems();

    if (allItems.isEmpty) return;

    // Shuffle the full pool for randomization
    final shuffled = List<LanguageItem>.from(allItems)..shuffle(_random);

    state = ListenRepeatState(
      pool: allItems,
      shuffledPool: shuffled,
      isPlaying: true,
      totalWordsSeen: 0,
    );

    // Pick first word
    _pickRandomWord();
  }

  void _pickRandomWord() {
    if (state.shuffledPool.isEmpty) return;

    final randomIndex = _random.nextInt(state.shuffledPool.length);
    final item = state.shuffledPool[randomIndex];

    state = state.copyWith(
      currentItem: item,
      totalWordsSeen: state.totalWordsSeen + 1,
    );
  }

  void nextWord() {
    if (!state.isPlaying) return;
    _pickRandomWord();
  }

  void shufflePool() {
    if (!state.isPlaying || state.pool.isEmpty) return;

    final shuffled = List<LanguageItem>.from(state.pool)..shuffle(_random);
    state = state.copyWith(shuffledPool: shuffled);

    // Pick a new random word from the reshuffled pool
    _pickRandomWord();
  }

  void stopSession() {
    state = ListenRepeatState(
      currentItem: null,
      pool: const [],
      shuffledPool: const [],
      isPlaying: false,
      totalWordsSeen: 0,
    );
  }
}

final listenRepeatViewModelProvider =
    NotifierProvider<ListenRepeatViewModel, ListenRepeatState>(
      ListenRepeatViewModel.new,
    );
