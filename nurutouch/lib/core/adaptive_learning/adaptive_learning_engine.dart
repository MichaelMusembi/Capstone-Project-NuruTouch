import 'models/lesson.dart';
import 'curriculum_database.dart';
import 'mastery_calculator.dart';
import '../../data/local/database_helper.dart';
import '../../models/braille_record.dart';

class LessonResult {
  final double accuracy;
  final int attempts;
  final int responseTime; // in seconds
  final int hintsUsed;
  final bool mastered;

  LessonResult({
    this.accuracy = 1.0,
    required this.attempts,
    required this.responseTime,
    required this.hintsUsed,
    required this.mastered,
  });
}

class AdaptiveLearningEngine {
  static final AdaptiveLearningEngine _instance = AdaptiveLearningEngine._internal();
  static AdaptiveLearningEngine get instance => _instance;

  AdaptiveLearningEngine._internal();

  final MasteryCalculator _masteryCalculator = MasteryCalculator();

  Future<Lesson?> getNextLesson(int studentId, String languageCode, {LessonType? typeFilter}) async {
    final curriculum = CurriculumDatabase.instance;
    final allLessons = languageCode.startsWith('sw') ? curriculum.swahiliLessons : curriculum.englishLessons;
    
    // Check if there's any review due (easinessFactor < 80.0 means struggling)
    final progress = await DatabaseHelper.instance.getStudentProgress(studentId, languageCode: languageCode);
    if (progress.isNotEmpty) {
      final records = progress.map((m) => BrailleRecord.fromMap(m)).toList();
      records.sort((a, b) => a.easinessFactor.compareTo(b.easinessFactor)); // Lowest mastery first
      
      final strugglingRecord = records.first;
      if (strugglingRecord.easinessFactor < 80.0) {
        final reviewLesson = curriculum.getLessonById(strugglingRecord.lessonId, languageCode);
        if (reviewLesson != null && (typeFilter == null || reviewLesson.type == typeFilter)) {
          return reviewLesson;
        }
      }
    }

    final targetLessons = typeFilter != null 
        ? allLessons.where((l) => l.type == typeFilter).toList() 
        : allLessons;

    // Helper to recursively find the deepest unpassed prerequisite
    Future<Lesson?> getDeepestUnpassed(Lesson current) async {
      if (typeFilter != null) return current; // Bypass prereqs for direct testing

      for (String prereqId in current.prerequisites) {
        final hasPassed = await DatabaseHelper.instance.hasPassedLesson(studentId, languageCode, prereqId);
        if (!hasPassed) {
          final prereqLesson = curriculum.getLessonById(prereqId, languageCode);
          if (prereqLesson != null) {
            return await getDeepestUnpassed(prereqLesson);
          }
        }
      }
      return current; // All prerequisites are passed, so this is the blocker
    }

    // Find first target lesson that is NOT passed
    for (var lesson in targetLessons) {
      final hasPassed = await DatabaseHelper.instance.hasPassedLesson(studentId, languageCode, lesson.id);
      if (!hasPassed) {
        return await getDeepestUnpassed(lesson);
      }
    }

    // If all passed, return the one with the lowest mastery score to create an infinite spaced-repetition loop
    if (progress.isNotEmpty) {
      final records = progress.map((m) => BrailleRecord.fromMap(m)).toList();
      records.sort((a, b) => a.easinessFactor.compareTo(b.easinessFactor));
      
      for (var record in records) {
        final reviewLesson = curriculum.getLessonById(record.lessonId, languageCode);
        if (reviewLesson != null && (typeFilter == null || reviewLesson.type == typeFilter)) {
          return reviewLesson;
        }
      }
    }

    return null;
  }

  Future<bool> isTypeUnlocked(int studentId, String languageCode, LessonType targetType) async {
    if (targetType == LessonType.letter) return true; // Always unlocked
    
    final curriculum = CurriculumDatabase.instance;
    final allLessons = languageCode.startsWith('sw') ? curriculum.swahiliLessons : curriculum.englishLessons;
    
    if (targetType == LessonType.word) {
      // Unlocked if AT LEAST ONE letter has been mastered (or all letters, depending on strictness).
      // Let's use: Unlocked if they've passed at least 5 letter lessons (or all available if fewer).
      final letterLessons = allLessons.where((l) => l.type == LessonType.letter).toList();
      if (letterLessons.isEmpty) return true;
      
      int passedCount = 0;
      for (var l in letterLessons) {
        if (await DatabaseHelper.instance.hasPassedLesson(studentId, languageCode, l.id)) {
          passedCount++;
        }
      }
      return passedCount >= 3; // Unlock words after learning at least 3 letters
    }
    
    if (targetType == LessonType.sentence) {
      final wordLessons = allLessons.where((l) => l.type == LessonType.word).toList();
      if (wordLessons.isEmpty) return true;
      
      int passedCount = 0;
      for (var l in wordLessons) {
        if (await DatabaseHelper.instance.hasPassedLesson(studentId, languageCode, l.id)) {
          passedCount++;
        }
      }
      return passedCount >= 3; // Unlock sentences after learning at least 3 words
    }
    
    return true;
  }

  Future<Lesson?> processLessonResult(int studentId, String lessonId, String languageCode, LessonResult result, {LessonType? typeFilter}) async {
    // 1. Calculate mastery update
    final currentScore = _masteryCalculator.calculateScore(result.mastered, result.hintsUsed, result.responseTime);
    
    // 2. Save to database
    // TODO: [Post-MVP] We currently discard the raw 'hintsUsed' and 'responseTime' after calculating 'currentScore'.
    // TODO: [Post-MVP] In V3, update BrailleRecord and SQLite schema to persist:
    // TODO: [Post-MVP] - hints_used (INTEGER)
    // TODO: [Post-MVP] - response_time_seconds (INTEGER)
    // TODO: [Post-MVP] This will allow the Dashboard to display rich analytics.
    final record = BrailleRecord(
      studentId: studentId,
      language: languageCode,
      lessonId: lessonId,
      easinessFactor: currentScore, // using easinessFactor to store mastery 0-100 for now
      intervalMinutes: 0,
      repetitions: result.attempts,
      lastReviewed: DateTime.now(),
      passed: result.mastered,
    );
    await DatabaseHelper.instance.upsertLessonProgress(record);

    // 3. Determine next lesson
    return getNextLesson(studentId, languageCode, typeFilter: typeFilter);
  }
}
