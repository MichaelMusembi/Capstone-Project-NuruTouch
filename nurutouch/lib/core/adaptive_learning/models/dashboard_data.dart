class DashboardData {
  final int totalLessons;
  final int completedLessons;
  final double completionPercentage;
  final double masteryAverage;
  final List<String> strongestLessons;
  final List<String> weakestLessons;
  final String currentLesson;
  final int passedFirstAttempt;
  final int passedMultipleAttempts;

  DashboardData({
    required this.totalLessons,
    required this.completedLessons,
    required this.completionPercentage,
    required this.masteryAverage,
    required this.strongestLessons,
    required this.weakestLessons,
    required this.currentLesson,
    required this.passedFirstAttempt,
    required this.passedMultipleAttempts,
  });

  factory DashboardData.fromProgress(List<Map<String, dynamic>> progressRows, int totalCurriculumLessons) {
    if (progressRows.isEmpty) {
      return DashboardData(
        totalLessons: totalCurriculumLessons,
        completedLessons: 0,
        completionPercentage: 0,
        masteryAverage: 0,
        strongestLessons: [],
        weakestLessons: [],
        currentLesson: "None",
        passedFirstAttempt: 0,
        passedMultipleAttempts: 0,
      );
    }

    int completed = 0;
    double totalMastery = 0.0;
    int firstAttempt = 0;
    int multiAttempt = 0;

    // Sort by easiness factor for strongest/weakest
    List<Map<String, dynamic>> sortedByMastery = List.from(progressRows);
    sortedByMastery.sort((a, b) => (b['easiness_factor'] as double).compareTo(a['easiness_factor'] as double));

    for (var row in progressRows) {
      if (row['passed'] == 1) {
        completed++;
        int attempts = (row['repetitions'] ?? 1) as int;
        if (attempts <= 1) {
          firstAttempt++;
        } else {
          multiAttempt++;
        }
      }
      totalMastery += (row['easiness_factor'] as double);
    }

    // Most recent attempt is usually at the end of the chronological list, 
    // but let's sort by timestamp to be safe.
    List<Map<String, dynamic>> sortedByTime = List.from(progressRows);
    sortedByTime.sort((a, b) => (b['last_attempt_timestamp'] as int).compareTo(a['last_attempt_timestamp'] as int));

    return DashboardData(
      totalLessons: totalCurriculumLessons,
      completedLessons: completed,
      completionPercentage: totalCurriculumLessons == 0 ? 0 : (completed / totalCurriculumLessons) * 100,
      masteryAverage: totalMastery / progressRows.length,
      strongestLessons: sortedByMastery.take(3).map((r) => r['lesson_id'] as String).toList(),
      weakestLessons: sortedByMastery.reversed.take(3).map((r) => r['lesson_id'] as String).toList(),
      currentLesson: sortedByTime.isNotEmpty ? sortedByTime.first['lesson_id'] as String : "None",
      passedFirstAttempt: firstAttempt,
      passedMultipleAttempts: multiAttempt,
    );
  }
}
