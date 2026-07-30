import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import '../core/adaptive_learning/models/lesson.dart';
import '../core/adaptive_learning/models/narration_step.dart';
import '../core/adaptive_learning/models/lesson_conversation.dart';
import 'narration_service.dart';

class TeacherAminaService {
  Map<int, Map<String, dynamic>> _dotDescriptions = {};
  
  // NOTE: For Swahili, we rely on the YAML files containing 'Silabi' forms 
  // (e.g. 'Ba' instead of 'B') directly in the text. We pass this text to 
  // the TTS engine using the 'sw-KE' locale without further modification,
  // which ensures correct pronunciation of consonants.
  TeacherAminaService(NarrationService narrationService);

  Future<void> initialize(String language) async {
    try {
      final yamlString = await rootBundle.loadString('assets/narration/dot_descriptions.yaml');
      final yamlDoc = loadYaml(yamlString);
      final dots = yamlDoc['dots'] as Map;
      _dotDescriptions.clear();
      dots.forEach((key, value) {
        int dotKey;
        if (key is int) {
          dotKey = key;
        } else if (key is String) {
          dotKey = int.parse(key);
        } else {
          return;
        }
        _dotDescriptions[dotKey] = Map<String, dynamic>.from(value);
      });
    } catch (e) {
      print('Failed to load dot descriptions: $e');
    }
  }

  Future<LessonConversation> buildConversation(Lesson lesson, LearnerContext context, String lang) async {
    List<NarrationStep> intro = [];
    List<NarrationStep> explanation = [];
    List<NarrationStep> demonstration = [];
    List<NarrationStep> practice = [];
    List<NarrationStep> retry = [];
    List<NarrationStep> success = [];

    final narration = lesson.narration;

    if (narration != null) {
      bool isReview = lesson.type == LessonType.review;
      
      for (var step in narration.steps) {
        if (step.type == 'explain') {
          if (!isReview) {
            explanation.add(NarrationStep(type: StepType.explanation, text: step.text, interruptible: false, repeatable: true));
          }
        } else if (step.type == 'prompt') {
          practice.add(NarrationStep(type: StepType.practice, text: step.text, interruptible: true, repeatable: true));
        } else if (step.type == 'retry') {
          retry.add(NarrationStep(type: StepType.retry, text: step.text, interruptible: true, repeatable: true, condition: PlayCondition.retryOnly));
        } else if (step.type == 'success') {
          success.add(NarrationStep(type: StepType.success, text: step.text, interruptible: true, repeatable: false, condition: PlayCondition.successOnly));
        }
      }
    } else {
      // Fallback to legacy flat schema
      if (lesson.intro != null && lesson.intro!.isNotEmpty) {
        intro.add(NarrationStep(type: StepType.objective, text: lesson.intro!, interruptible: true, repeatable: true, condition: PlayCondition.always));
      }
      for (var exp in lesson.explanation) {
        explanation.add(NarrationStep(type: StepType.explanation, text: exp, interruptible: false, repeatable: true));
      }
      for (var dem in lesson.demonstration) {
        demonstration.add(NarrationStep(type: StepType.demonstration, text: dem, interruptible: false, repeatable: true));
      }
      for (var prac in lesson.practice) {
        practice.add(NarrationStep(type: StepType.practice, text: prac, interruptible: true, repeatable: true));
      }
      if (lesson.hint != null && lesson.hint!.isNotEmpty) {
        retry.add(NarrationStep(type: StepType.retry, text: lesson.hint!, interruptible: true, repeatable: true, condition: PlayCondition.retryOnly));
      } else {
        retry.add(NarrationStep(type: StepType.retry, text: lang.startsWith('sw') ? 'Jaribu tena.' : 'Try again.', interruptible: true, repeatable: true, condition: PlayCondition.retryOnly));
      }
      if (lesson.success != null && lesson.success!.isNotEmpty) {
        success.add(NarrationStep(type: StepType.success, text: lesson.success!, interruptible: true, repeatable: false, condition: PlayCondition.successOnly));
      } else {
        success.add(NarrationStep(type: StepType.success, text: lang.startsWith('sw') ? 'Safi sana.' : 'Great job.', interruptible: true, repeatable: false, condition: PlayCondition.successOnly));
      }
    }
    
    bool isReview = lesson.type == LessonType.review;
    if (!isReview && lesson.type == LessonType.letter) {
      List<int> targetDots = [];
      if (lesson.dots != null && lesson.dots!.isNotEmpty) {
        targetDots = List<int>.from(lesson.dots!);
      } else if (lesson.sequence.isNotEmpty) {
        targetDots = List<int>.from(lesson.sequence.first.targetDots);
      }
      
      if (targetDots.isNotEmpty && _dotDescriptions.isNotEmpty) {
        String dynamicExpl = "";
        for (int dot in targetDots) {
           final desc = _dotDescriptions[dot];
           if (desc != null) {
              if (lang.startsWith('sw')) {
                 dynamicExpl += "Kitone $dot kiko ${desc['position_sw']}, gusa na ${desc['finger_name_sw']}. ";
              } else {
                 dynamicExpl += "Dot $dot is ${desc['position_en']}, tap with your ${desc['finger_name_en']}. ";
              }
           }
        }
        if (dynamicExpl.isNotEmpty) {
          explanation.add(NarrationStep(type: StepType.explanation, text: dynamicExpl.trim(), interruptible: false, repeatable: true));
        }
      }
    }

    return LessonConversation(
      introduction: intro,
      explanation: explanation,
      demonstration: demonstration,
      practice: practice,
      retry: retry,
      success: success,
    );
  }
}
