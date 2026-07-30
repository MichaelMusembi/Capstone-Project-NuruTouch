import 'dart:math';
import 'package:flutter/material.dart';
import '../../../data/local/database_helper.dart';
import '../../../theme/colors.dart';
import '../../../theme/text_styles.dart';
import '../../../core/adaptive_learning/models/dashboard_data.dart';
import '../../../core/adaptive_learning/curriculum_database.dart';
import '../../../core/adaptive_learning/models/lesson.dart';
import '../../../core/adaptive_learning/adaptive_learning_engine.dart';
import 'widgets/dot_cell.dart';

class StudentProgressScreen extends StatefulWidget {
  final int studentId;
  final String studentName;

  const StudentProgressScreen({super.key, required this.studentId, required this.studentName});

  @override
  State<StudentProgressScreen> createState() => _StudentProgressScreenState();
}

class _StudentProgressScreenState extends State<StudentProgressScreen> {
  List<Map<String, dynamic>> _allProgress = [];
  List<Map<String, dynamic>> _allAttempts = [];
  bool _isLoading = true;
  String _filter = 'All';

  // Curriculum Stats
  int _passedLetters = 0;
  int _totalLetters = 0;
  int _passedWords = 0;
  int _totalWords = 0;
  int _passedSentences = 0;
  int _totalSentences = 0;
  bool _wordsUnlocked = false;
  bool _sentencesUnlocked = false;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _mapCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchProgress();
  }

  Future<void> _fetchProgress() async {
    final data = await DatabaseHelper.instance.getStudentProgress(widget.studentId);
    final attemptsData = await DatabaseHelper.instance.getStudentAttempts(widget.studentId);
    if (mounted) {
      setState(() {
        _allProgress = data;
        _allAttempts = attemptsData;
        _isLoading = false;
      });
      _updateStatsForFilter();
    }
  }

  Future<void> _updateStatsForFilter() async {
    final langCode = _filter == 'Swahili' ? 'sw' : 'en';
    final wordsUnlocked = await AdaptiveLearningEngine.instance.isTypeUnlocked(widget.studentId, langCode, LessonType.word);
    final sentencesUnlocked = await AdaptiveLearningEngine.instance.isTypeUnlocked(widget.studentId, langCode, LessonType.sentence);

    final curriculum = CurriculumDatabase.instance;
    final List<Lesson> targetLessons = [];
    if (_filter == 'English') {
      targetLessons.addAll(curriculum.englishLessons);
    } else if (_filter == 'Swahili') {
      targetLessons.addAll(curriculum.swahiliLessons);
    } else {
      targetLessons.addAll(curriculum.englishLessons);
      targetLessons.addAll(curriculum.swahiliLessons);
    }

    int tL = 0, pL = 0;
    int tW = 0, pW = 0;
    int tS = 0, pS = 0;

    final filteredProgress = _getFilteredProgress();
    final passedIds = filteredProgress.where((p) => p['passed'] == 1).map((p) => p['lesson_id'] as String).toSet();

    for (var l in targetLessons) {
      bool passed = passedIds.contains(l.id);
      if (l.type == LessonType.letter) {
        tL++;
        if (passed) pL++;
      } else if (l.type == LessonType.word) {
        tW++;
        if (passed) pW++;
      } else if (l.type == LessonType.sentence) {
        tS++;
        if (passed) pS++;
      }
    }

    if (mounted) {
      setState(() {
        _wordsUnlocked = wordsUnlocked;
        _sentencesUnlocked = sentencesUnlocked;
        _totalLetters = tL;
        _passedLetters = pL;
        _totalWords = tW;
        _passedWords = pW;
        _totalSentences = tS;
        _passedSentences = pS;
      });
    }
  }

  int _getTotalCurriculumLessons() {
    if (_filter == 'English') {
      return CurriculumDatabase.instance.englishLessons.length;
    } else if (_filter == 'Swahili') {
      return CurriculumDatabase.instance.swahiliLessons.length;
    }
    return CurriculumDatabase.instance.englishLessons.length + CurriculumDatabase.instance.swahiliLessons.length;
  }

  List<Map<String, dynamic>> _getFilteredProgress() {
    if (_filter == 'All') return _allProgress;
    return _allProgress.where((p) {
      String id = p['lesson_id'] as String;
      return _filter == 'English' ? id.startsWith('en_') : id.startsWith('sw_');
    }).toList();
  }
  
  List<Map<String, dynamic>> _getFilteredAttempts() {
    if (_filter == 'All') return _allAttempts;
    return _allAttempts.where((a) {
      String id = a['lesson_id'] as String;
      return _filter == 'English' ? id.startsWith('en_') : id.startsWith('sw_');
    }).toList();
  }

  void _scrollToMap() {
    if (_mapCardKey.currentContext != null) {
      Scrollable.ensureVisible(
        _mapCardKey.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: NuruColors.background, body: Center(child: CircularProgressIndicator()));
    }

    if (_allProgress.isEmpty) {
      return Scaffold(
        backgroundColor: NuruColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white, 
          elevation: 0, 
          foregroundColor: NuruColors.ink,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(color: NuruColors.slate.withOpacity(0.5), height: 1.0),
          ),
          title: Text(widget.studentName, style: NuruTextStyles.body(weight: FontWeight.w500)),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OverallProgressRing(percentage: 0),
              const SizedBox(height: 24),
              Text("No attempts yet.", style: NuruTextStyles.body(color: NuruColors.inkMuted)),
            ],
          ),
        ),
      );
    }

    final filteredProgress = _getFilteredProgress();
    final data = DashboardData.fromProgress(filteredProgress, _getTotalCurriculumLessons());

    return Scaffold(
      backgroundColor: NuruColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white, 
        elevation: 0, 
        foregroundColor: NuruColors.ink,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: NuruColors.slate.withOpacity(0.5), height: 1.0),
        ),
        title: Text(widget.studentName, style: NuruTextStyles.body(weight: FontWeight.w500)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 4. Filter Bar
              _buildFilterBar(),
              const SizedBox(height: 24),

              // 5. Overall Progress
              _buildCard(
                child: Row(
                  children: [
                    OverallProgressRing(
                      percentage: data.completionPercentage / 100,
                      total: data.totalLessons,
                      passed: data.completedLessons,
                    ),
                    const SizedBox(width: 32),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Avg Mastery", style: NuruTextStyles.body(color: NuruColors.inkMuted, fontSize: 14)),
                        const SizedBox(height: 4),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: data.masteryAverage),
                          duration: const Duration(milliseconds: 300),
                          builder: (context, value, child) {
                            return Text("${value.toStringAsFixed(1)}%", style: NuruTextStyles.display(fontSize: 32));
                          }
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 6. Curriculum Stage Card
              _buildCard(
                child: Column(
                  children: [
                    _buildStageBar("Letters", _passedLetters, _totalLetters, true),
                    const SizedBox(height: 16),
                    _buildStageBar("Words", _passedWords, _totalWords, _wordsUnlocked),
                    const SizedBox(height: 16),
                    _buildStageBar("Sentences", _passedSentences, _totalSentences, _sentencesUnlocked),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 7. Curriculum Map (Lesson Matrix)
              Container(key: _mapCardKey, child: _buildCard(child: CurriculumMap(progress: filteredProgress))),
              const SizedBox(height: 12),

              // 8. Attempt Distribution
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Attempt Distribution", style: NuruTextStyles.body(weight: FontWeight.w500)),
                    const SizedBox(height: 16),
                    AttemptDistributionBar(
                      passedFirstAttempt: data.passedFirstAttempt,
                      passedMultipleAttempts: data.passedMultipleAttempts,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 9. Granular Breakdown
              _buildCard(child: GranularBreakdown(progress: filteredProgress, filter: _filter)),
              const SizedBox(height: 12),

              // 10. Activity Feed
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Recent Activity", style: NuruTextStyles.body(weight: FontWeight.w500)),
                    const SizedBox(height: 16),
                    ActivityFeed(attempts: _getFilteredAttempts()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _buildFilterBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NuruColors.slate),
      ),
      child: Row(
        children: ['All', 'English', 'Swahili'].map((title) {
          bool isActive = _filter == title;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _filter = title);
                _updateStatsForFilter();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isActive ? NuruColors.indigo : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  title,
                  style: NuruTextStyles.body(
                    color: isActive ? Colors.white : NuruColors.inkMuted,
                    weight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStageBar(String title, int passed, int total, bool isUnlocked) {
    double progress = total == 0 ? 0 : passed / total;
    return GestureDetector(
      onTap: () {
        if (isUnlocked) {
          _scrollToMap();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Unlocks after previous stage is passed", style: NuruTextStyles.body(color: Colors.white)),
              backgroundColor: NuruColors.ink,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: isUnlocked 
                ? null 
                : const Icon(Icons.lock, color: NuruColors.slate, size: 16),
          ),
          SizedBox(
            width: 80,
            child: Text(title, style: NuruTextStyles.body(
              color: isUnlocked ? NuruColors.ink : NuruColors.slate,
              weight: FontWeight.w500,
            )),
          ),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: isUnlocked ? progress : 0),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  backgroundColor: NuruColors.background,
                  valueColor: AlwaysStoppedAnimation(
                    progress >= 1.0 ? NuruColors.sage : NuruColors.indigo
                  ),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                );
              }
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "$passed/$total",
            style: NuruTextStyles.mono(color: isUnlocked ? NuruColors.inkMuted : NuruColors.slate),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// 5. Overall Progress Ring
// ---------------------------------------------------------
class OverallProgressRing extends StatefulWidget {
  final double percentage;
  final int total;
  final int passed;

  const OverallProgressRing({super.key, required this.percentage, this.total = 0, this.passed = 0});

  @override
  State<OverallProgressRing> createState() => _OverallProgressRingState();
}

class _OverallProgressRingState extends State<OverallProgressRing> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _anim;
  
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0, end: widget.percentage).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant OverallProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percentage != widget.percentage) {
      _anim = Tween<double>(begin: oldWidget.percentage, end: widget.percentage).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
      _animController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(140, 140),
                painter: DotRingPainter(fillPercentage: _anim.value),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("${(_anim.value * 100).toInt()}%", style: NuruTextStyles.display(fontSize: 36)),
                  Text("Passed ${widget.passed}/${widget.total}", style: NuruTextStyles.body(fontSize: 12, color: NuruColors.inkMuted)),
                ],
              ),
            ],
          ),
        );
      }
    );
  }
}

