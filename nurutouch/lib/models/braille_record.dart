class BrailleRecord {
  final int studentId;
  final String language;
  final String lessonId;
  double easinessFactor;
  int intervalMinutes;
  int repetitions;
  DateTime nextReviewDate;
  DateTime? lastReviewed;
  bool passed;

  BrailleRecord({
    required this.studentId,
    required this.language,
    required this.lessonId,
    this.easinessFactor = 2.5,
    this.intervalMinutes = 0,
    this.repetitions = 0,
    DateTime? nextReviewDate,
    this.lastReviewed,
    this.passed = false,
  }) : nextReviewDate = nextReviewDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'student_id': studentId,
      'language': language,
      'lesson_id': lessonId,
      'easiness_factor': easinessFactor,
      'interval_minutes': intervalMinutes,
      'repetitions': repetitions,
      'next_review_date': nextReviewDate.millisecondsSinceEpoch,
      'last_attempt_timestamp': (lastReviewed ?? DateTime.now()).millisecondsSinceEpoch,
      'passed': passed ? 1 : 0,
    };
  }

  factory BrailleRecord.fromMap(Map<String, dynamic> map) {
    return BrailleRecord(
      studentId: map['student_id'],
      language: map['language'] ?? 'en',
      lessonId: map['lesson_id'],
      easinessFactor: map['easiness_factor']?.toDouble() ?? 2.5,
      intervalMinutes: map['interval_minutes'] ?? 0,
      repetitions: map['repetitions'] ?? 0,
      nextReviewDate: map['next_review_date'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['next_review_date'])
          : null,
      lastReviewed: map['last_attempt_timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_attempt_timestamp'])
          : null,
      passed: map['passed'] == 1,
    );
  }
}
