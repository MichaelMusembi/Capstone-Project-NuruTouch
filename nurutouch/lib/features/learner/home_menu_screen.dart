import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/tts_service.dart';
import '../../services/narration_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/colors.dart';
import 'adaptive_touch_screen.dart'; 
import '../../data/local/app_state.dart';
import '../../config/app_strings.dart';
import '../../config/app_strings.dart';
import '../../core/adaptive_learning/adaptive_learning_engine.dart';
import '../../core/adaptive_learning/models/lesson.dart';

class HomeMenuScreen extends StatefulWidget {
  const HomeMenuScreen({super.key});

  @override
  State<HomeMenuScreen> createState() => _HomeMenuScreenState();
}

class _HomeMenuScreenState extends State<HomeMenuScreen> {
  final TtsService _ttsService = TtsService(); // Singleton
  final HapticService _hapticService = HapticService();

  @override
  void initState() {
    super.initState();
    _playMenuAudio();
  }

  @override
  void dispose() {
    NarrationService.instance.stop();
    super.dispose();
  }

  void _playMenuAudio() {
    String lang = AppState().languageNotifier.value;
    String langCode = lang == "en" ? "en-US" : "sw-KE";
    
    String prompt = lang == "en" 
        ? "Welcome to Home. Tap dot 1 for letters, dot 2 for words."
        : "Karibu Nyumbani. Gusa kitone cha kwanza kwa herufi, cha pili kwa maneno.";
        
    _ttsService.speak(prompt, language: langCode, appendReminder: true);
  }

  final Map<int, Offset> _startPositions = {};
  final Set<int> _activePointers = {};
  int _maxPointers = 0;

  void _handlePointerDown(PointerDownEvent event) {
    setState(() {
      _activePointers.add(event.pointer);
      _startPositions[event.pointer] = event.position;
      if (_activePointers.length > _maxPointers) {
        _maxPointers = _activePointers.length;
      }
    });
  }

  void _handlePointerUp(PointerUpEvent event) async {
    if (!_startPositions.containsKey(event.pointer)) return;
    Offset startPos = _startPositions[event.pointer] ?? event.position;
    Offset endPos = event.position;
    
    setState(() {
      _activePointers.remove(event.pointer);
    });

    double dx = endPos.dx - startPos.dx;
    double dy = endPos.dy - startPos.dy;
    bool isSwipe = dy > 80.0 && dx.abs() < dy; // Swipe Down
    
    if (isSwipe && _maxPointers >= 3) {
      _startPositions.clear();
      _maxPointers = 0;
      _activePointers.clear();
      
      _hapticService.successPulse();
      await NarrationService.instance.stop();
      await _ttsService.stop();
      
      String current = AppState().languageNotifier.value;
      String newLang = (current == "en") ? "sw" : "en";
      AppState().languageNotifier.value = newLang;
      
      String msg = newLang == 'sw' ? "Kiswahili." : "English.";
      await _ttsService.speak(msg, language: newLang == "en" ? "en-US" : "sw-KE");
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeMenuScreen()),
        );
      }
      return;
    }

    if (_activePointers.isEmpty && !isSwipe) {
      int tappedDot = _identifyDotZone(endPos);
      _maxPointers = 0;
      _startPositions.clear();
      
      String lang = AppState().languageNotifier.value;
      String langCode = lang == "en" ? "en-US" : "sw-KE";
      
      int studentId = AppState().currentStudentId ?? 1;
      
      if (tappedDot == 1) {
        _hapticService.successPulse();
        await NarrationService.instance.stop();
        await _ttsService.speak(lang == "en" ? "Curriculum started." : "Mtaala umeanza.", language: langCode);
        _launchAdaptiveTouchScreen(null);
      } else if (tappedDot == 2) {
        bool isUnlocked = await AdaptiveLearningEngine.instance.isTypeUnlocked(studentId, lang, LessonType.word);
        await NarrationService.instance.stop();
        
        if (isUnlocked) {
          _hapticService.successPulse();
          await _ttsService.speak(lang == "en" ? "Words selected." : "Maneno yamechaguliwa.", language: langCode);
          _launchAdaptiveTouchScreen(LessonType.word);
        } else {
          _hapticService.errorBuzz();
          _ttsService.speak(lang == "en" ? "Words are locked. Please complete more letters first." : "Maneno yamefungwa. Tafadhali kamilisha herufi kwanza.", language: langCode);
        }
      } else if (tappedDot == 3) {
        bool isUnlocked = await AdaptiveLearningEngine.instance.isTypeUnlocked(studentId, lang, LessonType.sentence);
        await NarrationService.instance.stop();
        
        if (isUnlocked) {
          _hapticService.successPulse();
          await _ttsService.speak(lang == "en" ? "Sentences selected." : "Sentensi zimechaguliwa.", language: langCode);
          _launchAdaptiveTouchScreen(LessonType.sentence);
        } else {
          _hapticService.errorBuzz();
          _ttsService.speak(lang == "en" ? "Sentences are locked. Please complete more words first." : "Sentensi zimefungwa. Tafadhali kamilisha maneno kwanza.", language: langCode);
        }
      } else if (tappedDot != -1) {
        _hapticService.errorBuzz();
      }
    }
  }

  void _launchAdaptiveTouchScreen(LessonType? typeFilter) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdaptiveTouchScreen(lessonFilter: typeFilter)),
    ).then((_) {
      if (mounted) {
        _playMenuAudio();
      }
    });
  }

  int _identifyDotZone(Offset tapPosition) {
    int closestDot = -1;
    double minDistance = double.infinity;
    AppState().calibratedDots.forEach((dotNumber, calibratedPosition) {
      double distance = sqrt(pow(tapPosition.dx - calibratedPosition.dx, 2) + pow(tapPosition.dy - calibratedPosition.dy, 2));
      if (distance < minDistance) {
        minDistance = distance;
        closestDot = dotNumber;
      }
    });
    return (minDistance < 200) ? closestDot : -1; 
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
    final dots = (AppState().calibratedDots != null && AppState().calibratedDots.length == 6) 
        ? AppState().calibratedDots 
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
              dotColors: const {},
              activePointers: const [],
            ),
          ),
          
          SafeArea(
            child: Listener(
              onPointerDown: _handlePointerDown,
              onPointerUp: _handlePointerUp,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}
