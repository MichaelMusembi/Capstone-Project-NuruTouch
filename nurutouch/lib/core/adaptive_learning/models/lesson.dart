enum LessonType {
  readiness,
  instruction,
  practice,
  letter,
  word,
  sentence,
  review,
}

enum ExpectedAction { swipeDown, swipeRight, tapBraille, typeWord, none }

ExpectedAction _actionFromString(String? actionStr) {
  switch (actionStr) {
    case 'swipe_down': return ExpectedAction.swipeDown;
    case 'swipe_right': return ExpectedAction.swipeRight;
    case 'tap_braille': return ExpectedAction.tapBraille;
    case 'type_word': return ExpectedAction.typeWord;
    default: return ExpectedAction.tapBraille; // Default for typing
  }
}

class SequenceStep {
  final ExpectedAction expectedAction;
  final List<int> targetDots;
  final String? character;
  final String? ref;

  SequenceStep({
    required this.expectedAction,
    this.targetDots = const [],
    this.character,
    this.ref,
  });

  factory SequenceStep.fromMap(Map<String, dynamic> map) {
    List<int> parsedDots = [];
    if (map['target_dots'] != null) {
      parsedDots = List<int>.from(map['target_dots']);
    } else if (map['dots'] != null) {
      parsedDots = List<int>.from(map['dots']);
    }
    
    return SequenceStep(
      expectedAction: _actionFromString(map['expected_action'] ?? map['action']),
      targetDots: parsedDots,
      character: (map['character'] ?? map['letter']) as String?,
      ref: map['ref'] as String?,
    );
  }
}

class NarrationStepSchema {
  final String type;
  final String text;

  NarrationStepSchema({required this.type, required this.text});

  factory NarrationStepSchema.fromMap(Map<String, dynamic> map) {
    return NarrationStepSchema(
      type: map['type'] as String? ?? 'explain',
      text: map['text'] as String? ?? '',
    );
  }
}

class NarrationSchema {
  final String? character;
  final String? spokenForm;
  final List<NarrationStepSchema> steps;

  NarrationSchema({
    this.character,
    this.spokenForm,
    this.steps = const [],
  });

  factory NarrationSchema.fromMap(Map<String, dynamic> map) {
    var stepsList = <NarrationStepSchema>[];
    if (map['steps'] != null) {
      stepsList = (map['steps'] as List).map((e) => NarrationStepSchema.fromMap(e as Map<String, dynamic>)).toList();
    }
    return NarrationSchema(
      character: map['character'] as String?,
      spokenForm: map['spoken_form'] as String?,
      steps: stepsList,
    );
  }
}

class Lesson {
  final String id;
  final LessonType type;
  final String? target;
  final List<int>? dots;
  final String? intro;
  final String? hint;
  final String? success;
  final List<String> explanation;
  final List<String> demonstration;
  final List<String> practice;
  final List<SequenceStep> sequence;
  final List<String> prerequisites;
  final List<String> unlocks;
  final List<String>? confuserFamily;
  final NarrationSchema? narration;
  final String? soundForm;

  Lesson({
    required this.id,
    required this.type,
    this.target,
    this.dots,
    this.intro,
    this.hint,
    this.success,
    this.explanation = const [],
    this.demonstration = const [],
    this.practice = const [],
    this.sequence = const [],
    this.prerequisites = const [],
    this.unlocks = const [],
    this.confuserFamily,
    this.narration,
    this.soundForm,
  });

  factory Lesson.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type'] as String? ?? 'practice';
    LessonType type;
    switch (typeStr) {
      case 'readiness': type = LessonType.readiness; break;
      case 'instruction': type = LessonType.instruction; break;
      case 'orientation': type = LessonType.instruction; break;
      case 'braille_cell': type = LessonType.instruction; break;
      case 'letter': type = LessonType.letter; break;
      case 'word': type = LessonType.word; break;
      case 'sentence': type = LessonType.sentence; break;
      case 'review': type = LessonType.review; break;
      case 'practice':
      default: type = LessonType.practice; break;
    }

    List<int>? parsedDots;
    if (map['target_dots'] != null) {
      parsedDots = List<int>.from(map['target_dots']);
    } else if (map['dots'] != null) {
      parsedDots = List<int>.from(map['dots']);
    }

    List<SequenceStep> parsedSequence = [];
    if (map['sequence'] != null) {
      final seqList = map['sequence'] as List;
      parsedSequence = seqList.map((e) => SequenceStep.fromMap(Map<String,dynamic>.from(e))).toList();
    }

    // Handle nested content
    Map<String, dynamic> content = {};
    if (map['content'] != null) {
      content = Map<String, dynamic>.from(map['content']);
    }

    List<String> parseStringList(dynamic value) {
      if (value == null) return [];
      if (value is String) return [value];
      if (value is List) return value.map((e) => e.toString()).toList();
      return [];
    }

    List<String> prereqs = [];
    if (map['prerequisites'] != null) {
      prereqs = List<String>.from(map['prerequisites']);
    }

    List<String> unlks = [];
    if (map['unlocks'] != null) {
      unlks = List<String>.from(map['unlocks']);
    }

    List<String>? confusers;
    if (map['confuser_family'] != null) {
      confusers = List<String>.from(map['confuser_family']);
    }

    NarrationSchema? narrationSchema;
    if (map['narration'] != null) {
      narrationSchema = NarrationSchema.fromMap(Map<String, dynamic>.from(map['narration']));
    }

    String extractTarget(String id) {
      final parts = id.split('_');
      if (parts.length > 2) {
        return parts.sublist(2).join(' ').toUpperCase();
      }
      return id.toUpperCase();
    }

    return Lesson(
      id: map['id'] as String,
      type: type,
      target: (map['target'] ?? map['target_word'] ?? map['target_letter'] ?? content['character'] ?? narrationSchema?.character) as String? ?? extractTarget(map['id'] as String),
      dots: parsedDots,
      intro: (content['intro'] ?? map['intro']) as String?,
      hint: (content['hint'] ?? map['hint']) as String?,
      success: (content['success'] ?? map['success']) as String?,
      explanation: parseStringList(content['explanation']),
      demonstration: parseStringList(content['demonstration']),
      practice: parseStringList(content['practice']),
      sequence: parsedSequence,
      prerequisites: prereqs,
      unlocks: unlks,
      confuserFamily: confusers,
      narration: narrationSchema,
      soundForm: content['sound_form'] as String?,
    );
  }
}