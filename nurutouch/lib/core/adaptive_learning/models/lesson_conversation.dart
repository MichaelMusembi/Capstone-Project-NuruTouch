import 'narration_step.dart';

class LessonConversation {
  final List<NarrationStep> introduction; // greeting, connection, objective
  final List<NarrationStep> explanation;
  final List<NarrationStep> demonstration;
  final List<NarrationStep> practice;
  final List<NarrationStep> encouragement;
  final List<NarrationStep> retry; // hint, repractice
  final List<NarrationStep> success;
  final List<NarrationStep> completion;

  LessonConversation({
    this.introduction = const [],
    this.explanation = const [],
    this.demonstration = const [],
    this.practice = const [],
    this.encouragement = const [],
    this.retry = const [],
    this.success = const [],
    this.completion = const [],
  });
}
