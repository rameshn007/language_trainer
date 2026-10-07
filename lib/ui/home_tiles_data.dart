import 'package:flutter/material.dart';

import 'exercise/exercise_list_screen.dart';
import 'exercise/exercise_screen.dart';
import 'listen_repeat/listen_repeat_screen.dart';
import 'flashcards/flashcards_screen.dart';
import 'phrase_trainer_screen.dart';
import 'quiz/category_selection_screen.dart';
import 'quiz/grammar_quiz_screen.dart';
import 'quiz/interrogative_quiz_screen.dart';
import 'quiz/preposition_quiz_screen.dart';
import 'quiz/quiz_category.dart';
import 'quiz/quiz_screen.dart';
import 'quiz/verb_conjugation_screen.dart';
import 'quiz/verb_phrase_trainer_screen.dart';
import 'vocabulary/vocabulary_list_screen.dart';
import 'voice_trainer_screen.dart';

/// Representation of a single interactive action tile on the home screen.
class HomeTileItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? badge;
  final void Function(Offset offset)? onPressed;

  const HomeTileItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.badge,
    this.onPressed,
  });
}

/// Representation of a grouped section of tiles on the home screen.
class HomeSectionData {
  final String id;
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<HomeTileItem> exercises;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const HomeSectionData({
    required this.id,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.exercises,
    this.actionLabel,
    this.onActionTap,
  });
}

/// Category filter pill with self-derived tile counts.
class HomeCategoryPill {
  final String id;
  final String label;
  final IconData icon;
  final int count;

  const HomeCategoryPill({
    required this.id,
    required this.label,
    required this.icon,
    required this.count,
  });
}

/// Builder responsible for assembling home screen sections and pills.
///
/// Keeps `HomeScreen` layout-only and guarantees that pill counts are computed
/// directly from the rendered section data without manual duplication.
class HomeSectionsBuilder {
  final BuildContext context;
  final bool isQuizDisabled;
  final void Function(Widget screen, Offset offset) pushScreen;
  final void Function(String categoryId) selectCategory;

  late final Map<String, List<HomeSectionData>> _sectionsByTab = _buildAllSections();

  HomeSectionsBuilder({
    required this.context,
    required this.isQuizDisabled,
    required this.pushScreen,
    required this.selectCategory,
  });

  /// Computes filter pills with self-correcting counts derived from section items.
  List<HomeCategoryPill> getPills() {
    return [
      HomeCategoryPill(
        id: 'all',
        label: 'All',
        icon: Icons.auto_awesome_mosaic_rounded,
        count: _countExercisesFor('all'),
      ),
      HomeCategoryPill(
        id: 'exercises',
        label: 'Exercises',
        icon: Icons.assignment_rounded,
        count: _countExercisesFor('exercises'),
      ),
      HomeCategoryPill(
        id: 'topics',
        label: 'Topics',
        icon: Icons.category_rounded,
        count: _countExercisesFor('topics'),
      ),
      HomeCategoryPill(
        id: 'vocab',
        label: 'Vocabulary',
        icon: Icons.menu_book_rounded,
        count: _countExercisesFor('vocab'),
      ),
      HomeCategoryPill(
        id: 'grammar',
        label: 'Grammar',
        icon: Icons.school_rounded,
        count: _countExercisesFor('grammar'),
      ),
      HomeCategoryPill(
        id: 'speaking',
        label: 'Speaking',
        icon: Icons.mic_rounded,
        count: _countExercisesFor('speaking'),
      ),
    ];
  }

  int _countExercisesFor(String categoryId) {
    final sections = _sectionsByTab[categoryId] ?? const [];
    return sections.fold<int>(0, (sum, sec) => sum + sec.exercises.length);
  }

  /// Returns the sections and tiles for the currently selected filter tab.
  List<HomeSectionData> getSections(String selectedCategory) {
    return _sectionsByTab[selectedCategory] ?? _sectionsByTab['all'] ?? const [];
  }

