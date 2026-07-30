import 'package:flutter/material.dart';
import 'adaptive_touch_screen.dart';

import '../../services/tts_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/colors.dart';
import '../../data/local/app_state.dart';
import 'grid_training_screen.dart';
import '../../config/app_strings.dart';
import '../../data/local/database_helper.dart' as import_database_helper;
import '../../core/adaptive_learning/adaptive_learning_engine.dart' as import_adaptive_engine;
import 'home_menu_screen.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  final TtsService _ttsService = TtsService(); 
  final HapticService _hapticService = HapticService();
  final Map<int, Offset> _activePointers = {};

  @override
  void initState() {
    super.initState();
    _playInstructions();
  }

  void _playInstructions() async {
    String lang = AppState().languageNotifier.value;
    String langCode = lang == "en" ? "en-US" : "sw-KE";
    await _ttsService.speak(AppStrings.getCalibrationInstructions(langCode), language: langCode, appendReminder: lang == "sw");
  }

  void _handlePointerDown(PointerDownEvent event) {
    setState(() {
      _activePointers[event.pointer] = event.position;
      if (_activePointers.length == 6) _calibrateAndProceed();
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    setState(() => _activePointers.remove(event.pointer));
  }

  void _calibrateAndProceed() async {
    List<Offset> points = _activePointers.values.toList();
    points.sort((a, b) => a.dx.compareTo(b.dx));
    
    List<Offset> leftHand = points.sublist(0, 3);
    List<Offset> rightHand = points.sublist(3, 6);

    leftHand.sort((a, b) => a.dy.compareTo(b.dy));
    rightHand.sort((a, b) => a.dy.compareTo(b.dy));

    Map<int, Offset> dots = {
      1: leftHand[0], 2: leftHand[1], 3: leftHand[2],
      4: rightHand[0], 5: rightHand[1], 6: rightHand[2],
    };

    // 1. Save to Global Vault
    AppState().saveCalibration(dots);
    _hapticService.successPulse();
    await _ttsService.stop(); 
    
    // 2. Determine progress context
    int studentId = AppState().currentStudentId ?? 1;
    String langCode = AppState().languageNotifier.value == "en" ? "en-US" : "sw-KE";
    
    // Lazy imports for logic
    final dbHelper = import_database_helper.DatabaseHelper.instance;
    final progress = await dbHelper.getStudentProgress(studentId);
    
    final engine = import_adaptive_engine.AdaptiveLearningEngine.instance;
    final nextLesson = await engine.getNextLesson(studentId, langCode);
    
    if (progress.isNotEmpty && nextLesson != null) {
      // Find the most recently completed lesson (just get the last one in progress list for simplicity, or just use nextLesson)
      // Since progress is ordered by insertion, the last one is usually the most recent.
      String lastLessonId = progress.last['lesson_id'] as String;
      String spokenLast = lastLessonId.replaceAll('_', ' ');
      String spokenNext = nextLesson.id.replaceAll('_', ' ');
      
      String text = langCode == "en-US" 
          ? "You learned $spokenLast last time. This is what you're supposed to learn this time: $spokenNext. Let's proceed."
          : "Ulijifunza $spokenLast mara ya mwisho. Hiki ndicho unachopaswa kujifunza wakati huu: $spokenNext. Tuendelee.";
          
      await _ttsService.speak(text, language: langCode);
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdaptiveTouchScreen()),
        );
      }
    } else if (progress.isNotEmpty && nextLesson == null) {
      String text = langCode == "en-US" 
          ? "You have completed all available lessons! Let's go to the home menu."
          : "Umekamilisha masomo yote! Twende kwenye menyu kuu.";
          
      await _ttsService.speak(text, language: langCode);
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeMenuScreen()),
        );
      }
    } else {
      String text = langCode == "en-US" 
          ? "Welcome to your first lesson. Let's proceed."
          : "Karibu kwenye somo lako la kwanza. Tuendelee.";
          
      await _ttsService.speak(text, language: langCode);
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const GridTrainingScreen()),
        );
      }
    }
  }

  Map<int, Offset> _getDefaultDots(Size size) {
    double cx = size.width / 2;
    double cy = size.height / 2;
    double dx = size.width * 0.15;
    double dy = size.height * 0.2;
    return {
      1: Offset(cx - dx, cy - dy), 2: Offset(cx - dx, cy), 3: Offset(cx - dx, cy + dy),
      4: Offset(cx + dx, cy - dy), 5: Offset(cx + dx, cy), 6: Offset(cx + dx, cy + dy),
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
          CustomPaint(
            size: Size.infinite,
            painter: BrailleCanvasPainter(
              dots: dots,
              dotColors: const {},
              activePointers: _activePointers.values.toList(),
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
