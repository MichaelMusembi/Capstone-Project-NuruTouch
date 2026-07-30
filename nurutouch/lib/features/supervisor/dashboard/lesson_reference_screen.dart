import 'package:flutter/material.dart';
import '../../../theme/colors.dart';
import '../../../core/adaptive_learning/curriculum_database.dart';
import '../../../core/adaptive_learning/models/lesson.dart';
import '../../../data/local/app_state.dart';

class LessonReferenceScreen extends StatefulWidget {
  const LessonReferenceScreen({super.key});

  @override
  State<LessonReferenceScreen> createState() => _LessonReferenceScreenState();
}

class _LessonReferenceScreenState extends State<LessonReferenceScreen> {
  List<Lesson> _lessons = [];

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    final lang = AppState().languageNotifier.value;
    setState(() {
      _lessons = lang.startsWith('sw') 
          ? CurriculumDatabase.instance.swahiliLessons 
          : CurriculumDatabase.instance.englishLessons;
    });
  }

  Widget _buildBraillePattern(Lesson lesson) {
    List<int> dots = lesson.dots ?? [];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          children: [
            _dot(dots.contains(1)),
            _dot(dots.contains(2)),
            _dot(dots.contains(3)),
          ],
        ),
        Column(
          children: [
            _dot(dots.contains(4)),
            _dot(dots.contains(5)),
            _dot(dots.contains(6)),
          ],
        ),
      ],
    );
  }

  Widget _dot(bool isActive) {
    return Container(
      margin: const EdgeInsets.all(2),
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? NuruColors.indigo : Colors.grey[300],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lesson Reference")),
      body: _lessons.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _lessons.length,
              itemBuilder: (context, index) {
                final lesson = _lessons[index];
                if (lesson.type == LessonType.instruction) {
                  return const SizedBox.shrink(); // Skip intro items
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: _buildBraillePattern(lesson),
                    title: Text(
                      lesson.type == LessonType.word ? 'Word: ${lesson.target}' : 'Letter: ${lesson.target}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (lesson.dots != null && lesson.dots!.isNotEmpty)
                          Text("Dots: ${lesson.dots!.join(', ')}", style: const TextStyle(color: NuruColors.indigo, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(lesson.intro ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    isThreeLine: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LessonDetailScreen(lesson: lesson),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class LessonDetailScreen extends StatelessWidget {
  final Lesson lesson;
  const LessonDetailScreen({super.key, required this.lesson});

  Widget _dot(bool isActive) {
    return Container(
      margin: const EdgeInsets.all(8),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? NuruColors.indigo : Colors.grey[300],
        boxShadow: isActive ? [
          BoxShadow(
            color: NuruColors.indigo.withOpacity(0.4),
            blurRadius: 8,
            spreadRadius: 2,
          )
        ] : null,
      ),
    );
  }

  Widget _buildGiantBraillePattern(List<int> dots) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          children: [
            _dot(dots.contains(1)),
            _dot(dots.contains(2)),
            _dot(dots.contains(3)),
          ],
        ),
        const SizedBox(width: 20),
        Column(
          children: [
            _dot(dots.contains(4)),
            _dot(dots.contains(5)),
            _dot(dots.contains(6)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = lesson.type == LessonType.word ? 'Word: ${lesson.target}' : 'Letter: ${lesson.target}';
    final isWordOrSentence = lesson.type == LessonType.word || lesson.type == LessonType.sentence;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: NuruColors.bone,
      ),
      backgroundColor: NuruColors.bone,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Text(
              "Braille Pattern Reference",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: NuruColors.indigo),
            ),
            const SizedBox(height: 40),
            if (!isWordOrSentence && lesson.dots != null)
              _buildGiantBraillePattern(lesson.dots!)
            else if (isWordOrSentence && lesson.sequence != null)
              Wrap(
                spacing: 40,
                runSpacing: 40,
                alignment: WrapAlignment.center,
                children: lesson.sequence!.map((seq) {
                  if (seq.expectedAction == ExpectedAction.swipeRight || seq.character == 'SPACE') {
                    return Container(width: 50, height: 50, child: const Center(child: Text("SPACE", style: TextStyle(fontWeight: FontWeight.bold))));
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(seq.character ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      _buildGiantBraillePattern(seq.targetDots),
                    ],
                  );
                }).toList(),
              ),
            const SizedBox(height: 60),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Spoken Introduction", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: NuruColors.green)),
                  const SizedBox(height: 8),
                  Text(lesson.intro ?? "None", style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 20),
                  const Text("Hint Text", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: NuruColors.clay)),
                  const SizedBox(height: 8),
                  Text(lesson.hint ?? "None", style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 20),
                  const Text("Success Text", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: NuruColors.indigo)),
                  const SizedBox(height: 8),
                  Text(lesson.success ?? "None", style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