  Map<String, List<HomeSectionData>> _buildAllSections() {
    // ── Exercise Units (18 curriculum units + Question Builder + Directory) ──
    final sentenceBuilder = HomeTileItem(
      id: 'ex_unit_10',
      title: 'Sentence Builder',
      subtitle: 'Word Order & Pronouns',
      icon: Icons.reorder_rounded,
      color: Colors.indigo.shade600,
      badge: 'Unit 10',
      onPressed: (offset) {
        pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 10: Word Order & Pronouns',
            unitPath: 'assets/data/exercises/unit_10.json',
          ),
          offset,
        );
      },
    );

    final questionBuilder = HomeTileItem(
      id: 'ex_question_builder',
      title: 'Question Builder',
      subtitle: 'Make questions with interrogatives',
      icon: Icons.chat_rounded,
      color: Colors.lightBlue.shade700,
      badge: 'Questions',
      onPressed: (offset) {
        pushScreen(
          const ExerciseScreen(
            unitName: 'Question Builder: Make the Question',
            unitPath: 'assets/data/exercises/question_builder.json',
          ),
          offset,
        );
      },
    );

    final verbConjugationQuiz = HomeTileItem(
      id: 'ex_verb_quiz',
      title: 'Verb Conjugation Quiz',
      subtitle: 'Practice all verb conjugations',
      icon: Icons.school_rounded,
      color: Colors.purple.shade600,
      badge: 'All Verbs',
      onPressed: (offset) {
        pushScreen(
          const ExerciseScreen(
            unitName: 'Verb Conjugation Quiz',
            unitPath: 'assets/data/exercises/verb_conjugation_quiz.json',
          ),
          offset,
        );
      },
    );

    final prepositionalPronouns = HomeTileItem(
      id: 'ex_prep_pronouns',
      title: 'Prepositional Pronouns',
      subtitle: 'Comigo, contigo, connosco...',
      icon: Icons.link_rounded,
      color: Colors.pink.shade700,
      badge: 'Pronouns',
      onPressed: (offset) {
        pushScreen(
          const ExerciseScreen(
            unitName: 'Prepositional Pronouns',
            unitPath: 'assets/data/exercises/prepositional_pronouns.json',
          ),
          offset,
        );
      },
    );

    final indirectObjectPronouns = HomeTileItem(
      id: 'ex_indirect_obj',
      title: 'Indirect Pronouns',
      subtitle: 'Me, te, lhe, nos, vos, lhes',
      icon: Icons.contact_mail_rounded,
      color: Colors.cyan.shade700,
      badge: 'Pronouns',
      onPressed: (offset) {
        pushScreen(
          const ExerciseScreen(
            unitName: 'Indirect Object Pronouns',
            unitPath: 'assets/data/exercises/indirect_object_pronouns.json',
          ),
          offset,
        );
      },
    );

    final conjunctions = HomeTileItem(
      id: 'ex_conjunctions',
      title: 'Conjunctions & Connectors',
      subtitle: 'Quando, Porque, Mas, E',
      icon: Icons.alt_route_rounded,
      color: Colors.orange.shade700,
      badge: 'Connectors',
      onPressed: (offset) {
        pushScreen(
          const ExerciseScreen(
            unitName: 'Conjunctions: Quando, Porque, Mas, E',
            unitPath: 'assets/data/exercises/unit_conjunctions.json',
          ),
          offset,
        );
      },
    );

    final comparatives = HomeTileItem(
      id: 'ex_comparatives',
      title: 'Comparatives & Duration',
      subtitle: 'Tão... como, há vs desde',
      icon: Icons.compare_arrows_rounded,
      color: Colors.deepOrange.shade600,
      badge: 'Unit 11',
      onPressed: (offset) {
        pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 11: Comparatives, Time & Life Events',
            unitPath:
                'assets/data/exercises/unit_comparatives_and_duration.json',
          ),
          offset,
        );
      },
    );

    final sentenceTransformations = HomeTileItem(
      id: 'ex_sentence_trans',
      title: 'Transformations & Syntax',
      subtitle: 'Future tense & comparatives',
      icon: Icons.transform_rounded,
      color: Colors.deepPurple.shade700,
      badge: 'Advanced',
      onPressed: (offset) {
        pushScreen(
          const ExerciseScreen(
            unitName: 'Sentence Transformations & Grammar',
            unitPath: 'assets/data/exercises/unit_sentence_transformations.json',
          ),
          offset,
        );
      },
    );

    final unit2IrregularVerbs = HomeTileItem(
      id: 'ex_unit_2',
      title: 'Irregular Verbs (Pt 1)',
      subtitle: 'Sentir, Dormir, etc.',
      icon: Icons.school_rounded,
      color: Colors.deepPurple.shade600,
      badge: 'Unit 2',
      onPressed: (offset) {
        pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 2: Irregular Verbs (Part 1)',
            unitPath: 'assets/data/exercises/unit_2.json',
            hintPath: 'assets/images/unit_2_hint.png',
          ),
          offset,
        );
      },
    );

    final unit3Ser = HomeTileItem(
      id: 'ex_unit_3',
      title: 'Verbo Ser vs Ficar',
      subtitle: 'Identity vs Location',
      icon: Icons.person_rounded,
      color: Colors.blue.shade700,
      badge: 'Unit 3',
      onPressed: (offset) {
        pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 3: Verbo Ser',
            unitPath: 'assets/data/exercises/unit_3.json',
            hintPath: 'assets/images/unit_3_hint.png',
          ),
          offset,
        );
      },
    );

    final unit4IrregularVerbs = HomeTileItem(
      id: 'ex_unit_4',
      title: 'Irregular Verbs (Pt 2)',
      subtitle: 'Ter, Ver, Fazer, Dizer',
      icon: Icons.build_rounded,
      color: Colors.indigo.shade700,
      badge: 'Unit 4',
      onPressed: (offset) {
        pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 4: Irregular Verbs (Part 2)',
            unitPath: 'assets/data/exercises/unit_4.json',
            hintPath: 'assets/images/unit_4_hint.png',
          ),
          offset,
        );
      },
    );

    final unit5RegularVerbs = HomeTileItem(
      id: 'ex_unit_5',
      title: 'Regular Verbs',
      subtitle: 'Presente: -ar, -er, -ir',
      icon: Icons.forum_rounded,
      color: Colors.teal.shade700,
      badge: 'Unit 5',
      onPressed: (offset) {
        pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 5: Regular Verbs',
            unitPath: 'assets/data/exercises/unit_5.json',
            hintPath: 'assets/images/unit_5_hint.png',
          ),
          offset,
        );
      },
    );

    final unit12Rooms = HomeTileItem(
      id: 'ex_unit_12',
      title: 'Rooms in the House',
      subtitle: 'Cozinha, sala, quarto',
      icon: Icons.home_rounded,
      color: Colors.green.shade700,
      badge: 'Unit 12',
      onPressed: (offset) {
        pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 12: Rooms in the House',
            unitPath: 'assets/data/exercises/unit_rooms_in_the_house.json',
          ),
          offset,
        );
      },
    );

    final unit13HouseholdItems = HomeTileItem(
      id: 'ex_unit_13',
      title: 'Household Items',
      subtitle: 'Frigorífico, loiça, utensílios',
      icon: Icons.kitchen_rounded,
      color: Colors.teal.shade600,
      badge: 'Unit 13',
      onPressed: (offset) {
        pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 13: Household Items & Appliances',
            unitPath: 'assets/data/exercises/unit_household_items.json',
          ),
          offset,
        );
      },
    );

    final unit14BodyHealth = HomeTileItem(
      id: 'ex_unit_14',
      title: 'Body Parts & Health',
      subtitle: 'Corpo humano, dores, sintomas',
      icon: Icons.health_and_safety_rounded,
      color: Colors.red.shade700,
      badge: 'Unit 14',
      onPressed: (offset) {
        pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 14: Parts of the Body & Health',
            unitPath: 'assets/data/exercises/unit_body_parts_and_health.json',
          ),
          offset,
        );
      },
    );

    final unit15EverydayItems = HomeTileItem(
      id: 'ex_unit_15',
      title: 'Everyday Items',
      subtitle: 'Telemóvel, chaves, carteira',
      icon: Icons.backpack_rounded,
      color: Colors.amber.shade800,
      badge: 'Unit 15',
      onPressed: (offset) {
        pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 15: Everyday Items & Belongings',
            unitPath: 'assets/data/exercises/unit_everyday_items.json',
          ),
          offset,
        );
      },
    );

    final unit6NewVocab = HomeTileItem(
      id: 'ex_unit_6',
      title: 'New Vocabulary',
      subtitle: 'Practice words from new.md',
      icon: Icons.menu_book_rounded,
      color: Colors.blue.shade600,
      badge: 'Unit 6',
      onPressed: (offset) {
        pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 6: New Vocabulary',
            unitPath: 'assets/data/exercises/unit_6.json',
          ),
          offset,
        );
      },
    );

    final unit7MoreVocab = HomeTileItem(
      id: 'ex_unit_7',
      title: 'More Vocabulary',
      subtitle: 'From Even_More_words.md',
      icon: Icons.auto_stories_rounded,
      color: Colors.blue.shade800,
      badge: 'Unit 7',
      onPressed: (offset) {
        pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 7: Even More Vocabulary',
            unitPath: 'assets/data/exercises/unit_7.json',
          ),
          offset,
        );
      },
    );

    final unit8MonVocab = HomeTileItem(
      id: 'ex_unit_8',
      title: 'Weekly Vocabulary',
      subtitle: 'New words & related phrases',
      icon: Icons.library_books_rounded,
      color: Colors.indigo.shade800,
      badge: 'Unit 8',
      onPressed: (offset) {
        pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 8: Monday Mar 9 Vocabulary',
            unitPath: 'assets/data/exercises/unit_8.json',
          ),
          offset,
        );
      },
    );

    final allExercisesCard = HomeTileItem(
      id: 'ex_all_list',
      title: 'All Units Directory',
      subtitle: 'Browse complete unit list',
      icon: Icons.view_list_rounded,
      color: Theme.of(context).colorScheme.secondary,
      badge: 'Directory',
      onPressed: (offset) {
        pushScreen(const ExerciseListScreen(), offset);
      },
    );

    // ── Canonical Topic Tiles derived from kQuizCategories ──
    final topicTilesMap = {
      for (final cat in kQuizCategories)
        cat.name: HomeTileItem(
          id: 'topic_${cat.id}',
          title: cat.name,
          subtitle: cat.subtitle,
          icon: cat.icon,
          color: cat.color,
          badge: 'Quiz',
          onPressed: isQuizDisabled
              ? null
              : (offset) {
                  pushScreen(QuizScreen(category: cat.name), offset);
                },
        ),
    };

    final topicGridPicker = HomeTileItem(
      id: 'topic_all_grid',
      title: 'All Topics Grid',
      subtitle: 'Browse all categories in a visual grid',
      icon: Icons.category_rounded,
      color: Theme.of(context).colorScheme.primary,
      badge: 'Grid',
      onPressed: isQuizDisabled
          ? null
          : (offset) {
              pushScreen(const CategorySelectionScreen(), offset);
            },
    );

    // ── Fast Practice ──
    final fastVocabQuiz = HomeTileItem(
      id: 'fast_vocab_quiz',
      title: 'Vocab Quiz',
      subtitle: 'Rapid-fire 10-Q challenge',
      icon: Icons.local_fire_department_rounded,
      color: Colors.amber.shade700,
      badge: 'Rapid',
      onPressed: isQuizDisabled
          ? null
          : (offset) {
              pushScreen(const QuizScreen(isVocabularyQuiz: true), offset);
            },
    );

    final fastListenRepeat = HomeTileItem(
      id: 'fast_listen_repeat',
      title: 'Listen & Repeat',
      subtitle: 'Hands-free ear training',
      icon: Icons.headset_rounded,
      color: Colors.indigo.shade600,
      badge: 'Audio',
      onPressed: (offset) {
        pushScreen(const ListenRepeatScreen(), offset);
      },
    );

    final fastLuckyQuiz = HomeTileItem(
      id: 'fast_lucky_quiz',
      title: 'Lucky Challenge',
      subtitle: 'Smart adaptive practice',
      icon: Icons.auto_awesome_rounded,
      color: Colors.purple.shade600,
      badge: 'Adaptive',
      onPressed: isQuizDisabled
          ? null
          : (offset) {
              pushScreen(const QuizScreen(isLuckyQuiz: true), offset);
            },
    );

    final fastVoiceTrainer = HomeTileItem(
      id: 'fast_voice_trainer',
      title: 'Voice Trainer',
      subtitle: 'Speech & pronunciation',
      icon: Icons.mic_rounded,
      color: Colors.deepOrange.shade600,
      badge: 'Speak',
      onPressed: (offset) {
        pushScreen(const VoiceTrainerScreen(), offset);
      },
    );

    // ── Core Skills ──
    final flashcardsTile = HomeTileItem(
      id: 'vocab_flashcards',
      title: 'Flashcards',
      subtitle: '865 cards with audio & 3D flip',
      icon: Icons.style_rounded,
      color: Colors.indigo.shade600,
      badge: '865 Cards',
      onPressed: (offset) {
        pushScreen(const FlashcardsScreen(), offset);
      },
    );

    final vocabList = HomeTileItem(
      id: 'vocab_list',
      title: 'Vocabulary',
      subtitle: 'Browse, search & word graph',
      icon: Icons.book_rounded,
      color: Colors.blue.shade600,
      badge: 'Search',
      onPressed: (offset) {
        pushScreen(const VocabularyListScreen(), offset);
      },
    );

    final vocabQuizCat = HomeTileItem(
      id: 'vocab_quiz_cat',
      title: 'Start Quiz',
      subtitle: 'Category multi-choice',
      icon: Icons.quiz_rounded,
      color: Theme.of(context).colorScheme.primary,
      badge: 'Topics',
      onPressed: isQuizDisabled
          ? null
          : (offset) {
              pushScreen(const CategorySelectionScreen(), offset);
            },
    );

    final vocabQuizQuick = HomeTileItem(
      id: 'vocab_quiz_quick',
      title: 'Vocab Quiz',
      subtitle: 'Rapid-fire challenge',
      icon: Icons.local_fire_department_rounded,
      color: Colors.amber.shade700,
      badge: 'Rapid',
      onPressed: isQuizDisabled
          ? null
          : (offset) {
              pushScreen(const QuizScreen(isVocabularyQuiz: true), offset);
            },
    );

    final vocab100Phrases = HomeTileItem(
      id: 'vocab_100_phrases',
      title: '100 Phrases',
      subtitle: 'Essential daily phrases',
      icon: Icons.style_rounded,
      color: Colors.teal.shade600,
      badge: 'Daily',
      onPressed: (offset) {
        pushScreen(const VerbPhraseTrainerScreen(), offset);
      },
    );

    final phraseTrainer = HomeTileItem(
      id: 'phrase_trainer',
      title: 'Phrase Trainer',
      subtitle: 'Everyday conversation',
      icon: Icons.translate_rounded,
      color: Colors.green.shade700,
      badge: 'Dialogues',
      onPressed: (offset) {
        pushScreen(const PhraseTrainerScreen(), offset);
      },
    );

    final verbTrainer = HomeTileItem(
      id: 'verb_trainer',
      title: 'Verb Trainer',
      subtitle: 'Conjugations & tenses',
      icon: Icons.school_rounded,
      color: Colors.purple.shade600,
      badge: 'Verbs',
      onPressed: (offset) {
        pushScreen(const VerbConjugationScreen(), offset);
      },
    );

    final interrogatives = HomeTileItem(
      id: 'interrogatives',
      title: 'Interrogatives',
      subtitle: 'Question words & usage',
      icon: Icons.contact_support_rounded,
      color: Colors.cyan.shade700,
      badge: 'Questions',
      onPressed: (offset) {
        pushScreen(const InterrogativeQuizScreen(), offset);
      },
    );

    final prepositions = HomeTileItem(
      id: 'prepositions',
      title: 'Prepositions',
      subtitle: 'Rules & connectors',
      icon: Icons.link_rounded,
      color: Colors.pink.shade700,
      badge: 'Rules',
      onPressed: (offset) {
        pushScreen(const PrepositionQuizScreen(), offset);
      },
    );

    final grammarRules = HomeTileItem(
      id: 'grammar_rules',
      title: 'Grammar Rules',
      subtitle: 'Essential syntax & tips',
      icon: Icons.menu_book_rounded,
      color: Colors.blue.shade700,
      badge: 'Syntax',
      onPressed: (offset) {
        pushScreen(const GrammarQuizScreen(), offset);
      },
    );

    final voiceTrainer = HomeTileItem(
      id: 'voice_trainer',
      title: 'Voice Trainer',
      subtitle: 'Speech & pronunciation',
      icon: Icons.mic_rounded,
      color: Colors.deepOrange.shade600,
      badge: 'Speak',
      onPressed: (offset) {
        pushScreen(const VoiceTrainerScreen(), offset);
      },
    );

    final speakingListenRepeat = HomeTileItem(
      id: 'speaking_listen_repeat',
      title: 'Listen & Repeat',
      subtitle: 'Hands-free audio trainer',
      icon: Icons.headset_rounded,
      color: Colors.indigo.shade600,
      badge: 'Audio',
      onPressed: (offset) {
        pushScreen(const ListenRepeatScreen(), offset);
      },
    );

    final exercisesSections = [
      HomeSectionData(
        id: 'ex_section_structure',
        title: 'Sentence & Structure (7 Units)',
        icon: Icons.reorder_rounded,
        accentColor: Colors.indigo.shade400,
        exercises: [
          sentenceBuilder,
          questionBuilder,
          prepositionalPronouns,
          indirectObjectPronouns,
          conjunctions,
          comparatives,
          sentenceTransformations,
        ],
      ),
      HomeSectionData(
        id: 'ex_section_verbs',
        title: 'Verb Mastery (5 Units)',
        icon: Icons.school_rounded,
        accentColor: Colors.purple.shade400,
        exercises: [
          verbConjugationQuiz,
          unit2IrregularVerbs,
          unit3Ser,
          unit4IrregularVerbs,
          unit5RegularVerbs,
        ],
      ),
      HomeSectionData(
        id: 'ex_section_thematic',
        title: 'Thematic Vocabulary Units (7 Units)',
        icon: Icons.home_work_rounded,
        accentColor: Colors.teal.shade400,
        exercises: [
          unit12Rooms,
          unit13HouseholdItems,
          unit14BodyHealth,
          unit15EverydayItems,
          unit6NewVocab,
          unit7MoreVocab,
          unit8MonVocab,
          allExercisesCard,
        ],
      ),
    ];

    final topicsSections = [
      HomeSectionData(
        id: 'topics_all',
        title: 'Explore by Topic (13 Topics)',
        icon: Icons.category_rounded,
        accentColor: Colors.orange.shade500,
        exercises: [
          ...kQuizCategories.map((c) => topicTilesMap[c.name]).whereType<HomeTileItem>(),
          topicGridPicker,
        ],
      ),
    ];

    final vocabSections = [
      HomeSectionData(
        id: 'vocab_all',
        title: 'Vocabulary & Flashcards',
        icon: Icons.menu_book_rounded,
        accentColor: Colors.blue.shade500,
        exercises: [
          flashcardsTile,
          vocabList,
          vocabQuizCat,
          vocabQuizQuick,
          vocab100Phrases,
          phraseTrainer,
        ],
      ),
    ];

    final grammarSections = [
      HomeSectionData(
        id: 'grammar_all',
        title: 'Grammar & Verbs',
        icon: Icons.school_rounded,
        accentColor: Colors.purple.shade400,
        exercises: [
          verbTrainer,
          verbConjugationQuiz,
          interrogatives,
          prepositions,
          grammarRules,
          sentenceBuilder,
        ],
      ),
    ];

    final speakingSections = [
      HomeSectionData(
        id: 'speaking_all',
        title: 'Speaking & Phrases',
        icon: Icons.mic_rounded,
        accentColor: Colors.deepOrange.shade400,
        exercises: [
          voiceTrainer,
          phraseTrainer,
          vocab100Phrases,
          speakingListenRepeat,
        ],
      ),
    ];

    final allSections = [
      HomeSectionData(
        id: 'fast_practice',
        title: 'Fast Practice',
        icon: Icons.bolt_rounded,
        accentColor: Colors.amber.shade600,
        exercises: [
          fastVocabQuiz,
          fastListenRepeat,
          fastLuckyQuiz,
          fastVoiceTrainer,
        ],
      ),
      HomeSectionData(
        id: 'exercises_featured',
        title: 'Practice & Exercises',
        icon: Icons.assignment_rounded,
        accentColor: Colors.teal.shade400,
        actionLabel: 'View All',
        onActionTap: () => selectCategory('exercises'),
        exercises: [
          sentenceBuilder,
          questionBuilder,
          verbConjugationQuiz,
          prepositionalPronouns,
        ],
      ),
      HomeSectionData(
        id: 'topics_featured',
        title: 'Explore Topics',
        icon: Icons.category_rounded,
        accentColor: Colors.orange.shade500,
        actionLabel: 'View All',
        onActionTap: () => selectCategory('topics'),
        exercises: [
          ...kQuizCategories.take(4).map((c) => topicTilesMap[c.name]).whereType<HomeTileItem>(),
        ],
      ),
      HomeSectionData(
        id: 'vocab_featured',
        title: 'Vocabulary & Phrases',
        icon: Icons.menu_book_rounded,
        accentColor: Colors.blue.shade500,
        actionLabel: 'View All',
        onActionTap: () => selectCategory('vocab'),
        exercises: [
          flashcardsTile,
          vocabList,
          vocab100Phrases,
        ],
      ),
      HomeSectionData(
        id: 'grammar_featured',
        title: 'Grammar & Verbs',
        icon: Icons.school_rounded,
        accentColor: Colors.purple.shade400,
        actionLabel: 'View All',
        onActionTap: () => selectCategory('grammar'),
        exercises: [
          verbTrainer,
          grammarRules,
          prepositions,
          interrogatives,
        ],
      ),
    ];

    return {
      'all': allSections,
      'exercises': exercisesSections,
      'topics': topicsSections,
      'vocab': vocabSections,
      'grammar': grammarSections,
      'speaking': speakingSections,
    };
  }
}
