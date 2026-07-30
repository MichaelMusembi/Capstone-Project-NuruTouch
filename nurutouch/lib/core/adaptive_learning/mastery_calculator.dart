class MasteryCalculator {
  /// Calculates a mastery score from 0.0 to 100.0 based on Volume 19A.
  /// Suggested weighting:
  /// - Accuracy: 60%
  /// - Independence (no hints): 20%
  /// - Completion: 10%
  /// - Response Time: 10%
  double calculateScore(bool passed, int hintsUsed, int durationSeconds) {
    if (!passed) return 20.0; // Needs support

    double score = 0.0;

    // Accuracy & Completion (if passed, they got it right) -> 70% total
    score += 70.0;

    // Independence: 20% (minus 5% per hint used)
    double hintScore = 20.0 - (hintsUsed * 5.0);
    if (hintScore < 0) hintScore = 0;
    score += hintScore;

    // Response Time: 10% (full score if under 10 seconds)
    double timeScore = 10.0;
    if (durationSeconds > 10) {
      timeScore = 10.0 - ((durationSeconds - 10) * 0.5);
      if (timeScore < 0) timeScore = 0;
    }
    score += timeScore;

    return score.clamp(0.0, 100.0);
  }
}
