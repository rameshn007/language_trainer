import re

with open('lib/ui/home_screen.dart', 'r') as f:
    content = f.read()

# 1. SizedBox.expand
content = content.replace('body: Stack(', 'body: SizedBox.expand(\n        child: Stack(')

# 2. CustomScrollView & Stats Card
# Find SafeArea
safe_area_start = content.find('SafeArea(\n            child: SingleChildScrollView(')

# Find GridView
grid_view_start = content.find('FadeInUp(\n                    delay: const Duration(milliseconds: 200),\n                    child: GridView.count(')

# Find end of build
build_end = content.find('  Widget _buildGridButton({')

new_build_content = """          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StatsCardDelegate(
                    progress: progress,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StatsScreen(),
                        ),
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 50,
                                  color: Colors.orange,
                                ),
                                const SizedBox(height: 10),
                                const Text('No vocabulary loaded.'),
                                TextButton(
                                  onPressed: _loadData,
                                  child: const Text('Tap here to load initial data'),
                                ),
                              ],
                            ),
                          ),
                        FadeInUp(
                          delay: const Duration(milliseconds: 200),
                          child: Column(
                            children: [
                              _buildSection(
                                title: 'Vocabulary & Flashcards',
                                icon: Icons.menu_book_rounded,
                                initiallyExpanded: true,
                                children: [
                                  _buildGridButton(
                                    context: context,
                                    label: 'Vocabulary',
                                    icon: Icons.book_rounded,
                                    bgColor: Colors.blue.shade600,
                                    fgColor: Colors.white,
                                    onPressed: (offset) {
                                      _pushScreen(
                                        const VocabularyListScreen(),
                                        offset,
                                      );
                                    },
                                  ),
                                  _buildGridButton(
                                    context: context,
                                    label: 'Start Quiz',
                                    icon: Icons.quiz_rounded,
                                    bgColor: Theme.of(context).colorScheme.primary,
                                    fgColor: Colors.white,
                                    onPressed: items.isEmpty || _isLoading
                                        ? null
                                        : (offset) {
                                            _pushScreen(
                                              const CategorySelectionScreen(),
                                              offset,
                                            ).then((_) => setState(() {}));
                                          },
                                  ),
                                  _buildGridButton(
                                    context: context,
                                    label: 'Vocab Quiz',
                                    icon: Icons.local_fire_department_rounded,
                                    bgColor: Colors.amber.shade700,
                                    fgColor: Colors.white,
                                    onPressed: items.isEmpty || _isLoading
                                        ? null
                                        : (offset) {
                                            _pushScreen(
                                              const QuizScreen(isVocabularyQuiz: true),
                                              offset,
                                            ).then((_) => setState(() {}));
                                          },
                                  ),
                                ],
                              ),
                              _buildSection(
                                title: 'Grammar & Verbs',
                                icon: Icons.school_rounded,
                                children: [
                                  _buildGridButton(
                                    context: context,
                                    label: 'Verb Trainer',
                                    icon: Icons.school_rounded,
                                    bgColor: Colors.purple,
                                    fgColor: Colors.white,
                                    onPressed: (offset) {
                                      _pushScreen(
                                        const VerbConjugationScreen(),
                                        offset,
                                      );
                                    },
                                  ),
                                  _buildGridButton(
                                    context: context,
                                    label: 'Interrogatives',
                                    icon: Icons.contact_support_rounded,
                                    bgColor: Colors.cyan.shade700,
                                    fgColor: Colors.white,
                                    onPressed: (offset) {
                                      _pushScreen(
                                        const InterrogativeQuizScreen(),
                                        offset,
                                      );
                                    },
                                  ),
                                  _buildGridButton(
                                    context: context,
                                    label: 'Prepositions',
                                    icon: Icons.link_rounded,
                                    bgColor: Colors.pink.shade700,
                                    fgColor: Colors.white,
                                    onPressed: (offset) {
                                      _pushScreen(
                                        const PrepositionQuizScreen(),
                                        offset,
                                      );
                                    },
                                  ),
                                ],
                              ),
                              _buildSection(
                                title: 'Practice & Exercises',
                                icon: Icons.assignment_rounded,
                                children: [
                                  _buildGridButton(
                                    context: context,
                                    label: 'Exercises',
                                    icon: Icons.assignment_rounded,
                                    bgColor: Theme.of(context).colorScheme.secondary,
                                    fgColor: Colors.white,
                                    onPressed: (offset) {
                                      _pushScreen(
                                        const ExerciseListScreen(),
                                        offset,
                                      );
                                    },
                                  ),
                                  _buildGridButton(
                                    context: context,
                                    label: 'Sentence Builder',
                                    icon: Icons.reorder_rounded,
                                    bgColor: Colors.indigo,
                                    fgColor: Colors.white,
                                    onPressed: (offset) {
                                      _pushScreen(
                                        const ExerciseScreen(
                                          unitName: 'Unit 10: Word Order & Pronouns',
                                          unitPath: 'assets/data/exercises/unit_10.json',
                                        ),
                                        offset,
                                      );
                                    },
                                  ),
                                  _buildGridButton(
                                    context: context,
                                    label: 'Question Builder',
                                    icon: Icons.chat_rounded,
                                    bgColor: Colors.lightBlue.shade600,
                                    fgColor: Colors.white,
                                    onPressed: (offset) {
                                      _pushScreen(
                                        const ExerciseScreen(
                                          unitName: 'Question Builder: Make the Question',
                                          unitPath: 'assets/data/exercises/question_builder.json',
                                        ),
                                        offset,
                                      );
                                    },
                                  ),
                                ],
                              ),
                              _buildSection(
                                title: 'Speaking & Phrases',
                                icon: Icons.mic_rounded,
                                children: [
                                  _buildGridButton(
                                    context: context,
                                    label: 'Voice Trainer',
                                    icon: Icons.mic_rounded,
                                    bgColor: Colors.deepOrange,
                                    fgColor: Colors.white,
                                    onPressed: (offset) {
                                      _pushScreen(
                                        const VoiceTrainerScreen(),
                                        offset,
                                      );
                                    },
                                  ),
                                  _buildGridButton(
                                    context: context,
                                    label: 'Phrase Trainer',
                                    icon: Icons.translate_rounded,
                                    bgColor: Colors.green,
                                    fgColor: Colors.white,
                                    onPressed: (offset) {
                                      _pushScreen(
                                        const PhraseTrainerScreen(),
                                        offset,
                                      );
                                    },
                                  ),
                                  _buildGridButton(
                                    context: context,
                                    label: '100 Phrases',
                                    icon: Icons.style_rounded,
                                    bgColor: Colors.teal,
                                    fgColor: Colors.white,
                                    onPressed: (offset) {
                                      _pushScreen(
                                        const VerbPhraseTrainerScreen(),
                                        offset,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          iconColor: Colors.white,
          collapsedIconColor: Colors.white70,
          leading: Icon(icon, color: Colors.white),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridButton({"""

