import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../services/tts_service.dart';
import '../../services/haptic_service.dart';
import '../../services/audio_service.dart';
import '../../data/local/app_state.dart';
import '../../services/curriculum_engine.dart';
import '../../config/app_strings.dart';

class RawTouchScreen extends StatefulWidget {
  const RawTouchScreen({super.key});


  @override
  State<RawTouchScreen> createState() => _RawTouchScreenState();
}

class _RawTouchScreenState extends State<RawTouchScreen> {
  final TtsService _ttsService = TtsService();
  final HapticService _hapticService = HapticService();
  final AudioService _audioService = AudioService();
  
  final Map<int, Offset> _activePointers = {};
  final Map<int, Offset> _startPositions = {};
  int _maxPointersInCurrentStrike = 0;
  
  Map<int, Offset> _calibratedDots = {};
  bool _isCalibrated = false;

  final Set<int> _currentChord = {};
  final CurriculumEngine _engine = CurriculumEngine();
  String _currentLessonId = "";
  int _currentLessonMistakes = 0;
  int _currentLessonStartTimeMs = 0;

  int _currentWordCharIndex = 0; // Tracks progress inside a word like "ABBA"
  bool _isCurrentLessonPassed = false;
  
  Map<String, dynamic> _fullCurriculum = {};
  List<dynamic> _curriculum = [];
  bool _isLoading = true;
  String _lastKnownLang = "en";

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    if (AppState().isCalibrated) {
      _calibratedDots = AppState().calibratedDots;
      _isCalibrated = true;
    }
    
    _loadCurriculum();
    AppState().languageNotifier.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    AppState().languageNotifier.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() async {
    String currentLang = AppState().languageNotifier.value;
    if (_fullCurriculum.isNotEmpty && currentLang != _lastKnownLang) {
      setState(() {
        _lastKnownLang = currentLang;
        _curriculum = _fullCurriculum[currentLang] ?? [];
        _isCurrentLessonPassed = false;
        _currentWordCharIndex = 0;
        _currentLessonMistakes = 0;
      });
      await _engine.init(_curriculum, AppState().currentStudentId!);
      setState(() {
        _currentLessonId = _engine.getNextOptimalLesson();
        _currentLessonStartTimeMs = DateTime.now().millisecondsSinceEpoch;
      });
      if (_isCalibrated) {
        _playNextPrompt();
      }
    }
  }

  Future<void> _loadCurriculum() async {
    final String response = await rootBundle.loadString('assets/curriculum/lessons.json');
    final data = await json.decode(response);
    
    setState(() {
      _fullCurriculum = data;
      _lastKnownLang = AppState().languageNotifier.value;
      _curriculum = _fullCurriculum[_lastKnownLang] ?? [];
      _isLoading = false;
    });

    await _engine.init(_curriculum, AppState().currentStudentId!);
    setState(() {
      _currentLessonId = _engine.getNextOptimalLesson();
      _currentLessonStartTimeMs = DateTime.now().millisecondsSinceEpoch;
    });

    if (!_isCalibrated) {
      _ttsService.speak("Rest your six fingers on the screen to calibrate.", language: "en-US");
    } else {
      _playNextPrompt();
    }
  }

  Map<String, dynamic> _getCurrentLesson() {
    if (_currentLessonId.isEmpty) return _curriculum.first;
    return _curriculum.firstWhere((l) => l['id'] == _currentLessonId, orElse: () => _curriculum.first);
  }

