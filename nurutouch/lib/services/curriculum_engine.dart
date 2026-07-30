import '../models/braille_record.dart';
import '../data/local/database_helper.dart';
import '../data/local/app_state.dart';

class CurriculumEngine {
  List<BrailleRecord> _studentProgress = [];
  final List<String> _instructionIds = [];
  final List<String> _practiceIds = [];
  int? _currentStudentId;

  Future<void> init(List<dynamic> lessonsJson, int studentId) async {
    _currentStudentId = studentId;
    final progressMaps = await DatabaseHelper.instance.getStudentProgress(studentId);
    _studentProgress = progressMaps.map((m) => BrailleRecord.fromMap(m)).toList();
    
    _instructionIds.clear();
    _practiceIds.clear();
    
    for (var lesson in lessonsJson) {
      if (lesson['type'] == 'instruction') {
        _instructionIds.add(lesson['id']);
      } else {
        _practiceIds.add(lesson['id']);
      }
    }
  }

  String getNextOptimalLesson() {
    // 1. Force uncompleted instructions first
    for (String id in _instructionIds) {
      bool completed = _studentProgress.any((record) => record.lessonId == id);
      if (!completed) {
        return id;
      }
    }

    // 2. SRS Math for practice lessons
    final now = DateTime.now();
    List<BrailleRecord> dueRecords = _studentProgress
        .where((record) => _practiceIds.contains(record.lessonId) && record.nextReviewDate.isBefore(now))
        .toList();

    if (dueRecords.isNotEmpty) {
      dueRecords.sort((a, b) => a.easinessFactor.compareTo(b.easinessFactor));
      return dueRecords.first.lessonId;
    }

    // 3. Introduce next un-started practice
    for (String id in _practiceIds) {
      bool hasStarted = _studentProgress.any((record) => record.lessonId == id);
      if (!hasStarted) {
        return id;
      }
    }

    // 4. Everything completed & not due -> practice weakest
    var practiceProgress = _studentProgress.where((r) => _practiceIds.contains(r.lessonId)).toList();
    if (practiceProgress.isNotEmpty) {
      practiceProgress.sort((a, b) => a.easinessFactor.compareTo(b.easinessFactor));
      return practiceProgress.first.lessonId;
    }
    
    // Fallback if empty
    return _instructionIds.isNotEmpty ? _instructionIds.first : "";
  }

  Future<void> updateProgress(String lessonId, int mistakeCount, int timeToAnswerMs) async {
    if (_currentStudentId == null) return;

    // If it's an instruction, just mark it complete with an infinite interval so it never shows up again.
    if (_instructionIds.contains(lessonId)) {
      BrailleRecord record = BrailleRecord(
        studentId: _currentStudentId!,
        language: AppState().languageNotifier.value,
        lessonId: lessonId,
        nextReviewDate: DateTime.now().add(const Duration(days: 3650)), // 10 years
      );
      _studentProgress.add(record);
      await DatabaseHelper.instance.upsertLessonProgress(record);
      return;
    }

    BrailleRecord record = _studentProgress.firstWhere(
      (r) => r.lessonId == lessonId,
      orElse: () {
        final newRecord = BrailleRecord(
          studentId: _currentStudentId!, 
          language: AppState().languageNotifier.value,
          lessonId: lessonId,
        );
        _studentProgress.add(newRecord);
        return newRecord;
      },
    );

    int grade = _calculateGrade(mistakeCount, timeToAnswerMs);

    if (grade >= 3) {
      record.repetitions++;
      if (record.repetitions == 1) {
        record.intervalMinutes = 1; 
      } else if (record.repetitions == 2) {
        record.intervalMinutes = 5; 
      } else {
        record.intervalMinutes = (record.intervalMinutes * record.easinessFactor).round();
      }
    } else {
      record.repetitions = 0;
      record.intervalMinutes = 1; 
    }

    record.easinessFactor = record.easinessFactor + (0.1 - (5 - grade) * (0.08 + (5 - grade) * 0.02));
    if (record.easinessFactor < 1.3) record.easinessFactor = 1.3;

    record.nextReviewDate = DateTime.now().add(Duration(minutes: record.intervalMinutes));

    await DatabaseHelper.instance.upsertLessonProgress(record);
  }

  int _calculateGrade(int mistakeCount, int latencyMs) {
    if (mistakeCount == 0) {
      return latencyMs <= 3000 ? 5 : 4;
    } else if (mistakeCount == 1) {
      return 3;
    } else if (mistakeCount == 2) {
      return 2;
    } else {
      return 0;
    }
  }
}
