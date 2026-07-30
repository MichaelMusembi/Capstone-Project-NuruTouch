import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/tts_service.dart';
import '../../services/haptic_service.dart';
import '../../services/audio_service.dart';
import 'home_menu_screen.dart';
import '../../services/teacher_amina_service.dart';
import '../../data/local/app_state.dart';
import '../../data/local/database_helper.dart';
import '../../core/adaptive_learning/models/lesson.dart';
import '../../core/adaptive_learning/adaptive_learning_engine.dart';
import '../../services/narration_service.dart';
import '../../core/adaptive_learning/models/narration_step.dart';
import '../../core/adaptive_learning/models/lesson_conversation.dart';
import '../../core/adaptive_learning/curriculum_database.dart';
import '../supervisor/global_pin_gate.dart';
import 'home_menu_screen.dart';

class AdaptiveTouchScreen extends StatefulWidget {
  final LessonType? lessonFilter;
  const AdaptiveTouchScreen({super.key, this.lessonFilter});

  @override
  State<AdaptiveTouchScreen> createState() => _AdaptiveTouchScreenState();
}

class _AdaptiveTouchScreenState extends State<AdaptiveTouchScreen> {
  final Map<int, Offset> _activePointers = {};
  final Map<int, Offset> _startPositions = {};
  
  final HapticService _hapticService = HapticService();
  final NarrationService _narration = NarrationService.instance;
  final TtsService _ttsService = TtsService();
  late TeacherAminaService _teacherAmina;
  
  Lesson? _currentLesson;
  bool _isLoading = true;
  LessonConversation? _conversation;
  late LearnerContext _learnerContext;
  
  final Map<int, Color> _dotColors = {};
  final Map<int, Timer> _dotTimers = {};
  
  // Gesture visualization
  Offset? _swipeStart;
  Offset? _swipeEnd;
  Timer? _swipeTimer;

  final Set<int> _currentChord = {};
  int _maxPointersInCurrentStrike = 0;
  int _tapCountBeforeSwipe = 0;
  
  int _mistakes = 0;
  int _hints = 0;
  int _startTime = 0;
  int _lastTapTime = 0;

  // Track progress in multi-character lessons (e.g., words)
  int _charIndex = 0;
  int _sequenceIndex = 0;
  int _consecutiveMistakes = 0;

  LessonType? _currentTypeFilter;

  @override
  void initState() {
    super.initState();
    _currentTypeFilter = widget.lessonFilter;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _teacherAmina = TeacherAminaService(_narration);
    _learnerContext = LearnerContext(attemptNumber: 1, isSessionStart: true);
    
    // Initialize TeacherAmina strategies then load lesson
    _initAndLoadLesson();
  }

  Future<void> _initAndLoadLesson() async {
    final lang = AppState().languageNotifier.value;
    await _teacherAmina.initialize(lang);
    await _loadNextLesson();
  }

  @override
  void dispose() {
    _narration.stop();
    _strikeCompletionTimer?.cancel();
    _swipeTimer?.cancel();
    _dotTimers.values.forEach((t) => t.cancel());
    super.dispose();
  }

  Future<void> _loadNextLesson() async {
    setState(() => _isLoading = true);
    
    _mistakes = 0;
    _hints = 0;
    _charIndex = 0;
    _currentChord.clear();
    
    final studentId = AppState().currentStudentId ?? 1;
    final lang = AppState().languageNotifier.value;
    
    // Check for exact session resumption
    final state = await DatabaseHelper.instance.getSessionState(studentId, lang);
    if (state != null) {
       final savedLesson = CurriculumDatabase.instance.getLessonById(state['current_lesson_id'], lang);
       if (savedLesson != null) {
          _currentLesson = savedLesson;
          _sequenceIndex = state['current_item_index'];
          
          _learnerContext = _learnerContext.copyWith(
            attemptNumber: 1,
            retryCount: 0,
            languageCode: lang,
            currentLesson: _currentLesson,
            isSessionStart: false,
          );
          _startTime = DateTime.now().millisecondsSinceEpoch;
          setState(() => _isLoading = false);
          _playLessonIntro();
          return;
       }
    }

    _sequenceIndex = 0;
    
    _currentLesson = await AdaptiveLearningEngine.instance.getNextLesson(studentId, lang, typeFilter: _currentTypeFilter);
    
    _currentLesson = await AdaptiveLearningEngine.instance.getNextLesson(studentId, lang, typeFilter: _currentTypeFilter);
    bool hasPassed = false;
    if (_currentLesson != null) {
      hasPassed = await DatabaseHelper.instance.hasPassedLesson(studentId, lang, _currentLesson!.id);
    }
    
    _learnerContext = _learnerContext.copyWith(
      attemptNumber: 1,
      retryCount: 0,
      languageCode: lang,
      currentLesson: _currentLesson,
      previousLessonId: _learnerContext.currentLesson?.id ?? _learnerContext.previousLessonId,
      isSessionStart: !hasPassed,
    );

    _startTime = DateTime.now().millisecondsSinceEpoch;
    setState(() => _isLoading = false);

    if (_currentLesson != null) {
      _playLessonIntro();
    } else {
      _narration.speakRaw(lang.startsWith('sw') ? "Umepita masomo yote! Telezesha vidole viwili chini ili kurudi." : "You have completed all lessons! Swipe down with two fingers to go back.", lang, appendReminder: true);
    }
  }