  void _handlePointerDown(PointerDownEvent event) {
    setState(() {
      _activePointers[event.pointer] = event.position;
      _startPositions[event.pointer] = event.position;
      
      if (_activePointers.length > _maxPointersInCurrentStrike) {
        _maxPointersInCurrentStrike = _activePointers.length;
      }

      if (_isCalibrated && _activePointers.length <= 6) {
        int dot = _identifyDotZone(event.position);
        if (dot != -1) {
          _currentChord.add(dot);
          _hapticService.tick(); 
        }
      }
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activePointers.containsKey(event.pointer)) {
      _activePointers[event.pointer] = event.position;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    Offset startPos = _startPositions[event.pointer] ?? event.position;
    Offset endPos = event.position;
    
    setState(() {
      _activePointers.remove(event.pointer);
    });

    if (_activePointers.isEmpty) {
      _analyzeGestureAndExecute(startPos, endPos);
      _maxPointersInCurrentStrike = 0;
      _startPositions.clear();
      _currentChord.clear();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    setState(() {
      _activePointers.remove(event.pointer);
      if (_activePointers.isEmpty) {
        _maxPointersInCurrentStrike = 0;
        _startPositions.clear();
        _currentChord.clear();
      }
    });
  }

  // --- THE GESTURE BRAIN ---
  void _analyzeGestureAndExecute(Offset lastStartPos, Offset lastEndPos) async {
    double dy = lastEndPos.dy - lastStartPos.dy; 
    double dx = lastEndPos.dx - lastStartPos.dx; 
    bool isVerticalSwipe = dy.abs() > 50.0;
    bool isHorizontalSwipe = dx.abs() > 50.0;

    if (isVerticalSwipe || isHorizontalSwipe) {
      _currentChord.clear(); 
      String lang = AppState().languageNotifier.value;
      String langCode = lang == "sw" ? "sw-KE" : "en-US";

      if (_maxPointersInCurrentStrike == 1 && dy > 0) {
        // 1-FINGER SWIPE DOWN: Continue
        _hapticService.tick();
        var lesson = _getCurrentLesson();
        var type = lesson['type'];
        if (_isCalibrated && (type == 'practice' || type == 'word') && !_isCurrentLessonPassed) {
          _hapticService.errorBuzz();
          _ttsService.speak(AppStrings.getRawTouchWarning(langCode), language: langCode);
        } else {
          await _ttsService.stop();
          await _ttsService.speak(AppStrings.getContinuing(langCode), language: langCode, isFeedback: true);
          _skipToNext();
        }
      } else if (_maxPointersInCurrentStrike == 2 && dy > 0) {
        // 2-FINGER SWIPE DOWN: Go Back
        _hapticService.tick();
        _executeTrueStackGoBack();
      } else if (_maxPointersInCurrentStrike == 2 && dx > 0) {
        // 2-FINGER SWIPE RIGHT: Hint
        _giveHint();
      }
      return; 
    }

    // TAPS & CHORDS
    if (!_isCalibrated && _maxPointersInCurrentStrike == 6) {
      _calibrateFingers();
    } else if (_isCalibrated && _currentChord.isNotEmpty) {
      var lesson = _getCurrentLesson();
      if (lesson['type'] != 'instruction') {
        _evaluateChord();
      }
    }
  }

  void _giveHint() {
    _hapticService.tick();
    var lesson = _getCurrentLesson();
    String lang = AppState().languageNotifier.value;
    String langCode = lang == "sw" ? "sw-KE" : "en-US";
    
    if (lesson['type'] == 'practice') {
      _ttsService.speak(lesson['hint'], language: langCode, appendReminder: true);
    } else if (lesson['type'] == 'word') {
      _ttsService.speak(lesson['hint'], language: langCode, appendReminder: true);
    }
  }

  void _skipToNext() async {
    int timeMs = DateTime.now().millisecondsSinceEpoch - _currentLessonStartTimeMs;
    await _engine.updateProgress(_currentLessonId, _currentLessonMistakes, timeMs);

    setState(() {
      _isCurrentLessonPassed = false;
      _currentWordCharIndex = 0;
      _currentLessonMistakes = 0;
      _currentLessonId = _engine.getNextOptimalLesson();
      _currentLessonStartTimeMs = DateTime.now().millisecondsSinceEpoch;
    });

    if (_currentLessonId.isEmpty) {
      String langCode = AppState().languageNotifier.value == "sw" ? "sw-KE" : "en-US";
      _ttsService.speak(AppStrings.getEndOfLessons(langCode), language: langCode);
    } else {
      _playNextPrompt();
    }
  }

  Future<void> _executeTrueStackGoBack() async {
    await _ttsService.stop();
    await Future.delayed(const Duration(milliseconds: 150)); 

    if (mounted) {
      setState(() {
        _isCurrentLessonPassed = false;
        _currentWordCharIndex = 0;
        _currentChord.clear();
      });

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  void _playNextPrompt() {
    String lang = AppState().languageNotifier.value;
    String langCode = lang == "sw" ? "sw-KE" : "en-US";
    var lesson = _getCurrentLesson();
    _ttsService.speak(lesson['intro'], language: langCode, appendReminder: true);
  }

  void _calibrateFingers() {
    List<Offset> points = _startPositions.values.toList();
    points.sort((a, b) => a.dx.compareTo(b.dx));
    
    List<Offset> leftHand = points.sublist(0, 3);
    List<Offset> rightHand = points.sublist(3, 6);

    leftHand.sort((a, b) => a.dy.compareTo(b.dy));
    rightHand.sort((a, b) => a.dy.compareTo(b.dy));

    _calibratedDots = {
      1: leftHand[0], 2: leftHand[1], 3: leftHand[2],
      4: rightHand[0], 5: rightHand[1], 6: rightHand[2],
    };

    AppState().saveCalibration(_calibratedDots);

    setState(() => _isCalibrated = true);
    _hapticService.successPulse();
    _playNextPrompt(); 
  }

  int _identifyDotZone(Offset tapPosition) {
    int closestDot = -1;
    double minDistance = double.infinity;
    _calibratedDots.forEach((dotNumber, calibratedPosition) {
      double distance = sqrt(pow(tapPosition.dx - calibratedPosition.dx, 2) + pow(tapPosition.dy - calibratedPosition.dy, 2));
      if (distance < minDistance) {
        minDistance = distance;
        closestDot = dotNumber;
      }
    });
    return (minDistance < 200) ? closestDot : -1; 
  }

  void _evaluateChord() {
    var lesson = _getCurrentLesson();
    String lang = AppState().languageNotifier.value;
    String langCode = lang == "sw" ? "sw-KE" : "en-US";
    
    List<int> targetDots;
    String targetName;

    if (lesson['type'] == 'practice') {
      targetDots = List<int>.from(lesson['dots']);
      targetName = lesson['target_letter'];
    } else {
      // It's a word! Look at the current letter in the sequence.
      var seq = lesson['sequence'][_currentWordCharIndex];
      targetDots = List<int>.from(seq['dots']);
      targetName = seq['letter'];
    }

    List<int> struckDots = _currentChord.toList()..sort();
    
    if (listEquals(struckDots, targetDots)) {
      _hapticService.successPulse();
      
      if (lesson['type'] == 'practice') {
        setState(() => _isCurrentLessonPassed = true);
        
        _audioService.playSuccessChime();
        _ttsService.speak(lesson['success'], language: langCode);
      } else if (lesson['type'] == 'word') {
        setState(() => _currentWordCharIndex++);
        
        if (_currentWordCharIndex >= lesson['sequence'].length) {
          setState(() => _isCurrentLessonPassed = true);
          
          _audioService.playSuccessChime();
          _ttsService.speak(lesson['success'], language: langCode);
        } else {
          String nextLetter = lesson['sequence'][_currentWordCharIndex]['letter'];
          _ttsService.speak(AppStrings.getCorrectNextLetter(langCode, nextLetter), language: langCode);
        }
      }
    } else {
      _currentLessonMistakes++;
      _hapticService.errorBuzz();
      _audioService.playErrorThud();
      
      String feedback = "";
      if (struckDots.length == 1) {
        feedback = AppStrings.getWrongSingleDot(langCode, struckDots.first);
      } else {
        feedback = AppStrings.getWrongMultipleDots(langCode);
      }
      _ttsService.speak(feedback, language: langCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: Color(0xFF050505));

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Listener(
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: _handlePointerCancel,
          behavior: HitTestBehavior.opaque,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
