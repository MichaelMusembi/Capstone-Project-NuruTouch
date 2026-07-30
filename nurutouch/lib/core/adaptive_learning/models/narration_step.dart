enum StepType { greeting, connection, objective, explanation, demonstration, practice, encouragement, retry, success, completion }

enum PlayCondition {
  always,
  firstAttempt,
  retryOnly,
  successOnly,
  failureOnly,
}

class NarrationStep {
  final StepType type;
  final String text;
  final bool interruptible;
  final bool repeatable;
  final PlayCondition condition;

  NarrationStep({
    required this.type,
    required this.text,
    this.interruptible = false,
    this.repeatable = true,
    this.condition = PlayCondition.always,
  });
}

class LearnerContext {
  final int attemptNumber;
  final int retryCount;
  final String? previousLessonId;
  final String? studentName;
  final String languageCode;
  final dynamic currentLesson;
  final bool isSessionStart;
  final int currentStreak;
  final bool justMastered;

  LearnerContext({
    this.attemptNumber = 1,
    this.retryCount = 0,
    this.previousLessonId,
    this.studentName,
    this.languageCode = 'en',
    this.currentLesson,
    this.isSessionStart = false,
    this.currentStreak = 0,
    this.justMastered = false,
  });

  LearnerContext copyWith({
    int? attemptNumber,
    int? retryCount,
    String? previousLessonId,
    String? studentName,
    String? languageCode,
    dynamic currentLesson,
    bool? isSessionStart,
    int? currentStreak,
    bool? justMastered,
  }) {
    return LearnerContext(
      attemptNumber: attemptNumber ?? this.attemptNumber,
      retryCount: retryCount ?? this.retryCount,
      previousLessonId: previousLessonId ?? this.previousLessonId,
      studentName: studentName ?? this.studentName,
      languageCode: languageCode ?? this.languageCode,
      currentLesson: currentLesson ?? this.currentLesson,
      isSessionStart: isSessionStart ?? this.isSessionStart,
      currentStreak: currentStreak ?? this.currentStreak,
      justMastered: justMastered ?? this.justMastered,
    );
  }
}