end_of_build_block = content.find('        ],\n      ),\n    );\n  }\n\n  Widget _buildGridButton({')

if end_of_build_block == -1:
    # try another format
    end_of_build_block = content.find('  Widget _buildGridButton({')
    # need to find the `    );\n  }\n\n` before this
    idx = content.rfind('    );\n  }\n', 0, end_of_build_block)
    
# Replace everything from SafeArea to _buildGridButton
content = content[:safe_area_start] + new_build_content + content[end_of_build_block+len('  Widget _buildGridButton({'):]

# Add _StatsCardDelegate at the end of the file, before CircularRevealClipper if possible, 
# or just after _buildGridButton class closes.
clipper_start = content.find('class CircularRevealClipper extends CustomClipper<Path> {')

stats_card_delegate = """
class _StatsCardDelegate extends SliverPersistentHeaderDelegate {
  final ProgressData progress;
  final VoidCallback onTap;

  _StatsCardDelegate({required this.progress, required this.onTap});

  @override
  double get maxExtent => 180.0;

  @override
  double get minExtent => 85.0;

  @override
  bool shouldRebuild(covariant _StatsCardDelegate oldDelegate) {
    return progress != oldDelegate.progress;
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final shrinkPercentage = shrinkOffset / (maxExtent - minExtent);
    final clampedShrink = shrinkPercentage.clamp(0.0, 1.0);

    final expandedOpacity = (1.0 - clampedShrink * 2).clamp(0.0, 1.0);
    final collapsedOpacity = ((clampedShrink - 0.5) * 2).clamp(0.0, 1.0);

    return FadeInDown(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.fromLTRB(20, 20 * (1 - clampedShrink), 20, 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepPurple.shade400.withValues(alpha: 0.9 + 0.1 * clampedShrink),
                Colors.deepPurple.shade700.withValues(alpha: 0.9 + 0.1 * clampedShrink),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15 + 0.2 * clampedShrink),
                blurRadius: 15 - 5 * clampedShrink,
                offset: Offset(0, 8 - 4 * clampedShrink),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (expandedOpacity > 0.0)
                Opacity(
                  opacity: expandedOpacity,
                  child: OverflowBox(
                    maxHeight: maxExtent,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.local_fire_department,
                                  color: progress.currentStreak > 0
                                      ? Colors.deepOrange.shade300
                                      : Colors.white38,
                                  size: 22,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${progress.currentStreak}-day streak',
                                  style: TextStyle(
                                    color: progress.currentStreak > 0
                                        ? Colors.white
                                        : Colors.white54,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${progress.todayXP}/${progress.dailyGoal} XP',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: progress.dailyGoalProgress,
                            minHeight: 8,
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress.dailyGoalMet
                                  ? Colors.greenAccent.shade400
                                  : Colors.amber.shade300,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(5, (tier) {
                            final count = progress.masteryDistribution[tier] ?? 0;
                            final tierColors = [
                              Colors.white38,
                              Colors.blue.shade200,
                              Colors.cyan.shade200,
                              Colors.orange.shade200,
                              Colors.greenAccent.shade200,
                            ];
                            return Column(
                              children: [
                                Text(
                                  '$count',
                                  style: TextStyle(
                                    color: tierColors[tier],
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  WordProgress.tierName(tier),
                                  style: TextStyle(
                                    color: tierColors[tier].withValues(alpha: 0.7),
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total XP: ${progress.totalXP}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Sessions today: ${progress.todaySessions}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white38,
                                  size: 16,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (collapsedOpacity > 0.0)
                Opacity(
                  opacity: collapsedOpacity,
                  child: Align(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              color: progress.currentStreak > 0
                                  ? Colors.deepOrange.shade300
                                  : Colors.white38,
                              size: 22,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${progress.currentStreak}',
                              style: TextStyle(
                                color: progress.currentStreak > 0
                                    ? Colors.white
                                    : Colors.white54,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${progress.todayXP}/${progress.dailyGoal} XP',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: LinearProgressIndicator(
                                    value: progress.dailyGoalProgress,
                                    minHeight: 6,
                                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      progress.dailyGoalMet
                                          ? Colors.greenAccent.shade400
                                          : Colors.amber.shade300,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          '${progress.totalXP} Total',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
"""

content = content[:clipper_start] + stats_card_delegate + "\n" + content[clipper_start:]

with open('lib/ui/home_screen.dart', 'w') as f:
    f.write(content)

print("Done")