class DotRingPainter extends CustomPainter {
  final double fillPercentage;
  DotRingPainter({required this.fillPercentage});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4; // padding
    final int totalDots = 24;
    final int filledDots = (fillPercentage * totalDots).round();

    for (int i = 0; i < totalDots; i++) {
      final angle = (i / totalDots) * 2 * pi - pi / 2;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      
      final paint = Paint()
        ..color = i < filledDots ? NuruColors.indigo : NuruColors.slate
        ..style = PaintingStyle.fill;
        
      canvas.drawCircle(Offset(x, y), 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DotRingPainter oldDelegate) {
    return oldDelegate.fillPercentage != fillPercentage;
  }
}

// ---------------------------------------------------------
// 7. Curriculum Map
// ---------------------------------------------------------
class CurriculumMap extends StatefulWidget {
  final List<Map<String, dynamic>> progress;

  const CurriculumMap({super.key, required this.progress});

  @override
  State<CurriculumMap> createState() => _CurriculumMapState();
}

class _CurriculumMapState extends State<CurriculumMap> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStatusColor(int passed, double ef) {
    if (passed == 1) return NuruColors.sage;
    if (passed == 0 && ef > 0) return NuruColors.amber;
    return NuruColors.slate;
  }

  @override
  Widget build(BuildContext context) {
    // Generate nodes
    List<Widget> nodes = [];
    final curriculum = CurriculumDatabase.instance;
    final allLessons = [...curriculum.englishLessons, ...curriculum.swahiliLessons];
    
    // De-dupe based on ID just in case
    final Map<String, Lesson> uniqueLessons = {};
    for (var l in allLessons) {
      if (l.type != LessonType.instruction) uniqueLessons[l.id] = l;
    }

    for (var p in widget.progress) {
      final id = p['lesson_id'] as String;
      final lesson = uniqueLessons[id];
      if (lesson == null) continue;

      final passed = p['passed'] ?? 0;
      final ef = (p['easiness_factor'] ?? 0.0).toDouble();
      final color = _getStatusColor(passed, ef);

      List<int> targetDots = [];
      if (lesson.type == LessonType.letter && lesson.sequence.isNotEmpty) {
        targetDots = lesson.sequence.first.targetDots;
      } else {
        // Words/Sentences get 2-dot glyph
        targetDots = [2, 5];
      }

      nodes.add(
        GestureDetector(
          onTap: () {
            _showLessonDetails(context, lesson, p);
          },
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              bool isStruggling = color == NuruColors.amber;
              return Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: isStruggling 
                    ? Border.all(color: NuruColors.amber.withOpacity(0.5 + 0.5 * _pulseController.value), width: 2)
                    : Border.all(color: Colors.transparent, width: 2),
                ),
                child: DotCell(
                  targetDots: targetDots,
                  baseColor: color,
                  dotSize: 5.0,
                  spacing: 2.0,
                ),
              );
            }
          ),
        )
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Curriculum Map", style: NuruTextStyles.body(weight: FontWeight.w500)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: nodes,
        ),
      ],
    );
  }

  void _showLessonDetails(BuildContext context, Lesson lesson, Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Lesson: ${lesson.target ?? lesson.id}", style: NuruTextStyles.display(fontSize: 24)),
                const SizedBox(height: 16),
                Text("Easiness Factor: ${p['easiness_factor']?.toStringAsFixed(1) ?? '0.0'}", style: NuruTextStyles.body()),
                Text("Total Attempts: ${p['repetitions'] ?? 0}", style: NuruTextStyles.body()),
                const SizedBox(height: 24),
                // "View in Activity Feed" link
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    // In a real implementation this would set a filter on the feed and scroll down.
                  },
                  child: Text("View in Activity Feed", style: NuruTextStyles.body(color: NuruColors.indigo, weight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}

// ---------------------------------------------------------
// 8. Attempt Distribution Bar
// ---------------------------------------------------------
class AttemptDistributionBar extends StatelessWidget {
  final int passedFirstAttempt;
  final int passedMultipleAttempts;

  const AttemptDistributionBar({
    super.key,
    required this.passedFirstAttempt,
    required this.passedMultipleAttempts,
  });

  @override
  Widget build(BuildContext context) {
    final int maxVal = max(passedFirstAttempt, passedMultipleAttempts);
    if (maxVal == 0) {
      return Text("No data yet.", style: NuruTextStyles.body(color: NuruColors.inkMuted));
    }

    return Column(
      children: [
        _buildBar("Passed on 1st attempt", passedFirstAttempt, maxVal, NuruColors.sage),
        const SizedBox(height: 12),
        _buildBar("Passed after retries", passedMultipleAttempts, maxVal, NuruColors.amber),
      ],
    );
  }

  Widget _buildBar(String label, int value, int maxVal, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth - 40; // reserve space for text
        final double width = maxVal == 0 ? 0 : (value / maxVal) * maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: NuruTextStyles.body(fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: width),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  builder: (context, val, child) {
                    return Container(
                      width: val,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    );
                  }
                ),
                const SizedBox(width: 8),
                Text("$value", style: NuruTextStyles.mono(color: NuruColors.ink)),
              ],
            ),
          ],
        );
      }
    );
  }
}