  void _playLessonIntro() async {
    if (_currentLesson == null) return;
    final lang = AppState().languageNotifier.value;

    // 1. Ask Teacher Amina to build the conversation cache
    _conversation = await _teacherAmina.buildConversation(_currentLesson!, _learnerContext, lang);
    
    // 2. Add global navigation prompt if needed
    List<NarrationStep> initialQueue = [
      ..._conversation!.introduction,
      ..._conversation!.explanation,
      ..._conversation!.demonstration,
      ..._conversation!.practice,
    ];

    if (_currentLesson!.type == LessonType.instruction) {
      final globalNavText = lang.startsWith('sw') ? "Telezesha kidole kimoja chini ili kuendelea." : "Swipe down with one finger to continue.";
      initialQueue.add(NarrationStep(
        type: StepType.practice,
        text: globalNavText,
        repeatable: true,
      ));
    }

    // 3. Play the initial queue
    await _narration.playQueue(initialQueue, lang);
  }

  
  void _flashDots(List<int> dots, Color color) {
    setState(() {
      for (int dot in dots) {
        _dotColors[dot] = color;
        _dotTimers[dot]?.cancel();
        _dotTimers[dot] = Timer(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              _dotColors.remove(dot);
            });
          }
        });
      }
    });
  }


  bool _gestureCooldown = false;
  int _lastGestureTime = 0;
  Timer? _strikeCompletionTimer;

  void _handlePointerDown(PointerDownEvent event) {
    if (_currentLesson == null || _gestureCooldown) return;
    
    // Check for TTS playback to prevent audio overlap and force full listening
    if (TtsService().isSpeaking) {
      _hapticService.errorBuzz();
      return;
    }
    
    _strikeCompletionTimer?.cancel();

    setState(() {
      _activePointers[event.pointer] = event.position;
      _startPositions[event.pointer] = event.position;
      if (_activePointers.length == 1) {
        _tapCountBeforeSwipe++;
      }
      
      if (_activePointers.length > _maxPointersInCurrentStrike) {
        _maxPointersInCurrentStrike = _activePointers.length;
      }
      
      debugPrint('[NuruTouch] _handlePointerDown: pointer=${event.pointer}, pos=${event.position}, active_count=${_activePointers.length}');

      int dot = _identifyDotZone(event.position);
      if (dot != -1) {
        _currentChord.add(dot);
        _hapticService.tick(); 
        
        // Drift adaptation with bounds (Device independent)
        final double maxDrift = MediaQuery.of(context).size.shortestSide * 0.15;
        final calibrated = AppState().calibratedDots;
        if (calibrated != null && calibrated.containsKey(dot)) {
           final oldPos = calibrated[dot]!;
           if ((event.position - oldPos).distance < maxDrift) {
             calibrated[dot] = Offset(
                oldPos.dx * 0.9 + event.position.dx * 0.1,
                oldPos.dy * 0.9 + event.position.dy * 0.1
             );
             AppState().saveCalibration(calibrated);
           }
        }

         // Immediate evaluation is now deferred to _handlePointerUp to allow swipes to register.
      }
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_gestureCooldown) return;
    if (_activePointers.containsKey(event.pointer)) {
      _activePointers[event.pointer] = event.position;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_gestureCooldown) return;
    if (!_startPositions.containsKey(event.pointer)) return;
    Offset startPos = _startPositions[event.pointer] ?? event.position;
    Offset endPos = event.position;
    
    setState(() {
      _activePointers.remove(event.pointer);
    });

    // 1. Differentiate Swipe vs Tap immediately on any finger lift
    double dx = endPos.dx - startPos.dx;
    double dy = endPos.dy - startPos.dy;
    bool isSwipe = dx.abs() > 80.0 || dy.abs() > 80.0;
    
    if (isSwipe) {
       debugPrint('[NuruTouch] _handlePointerUp: Swipe detected instantly on a lifting finger! dx=$dx, dy=$dy');
       _analyzeGestureAndExecute(startPos, endPos);
       _resetStateAfterInteraction();
       return;
    }

    if (_activePointers.isEmpty) {
      // 2. If it's a tap, check for Immediate Success Match (to avoid 1200ms delay if perfect)
      final expectedAction = _getCurrentExpectedAction();
      if (expectedAction == ExpectedAction.tapBraille) {
         List<int> target = _getCurrentTargetDots()..sort();
         List<int> current = _currentChord.toList()..sort();
         if (target.isNotEmpty && _listEquals(current, target)) {
            debugPrint('[NuruTouch] _handlePointerUp: Perfect Tap Match on lift! Triggering success.');
            _evaluateSequenceStep(current, ExpectedAction.tapBraille);
            _resetStateAfterInteraction();
            return;
         }
      }

      // 3. Otherwise, wait 1200ms for more fingers (or for an imperfect tap to register as a mistake)
      debugPrint('[NuruTouch] _handlePointerUp: All fingers lifted. Starting 1200ms _strikeCompletionTimer...');
      _strikeCompletionTimer?.cancel();
      _strikeCompletionTimer = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        debugPrint('[NuruTouch] _strikeCompletionTimer fired. Evaluating tap. _currentChord: ${_currentChord.toList()}');
        _analyzeGestureAndExecute(startPos, endPos);
        _resetStateAfterInteraction();
      });
    }
  }

  void _resetStateAfterInteraction() {
    _strikeCompletionTimer?.cancel();
    _maxPointersInCurrentStrike = 0;
    _startPositions.clear();
    _currentChord.clear();
    _tapCountBeforeSwipe = 0;
    
    _gestureCooldown = true;
    Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _gestureCooldown = false;
          _activePointers.clear();
          _currentChord.clear();
        });
      }
    });
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_gestureCooldown) return;
    if (!_startPositions.containsKey(event.pointer)) return;
    setState(() {
      _activePointers.remove(event.pointer);
    });
    if (_activePointers.isEmpty) {
      _maxPointersInCurrentStrike = 0;
      _startPositions.clear();
      _currentChord.clear();
      _tapCountBeforeSwipe = 0;
    }
  }

  int _identifyDotZone(Offset pos) {
    Map<int, Offset> zones;
    if (AppState().isCalibrated) {
      zones = AppState().calibratedDots;
    } else {
      zones = _getDefaultDots(MediaQuery.of(context).size);
    }
    
    double minDistance = double.infinity;
    int closestDot = -1;
    final threshold = MediaQuery.of(context).size.shortestSide * 0.45; 

    zones.forEach((dotNumber, center) {
      double dist = (pos - center).distance;
      if (dist < minDistance && dist < threshold) {
        minDistance = dist;
        closestDot = dotNumber;
      }
    });
    debugPrint('[NuruTouch] _identifyDotZone: pos=$pos -> dot=$closestDot (minDist=$minDistance, threshold=$threshold)');
    return closestDot;
  }

  void _logGestureEvent(String gestureType, int fingerCount, bool success) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/gesture_logs.txt');
      final timestamp = DateTime.now().toIso8601String();
      final logEntry = '[$timestamp] Type: $gestureType, Fingers: $fingerCount, Success: $success\n';
      await file.writeAsString(logEntry, mode: FileMode.append);
      debugPrint(logEntry);
    } catch (e) {
      debugPrint('Failed to log gesture: $e');
    }
  }

  void _analyzeGestureAndExecute(Offset start, Offset end) {
    double dx = end.dx - start.dx;
    double dy = end.dy - start.dy;
    int now = DateTime.now().millisecondsSinceEpoch;

    // Detect Double Tap (Repeat Instruction)
    if (dx.abs() < 20 && dy.abs() < 20 && _maxPointersInCurrentStrike == 1) {
      if (now - _lastTapTime < 500) {
        _logGestureEvent('DoubleTap', 1, true);
        _hapticService.tick();
        _ttsService.stop(); // Prevent audio overlap
        _playLessonIntro();
        _lastTapTime = 0; // reset
        return;
      }
      _lastTapTime = now;
    }

    double swipeThreshold = 80.0;

    // Detect Swipe Left (Go Back)
    if (dx < -swipeThreshold && dy.abs() < dx.abs()) {
      _logGestureEvent('SwipeLeft', _maxPointersInCurrentStrike, true);
      _hapticService.errorBuzz();
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeMenuScreen()));
      }
      return;
    }

    // Detect Swipe Right (Sequence Skip/Next or 2-Finger Hint)
    if (dx > swipeThreshold && dy.abs() < dx) {
      _logGestureEvent('SwipeRight', _maxPointersInCurrentStrike, true);
      setState(() {
        _swipeStart = start;
        _swipeEnd = end;
        _swipeTimer?.cancel();
        _swipeTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted) setState(() { _swipeStart = null; _swipeEnd = null; });
        });
      });
      if (_maxPointersInCurrentStrike == 1) {
        // Context-aware swipe right (Section 2.4)
        if (_currentLesson != null && _currentLesson!.type == LessonType.sentence) {
          _evaluateSequenceStep(null, ExpectedAction.swipeRight); // The sequence expects swipeRight for space
          return;
        }

        // First try to evaluate it as a sequence step (if expected)
        if (_currentLesson != null && _sequenceIndex < _currentLesson!.sequence.length) {
          if (_currentLesson!.sequence[_sequenceIndex].expectedAction == ExpectedAction.swipeRight) {
             _evaluateSequenceStep(null, ExpectedAction.swipeRight);
             return;
          }
        }
        // NO GLOBAL SKIP FOR 1-FINGER SWIPE RIGHT TO PREVENT ACCIDENTAL TRIGGERS
      } else if (_maxPointersInCurrentStrike == 2) {
        _hapticService.tick();
        _ttsService.stop(); // Stop audio before hint
        _provideHint(errorType: 'generic');
      }
      return;
    }

    // Detect Swipe Down
    if (dy > swipeThreshold && dx.abs() < dy) {
      setState(() {
        _swipeStart = start;
        _swipeEnd = end;
        _swipeTimer?.cancel();
        _swipeTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted) setState(() { _swipeStart = null; _swipeEnd = null; });
        });
      });
      if (_maxPointersInCurrentStrike == 1) {
        _evaluateSequenceStep(null, ExpectedAction.swipeDown);
      } else if (_maxPointersInCurrentStrike == 2) {
        _hapticService.errorBuzz();
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeMenuScreen()));
        }
      } else if (_maxPointersInCurrentStrike >= 3) {
        _toggleLanguage();
      }
      return;
    }

    if (_currentChord.isNotEmpty) {
      debugPrint('[NuruTouch] _analyzeGestureAndExecute: Evaluated as tapBraille. Pointers: $_maxPointersInCurrentStrike, chord: ${_currentChord.toList()}');
      _evaluateSequenceStep(_currentChord.toList(), ExpectedAction.tapBraille);
      return;
    }
    
    // CATCH-ALL: log-gap-healer global fallback
    debugPrint('[NuruTouch] _analyzeGestureAndExecute: CATCH-ALL triggered. Chord is empty, gestures did not match.');
    _logGestureEvent('Unhandled', _maxPointersInCurrentStrike, false);
    _hapticService.errorBuzz();
    _currentChord.clear();
    
    String langCode = AppState().languageNotifier.value;
    String fallbackMsg = langCode == 'sw' 
        ? "Sijatambua hilo. Hebu jaribu tena."
        : "Let's try that again. Swipe down to continue.";
    _ttsService.stop();
    _ttsService.speak(fallbackMsg, language: langCode == 'sw' ? 'sw-KE' : 'en-US');
  }

  bool _isReversal(List<int> tapped, List<int> target) {
    if (tapped.length != target.length || target.isEmpty) return false;
    List<int> mirrored = target.map((d) {
      if (d == 1) return 4;
      if (d == 2) return 5;
      if (d == 3) return 6;
      if (d == 4) return 1;
      if (d == 5) return 2;
      if (d == 6) return 3;
      return d;
    }).toList();
    mirrored.sort();
    List<int> t = List.from(tapped)..sort();
    return _listEquals(t, mirrored);
  }

  bool _isDroppedDot(List<int> input, List<int> target) {
    if (input.isEmpty) return false;
    for (int dot in input) {
      if (!target.contains(dot)) return false;
    }
    return input.length < target.length;
  }

  bool _hasExtraDots(List<int> input, List<int> target) {
    if (input.isEmpty) return false;
    for (int dot in input) {
      if (!target.contains(dot)) return true;
    }
    return false;
  }

  bool _isConfuserFamily(Lesson? lesson, List<int> inputDots) {
    if (lesson == null || lesson.confuserFamily == null || lesson.confuserFamily!.isEmpty) return false;
    
    // We would need a mapping of letters to dots to dynamically check if inputDots 
    // exactly matches another letter in the confuser family.
    // For simplicity, if the lesson has a confuser family and the error is a reversal, 
    // we assume the hint applies.
    return true; 
  }

  void _toggleLanguage() async {
    _hapticService.successPulse();
    await _narration.stop();
    await _ttsService.stop();
    
    String current = AppState().languageNotifier.value;
    String newLang = (current == "en") ? "sw" : "en";
    
    AppState().languageNotifier.value = newLang;
    
    // Announce the switch
    String msg = newLang == 'sw' ? "Kiswahili." : "English.";
    await _narration.speakRaw(msg, newLang);
    
    // Re-initialize Teacher Amina for the new language
    await _teacherAmina.initialize(newLang);
    
    // Navigate to Home Menu (separate English and Swahili homes)
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeMenuScreen()),
      );
    }
  }

  void _triggerSupervisorOverlay() {
    _hapticService.successPulse();
    // Since the whole app is wrapped in PinGateOverlay, we don't push a new one.
    // Instead, we just let the global timer handle it, or we could manually invoke it.
    // Actually, since this is a 4-finger swipe, we can use the PinGateOverlay state to trigger it.
    final pinGate = PinGateOverlay.of(context);
    if (pinGate != null) {
      pinGate.triggerSupervisorGate();
    } else {
      debugPrint("PinGateOverlay not found in context!");
    }
  }

  void _handleSingleSwipeDown() {
    // Deprecated, handled by _evaluateSequenceStep now.
  }

  List<int> _getCurrentTargetDots() {
    if (_currentLesson == null) return [];
    bool hasSequence = _currentLesson!.sequence.isNotEmpty;
    if (hasSequence) {
      if (_sequenceIndex >= _currentLesson!.sequence.length) return [];
      final step = _currentLesson!.sequence[_sequenceIndex];
      List<int> targetDots = List<int>.from(step.targetDots);
      if (step.ref != null) {
        final lang = AppState().languageNotifier.value;
        final refLesson = CurriculumDatabase.instance.getLessonById(step.ref!, lang);
        if (refLesson != null) {
          if (refLesson.dots != null && refLesson.dots!.isNotEmpty) {
            targetDots = List<int>.from(refLesson.dots!);
          } else if (refLesson.sequence.isNotEmpty) {
            targetDots = List<int>.from(refLesson.sequence.first.targetDots);
          }
        }
      }
      return targetDots;
    } else {
      return List<int>.from(_currentLesson!.dots ?? []);
    }
  }

  ExpectedAction _getCurrentExpectedAction() {
    if (_currentLesson == null) return ExpectedAction.tapBraille;
    if (_currentLesson!.sequence.isNotEmpty) {
       if (_sequenceIndex >= _currentLesson!.sequence.length) return ExpectedAction.tapBraille;
       return _currentLesson!.sequence[_sequenceIndex].expectedAction;
    }
    return (_currentLesson!.type == LessonType.instruction || _currentLesson!.type == LessonType.readiness) 
        ? ExpectedAction.swipeDown : ExpectedAction.tapBraille;
  }

  void _evaluateSequenceStep(List<int>? tappedDots, ExpectedAction action) async {
    if (_currentLesson == null) return;
    
    ExpectedAction expectedAction = _getCurrentExpectedAction();
    List<int> targetDots = _getCurrentTargetDots();
    bool hasSequence = _currentLesson!.sequence.isNotEmpty;
    
    targetDots.sort();
    if (tappedDots != null) tappedDots.sort();
    
    bool isCorrect = false;
    
    if (action != expectedAction) {
      if (action == ExpectedAction.swipeDown) {
        // Global Gesture: Swipe Down = Continue / Skip. Skip the current step if they are stuck.
        final lang = AppState().languageNotifier.value;
        String skipText = lang.startsWith('sw') ? "Tutaruka hii." : "Let's skip this one.";
        _ttsService.stop();
        _ttsService.speak(skipText, language: lang.startsWith('sw') ? 'sw-KE' : 'en-US');
        
        _sequenceIndex++;
        int totalSteps = hasSequence ? _currentLesson!.sequence.length : 1;
        if (_sequenceIndex >= totalSteps) {
          _finishLesson(false); 
        } else {
          String msg = "";
          final nextStep = _currentLesson!.sequence[_sequenceIndex];
          if (nextStep.expectedAction == ExpectedAction.swipeRight) {
            msg = lang.startsWith('sw') ? "Sasa telezesha kulia kwa nafasi." : "Now swipe right for space.";
          } else {
            String? charToType = nextStep.character;
            if (charToType == null && nextStep.ref != null) {
              final refLesson = CurriculumDatabase.instance.getLessonById(nextStep.ref!, lang);
              charToType = refLesson?.narration?.character ?? refLesson?.narration?.spokenForm ?? refLesson?.target;
            }
            if (charToType != null) {
              msg = lang.startsWith('sw') ? "Sasa andika $charToType." : "Now type $charToType.";
            }
          }
          _narration.stop();
          _narration.speakRaw(msg, lang);
        }
        return;
      }
      _provideHint(errorType: 'wrong_action');
      return;
    }
    
    debugPrint('[NuruTouch] _evaluateSequenceStep: Evaluating tapBraille. targetDots=$targetDots, tappedDots=$tappedDots');
    
    String errorType = 'generic';

    if (action == ExpectedAction.tapBraille) {
      if (tappedDots != null && _listEquals(tappedDots, targetDots)) {
        isCorrect = true;
      } else if (tappedDots != null) {
        if (_tapCountBeforeSwipe > 1 && _currentChord.length > targetDots.length) {
          errorType = 'timing_merge';
        } else if (_isReversal(tappedDots, targetDots)) {
          errorType = 'reversal';
        } else if (_isDroppedDot(tappedDots, targetDots)) {
          errorType = 'dropped_dot';
        } else if (_hasExtraDots(tappedDots, targetDots)) {
          errorType = 'extra_dots';
        }
      }
    } else {
      isCorrect = true;
    }
    
    debugPrint('[NuruTouch] _evaluateSequenceStep: Result isCorrect=$isCorrect, errorType=$errorType');
    
    if (isCorrect) {
      _consecutiveMistakes = 0; 
      if (tappedDots != null) {
        _flashDots(tappedDots, Colors.green);
      }
      _hapticService.successPulse();
      
      // Log correct attempt
      if (_currentLesson != null) {
        await DatabaseHelper.instance.logAttemptEvent(
          studentId: AppState().currentStudentId ?? 1,
          language: AppState().languageNotifier.value,
          lessonId: _currentLesson!.id,
          inputPattern: tappedDots?.join(',') ?? '',
          targetPattern: targetDots.join(','),
          errorType: 'correct',
          hintLevelReached: _consecutiveMistakes,
        );
        // Save session state
        await DatabaseHelper.instance.saveSessionState(
          AppState().currentStudentId ?? 1,
          AppState().languageNotifier.value,
          _currentLesson!.id,
          _currentLesson!.type.name,
          _sequenceIndex,
        );
      }
      
      _sequenceIndex++;
      
      int totalSteps = hasSequence ? _currentLesson!.sequence.length : 1;
      
      if (_sequenceIndex >= totalSteps) {
        await _finishLesson(true);
      } else {
        final lang = AppState().languageNotifier.value;
        String msg = "";
        if (hasSequence) {
           AudioService().playDing(_sequenceIndex - 1); // 0-based for the step just passed
           final nextStep = _currentLesson!.sequence[_sequenceIndex];
           if (nextStep.expectedAction == ExpectedAction.swipeRight) {
             msg = lang.startsWith('sw') ? "Sasa telezesha kulia kwa nafasi." : "Now swipe right for space.";
           } else {
             String? charToType = nextStep.character;
             if (charToType == null && nextStep.ref != null) {
               final refLesson = CurriculumDatabase.instance.getLessonById(nextStep.ref!, lang);
               charToType = refLesson?.narration?.character ?? refLesson?.narration?.spokenForm ?? refLesson?.target;
             }
             if (charToType != null) {
               msg = lang.startsWith('sw') ? "Sasa andika $charToType." : "Now type $charToType.";
             }
           }
        } else {
           msg = lang.startsWith('sw') ? "Vizuri." : "Good.";
        }
        _narration.stop();
        if (msg.isNotEmpty) {
           _narration.speakRaw(msg, lang);
        }
      }
    } else {
      _mistakes++;
      _hints++;
      _consecutiveMistakes++;
      
      // Log incorrect attempt
      if (_currentLesson != null) {
        await DatabaseHelper.instance.logAttemptEvent(
          studentId: AppState().currentStudentId ?? 1,
          language: AppState().languageNotifier.value,
          lessonId: _currentLesson!.id,
          inputPattern: tappedDots?.join(',') ?? '',
          targetPattern: targetDots.join(','),
          errorType: errorType,
          hintLevelReached: _consecutiveMistakes,
        );
      }
      
      if (tappedDots != null) {
        _flashDots(tappedDots, Colors.red);
      }
      _provideHint(errorType: errorType);
    }
  }

  void _provideHint({String errorType = 'generic'}) async {
    _narration.stop();
    if (_currentChord.isNotEmpty) {
      _flashDots(_currentChord.toList(), Colors.red);
    }

    _hapticService.errorBuzz();
    final lang = AppState().languageNotifier.value;
    
    _learnerContext = _learnerContext.copyWith(
      attemptNumber: _learnerContext.attemptNumber + 1,
      retryCount: _learnerContext.retryCount + 1,
    );

    if (errorType == 'wrong_action') {
       final wrongText = lang.startsWith('sw') ? "Tafadhali fuata maelekezo." : "Please follow the instructions.";
       await _narration.speakRaw(wrongText, lang);
       if (_conversation != null && _conversation!.retry.isNotEmpty) {
         await _narration.playQueue(_conversation!.retry, lang);
       } else {
         _playLessonIntro();
       }
       return;
    }
    
    // 5-Stage Prompting Hierarchy
    NarrationSchema? narration = _currentLesson?.narration;
    
    // Resolve narration from the currently referenced letter if this is a word sequence
    if (_currentLesson != null && _currentLesson!.sequence.isNotEmpty && _sequenceIndex < _currentLesson!.sequence.length) {
      final step = _currentLesson!.sequence[_sequenceIndex];
      if (step.ref != null) {
        final refLesson = CurriculumDatabase.instance.getLessonById(step.ref!, lang);
        if (refLesson?.narration != null) {
          narration = refLesson!.narration;
        }
      }
    }

    String? retryText;
    if (narration != null && narration.steps.isNotEmpty) {
      try {
        retryText = narration.steps.firstWhere((s) => s.type == 'retry').text;
      } catch (_) {}
    }

    if (_consecutiveMistakes == 1) {
       // Stage 1 Error: Verbal re-cue only
       if (retryText != null) {
         await _narration.speakRaw(retryText, lang);
       } else if (_conversation != null && _conversation!.retry.isNotEmpty) {
         await _narration.playQueue(_conversation!.retry, lang);
       }
       return;
    } 
    else if (_consecutiveMistakes == 2) {
       // Stage 2 Error: Specific dot hint / Classification hint
       String specificHint = lang.startsWith('sw') ? "Jaribu tena." : "Try again.";
       
       if (errorType == 'reversal') {
         specificHint = lang.startsWith('sw') 
            ? "Umeandika kinyume. Kumbuka, D, F, H na J ziko kwenye pembe za mraba."
            : "That's backwards. Remember, D, F, H, and J sit at the corners of a box.";
       } else if (errorType == 'dropped_dot') {
         specificHint = lang.startsWith('sw')
            ? "Umesahau doti ya chini. Hakikisha kidole chako kimeshika seli nzima."
            : "You dropped a bottom dot. Make sure your finger presses the whole cell.";
       } else if (errorType == 'extra_dots') {
         specificHint = lang.startsWith('sw')
            ? "Umeongeza doti ya ziada. Jaribu tena."
            : "You added an extra dot. Try again.";
       } else {
         // Generic Stage 2: Name the exact dots needed
         if (_currentLesson != null) {
            List<int> tDots = _getCurrentTargetDots();
            if (tDots.isNotEmpty) {
               specificHint = lang.startsWith('sw') 
                 ? "Unahitaji doti ${tDots.join(' na ')}."
                 : "You need dots ${tDots.join(', ')}.";
            } else if (retryText != null) {
               specificHint = retryText;
            }
         }
       }
       
       List<NarrationStep> hintSteps = [
          NarrationStep(type: StepType.retry, text: specificHint, repeatable: true, condition: PlayCondition.always)
       ];
       await _narration.playQueue(hintSteps, lang, appendReminder: true);
       return;
    }
    else if (_consecutiveMistakes == 3) {
       // Stage 3 Error: Full model + Guided Repeat
       
       String guidedHint = lang.startsWith('sw')
           ? "Hebu nikuonyeshe. Sikiliza na ufuate."
           : "Let me show you. Listen and follow.";
       
       List<int> tDots = [];
       if (_currentLesson != null) {
         tDots = _getCurrentTargetDots();
       }
       
       if (tDots.isNotEmpty) {
         _flashDots(tDots, Colors.blue); // Flash blue for guided model
       }
       
       List<NarrationStep> hintSteps = [
          NarrationStep(type: StepType.retry, text: guidedHint, repeatable: true, condition: PlayCondition.always)
       ];
       await _narration.playQueue(hintSteps, lang, appendReminder: true);
       return;
    }
    else {
       // Stage 4 Error: Needs review and move on
       String moveOn = lang.startsWith('sw')
           ? "Tutajifunza hii tena baadaye. Tuendelee."
           : "We will review this later. Let's move on.";
       
       await _narration.speakRaw(moveOn, lang);
       // Skip this item
       _sequenceIndex++;
       int totalSteps = _currentLesson != null && _currentLesson!.sequence.isNotEmpty ? _currentLesson!.sequence.length : 1;
       if (_sequenceIndex >= totalSteps) {
         await _finishLesson(false); // Finished but didn't master
       } else {
         _consecutiveMistakes = 0; // reset for next item in sequence
       }
       return;
    }
  }

  Future<void> _finishLesson(bool passed) async {
    _narration.stop();
    _flashDots(_currentChord.toList(), passed ? Colors.green : Colors.red);

    if (passed) {
      AudioService().playSuccessChord();
    } else {
      _hapticService.errorBuzz();
    }
    
    final lang = AppState().languageNotifier.value;
    
    // Update context
    _learnerContext = _learnerContext.copyWith(
      justMastered: passed,
    );
    
    if (_conversation != null) {
      List<NarrationStep> endQueue = [];
      
      if (passed) {
         endQueue.addAll(_conversation!.success);
         endQueue.addAll(_conversation!.encouragement);
         int masteredToday = await DatabaseHelper.instance.getTodayMasteredCount(AppState().currentStudentId ?? 1, lang);
         if (masteredToday > 0 && masteredToday % 5 == 0) {
            String chimeMsg = lang.startsWith('sw') 
               ? "<haptic_tick> Hongera! Umejifunza masomo $masteredToday mapya leo!"
               : "<haptic_tick> Congratulations! You have mastered $masteredToday new lessons today!";
            endQueue.add(NarrationStep(type: StepType.success, text: chimeMsg, repeatable: false, condition: PlayCondition.successOnly));
         }
      }
      endQueue.addAll(_conversation!.completion);
      
      await _narration.playQueue(endQueue, lang);
    }

    final durationSeconds = (DateTime.now().millisecondsSinceEpoch - _startTime) ~/ 1000;
    
    // Quality Score for SM-2
    // If passed without mistakes -> 5. Passed with 1 mistake (recue) -> 4
    // Passed with 2 mistakes (hint) -> 3. Passed with full model -> 2. Failed -> 1.
    double quality = passed ? (5.0 - _mistakes.clamp(0, 3)) : 1.0;
    
    final result = LessonResult(
      accuracy: quality / 5.0, // Used by adaptive engine as proxy for EF
      attempts: _mistakes + 1,
      hintsUsed: _hints,
      responseTime: durationSeconds,
      mastered: passed,
    );
    
    await AdaptiveLearningEngine.instance.processLessonResult(
      AppState().currentStudentId ?? 1, 
      _currentLesson!.id, 
      lang, 
      result,
      typeFilter: widget.lessonFilter
    );
    
    await DatabaseHelper.instance.deleteSessionState(AppState().currentStudentId ?? 1, lang);
    
    _loadNextLesson();
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Map<int, Offset> _getDefaultDots(Size size) {
    double cx = size.width / 2;
    double cy = size.height / 2;
    double dx = size.width * 0.15;
    double dy = size.height * 0.2;
    
    return {
      1: Offset(cx - dx, cy - dy),
      2: Offset(cx - dx, cy),
      3: Offset(cx - dx, cy + dy),
      4: Offset(cx + dx, cy - dy),
      5: Offset(cx + dx, cy),
      6: Offset(cx + dx, cy + dy),
    };
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dots = (AppState().calibratedDots != null && AppState().calibratedDots!.length == 6) 
        ? AppState().calibratedDots! 
        : _getDefaultDots(size);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Visual Canvas Overlay
          CustomPaint(
            size: Size.infinite,
            painter: BrailleCanvasPainter(
              dots: dots,
              dotColors: _dotColors,
              activePointers: _activePointers.values.toList(),
              swipeStart: _swipeStart,
              swipeEnd: _swipeEnd,
            ),
          ),
          
          // Braille Touch Interaction Layer
          Listener(
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerUp,
            onPointerCancel: (e) => _handlePointerUp(PointerUpEvent(pointer: e.pointer, position: e.position)),
            behavior: HitTestBehavior.translucent,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: _isLoading 
                    ? const CircularProgressIndicator()
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BrailleCanvasPainter extends CustomPainter {
  final Map<int, Offset> dots;
  final Map<int, Color> dotColors;
  final List<Offset> activePointers;
  final Offset? swipeStart;
  final Offset? swipeEnd;

  BrailleCanvasPainter({
    required this.dots,
    required this.dotColors,
    required this.activePointers,
    this.swipeStart,
    this.swipeEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // 1. Draw Braille Dots
    dots.forEach((id, offset) {
      paint.color = dotColors[id] ?? Colors.blue.withOpacity(0.3);
      canvas.drawCircle(offset, 40, paint);
      
      // Draw inner core
      paint.color = dotColors[id] ?? Colors.blue;
      canvas.drawCircle(offset, 15, paint);
    });

    // 2. Draw Active Touches
    paint.color = Colors.black.withOpacity(0.2);
    for (var pos in activePointers) {
      canvas.drawCircle(pos, 50, paint);
    }

    // 3. Draw Swipe Gesture Trail
    if (swipeStart != null && swipeEnd != null) {
      final linePaint = Paint()
        ..color = Colors.green.withOpacity(0.5)
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(swipeStart!, swipeEnd!, linePaint);
      
      // Draw arrowhead
      canvas.drawCircle(swipeEnd!, 30, Paint()..color = Colors.green);
    }
  }

  @override
  bool shouldRepaint(covariant BrailleCanvasPainter oldDelegate) => true;
}