// ---------------------------------------------------------
// 9. Granular Breakdown
// ---------------------------------------------------------
class GranularBreakdown extends StatefulWidget {
  final List<Map<String, dynamic>> progress;
  final String filter;

  const GranularBreakdown({super.key, required this.progress, required this.filter});

  @override
  State<GranularBreakdown> createState() => _GranularBreakdownState();
}

class _GranularBreakdownState extends State<GranularBreakdown> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    List<String> mastered = [];
    List<String> struggling = [];
    
    for (var p in widget.progress) {
      String id = p['lesson_id'] as String;
      var lesson = CurriculumDatabase.instance.getLessonById(id, id.startsWith('sw') ? 'sw' : 'en');
      if (lesson == null || lesson.type == LessonType.instruction) continue;

      double ef = (p['easiness_factor'] ?? 0.0).toDouble();
      int passed = p['passed'] ?? 0;
      int repetitions = p['repetitions'] ?? 0;
      
      if (passed == 1 && ef >= 80.0 && repetitions <= 1) {
        mastered.add(lesson.narration?.character ?? lesson.narration?.spokenForm ?? "Unknown");
      } else if (passed == 1 || repetitions > 0) {
        struggling.add(lesson.narration?.character ?? lesson.narration?.spokenForm ?? "Unknown");
      }
    }

    List<String> remaining = [];
    List<Lesson> activeCurriculum = [];
    if (widget.filter == 'English') {
      activeCurriculum = CurriculumDatabase.instance.englishLessons;
    } else if (widget.filter == 'Swahili') {
      activeCurriculum = CurriculumDatabase.instance.swahiliLessons;
    } else {
      activeCurriculum = [...CurriculumDatabase.instance.englishLessons, ...CurriculumDatabase.instance.swahiliLessons];
    }

    for (var lesson in activeCurriculum) {
      if (lesson.type == LessonType.instruction) continue;
      String displayTarget = lesson.target ?? lesson.narration?.character ?? lesson.narration?.spokenForm ?? "Unknown";
      if (!mastered.contains(displayTarget) && !struggling.contains(displayTarget)) {
        remaining.add(displayTarget);
      }
    }

    List<List<String>> buckets = [mastered, struggling, remaining];
    List<Color> bucketColors = [NuruColors.sage, NuruColors.amber, NuruColors.slate];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tabs
        Row(
          children: [
            _buildTab("Mastered", 0),
            _buildTab("Struggling", 1),
            _buildTab("Remaining", 2),
          ],
        ),
        const SizedBox(height: 16),
        // Content
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Wrap(
            key: ValueKey<int>(_selectedIndex),
            spacing: 8,
            runSpacing: 8,
            children: buckets[_selectedIndex].map((label) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: bucketColors[_selectedIndex].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: bucketColors[_selectedIndex]),
                ),
                child: Text(label, style: NuruTextStyles.body(color: NuruColors.ink)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String title, int index) {
    bool isActive = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? NuruColors.indigo : Colors.transparent,
                width: 2,
              )
            )
          ),
          alignment: Alignment.center,
          child: Text(title, style: NuruTextStyles.body(
            color: isActive ? NuruColors.indigo : NuruColors.inkMuted,
            weight: isActive ? FontWeight.bold : FontWeight.normal,
          )),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// 10. Activity Feed
// ---------------------------------------------------------
class ActivityFeed extends StatefulWidget {
  final List<Map<String, dynamic>> attempts;
  const ActivityFeed({super.key, required this.attempts});

  @override
  State<ActivityFeed> createState() => _ActivityFeedState();
}

class _ActivityFeedState extends State<ActivityFeed> {
  int _limit = 20;
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    if (widget.attempts.isEmpty) return const SizedBox.shrink();

    // Sort reverse chronological
    final sortedAttempts = List<Map<String, dynamic>>.from(widget.attempts)
      ..sort((a, b) => b['attempt_timestamp'].compareTo(a['attempt_timestamp']));
    
    // Allow internal scrolling for the feed
    return SizedBox(
      height: 350,
      child: ListView.builder(
        itemCount: sortedAttempts.length,
        itemBuilder: (context, index) {
          final attempt = sortedAttempts[index];
          final time = DateTime.fromMillisecondsSinceEpoch(attempt['attempt_timestamp']);
          final errorType = attempt['error_type'];
          final isSuccess = errorType == 'none' || errorType == '';
          final id = "${attempt['student_id']}_${attempt['lesson_id']}_${attempt['attempt_timestamp']}";
          final isExpanded = _expandedId == id;
          final lessonId = attempt['lesson_id'];

          return InkWell(
            onTap: isSuccess ? null : () {
              setState(() {
                _expandedId = isExpanded ? null : id;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(isSuccess ? Icons.check_circle : Icons.warning_rounded, 
                           color: isSuccess ? NuruColors.sage : NuruColors.amber, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isSuccess 
                            ? "$lessonId · Passed on attempt ${attempt['hint_level_reached'] + 1}"
                            : "$lessonId · Mistake: $errorType", 
                          style: NuruTextStyles.body(fontSize: 14),
                        ),
                      ),
                      Text("${time.hour}:${time.minute.toString().padLeft(2, '0')}", style: NuruTextStyles.mono(color: NuruColors.inkMuted)),
                    ],
                  ),
                  if (isExpanded && !isSuccess) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(width: 32),
                        DotCell(
                          targetDots: const [1,2,3],
                          inputDots: _parsePattern(attempt['input_pattern']),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 32.0),
                      child: Text("Raw input: ${attempt['input_pattern']}\nHint level: ${attempt['hint_level_reached']}", style: NuruTextStyles.mono()),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<int> _parsePattern(String patternStr) {
    if (patternStr.isEmpty || patternStr == '[]') return [];
    try {
      final clean = patternStr.replaceAll('[', '').replaceAll(']', '').replaceAll(' ', '');
      if (clean.isEmpty) return [];
      return clean.split(',').map((e) => int.parse(e)).toList();
    } catch (e) {
      return [];
    }
  }
}
