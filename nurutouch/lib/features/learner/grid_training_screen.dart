import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/tts_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/colors.dart';
import '../../data/local/app_state.dart';
import 'adaptive_touch_screen.dart';
import 'home_menu_screen.dart';
import '../../config/app_strings.dart';

class GridTrainingScreen extends StatefulWidget {
  const GridTrainingScreen({super.key});

  @override
  State<GridTrainingScreen> createState() => _GridTrainingScreenState();
}

class _GridTrainingScreenState extends State<GridTrainingScreen> {
  final TtsService _ttsService = TtsService();
  final HapticService _hapticService = HapticService();
  
  int _currentStep = 0; // Starts with Intro

  @override
  void initState() {
    super.initState();
    _playInstructions();
  }

  void _playInstructions() async {
    String lang = AppState().languageNotifier.value;
    String langCode = lang == "sw" ? "sw-KE" : "en-US";
    
    if (_currentStep == 0) {
      await _ttsService.speak(AppStrings.getGridIntro(langCode), language: langCode);
    } else if (_currentStep <= 6) {
      await _ttsService.speak(AppStrings.getGridTrainingStep(langCode, _currentStep), language: langCode, appendReminder: true);
    } else if (_currentStep == 7) {
      _hapticService.successPulse();
      await _ttsService.speak(AppStrings.getNavigationReminder(langCode), language: langCode);
      await _ttsService.speak(AppStrings.getGridTrainingComplete(langCode), language: langCode, appendReminder: true);
    }
  }

  void _handleVerticalDrag(DragEndDetails details) async {
    if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
      // Swipe down
      if (_currentStep == 0) {
        setState(() => _currentStep = 1);
        _playInstructions();
      } else if (_currentStep == 7) {
        await _ttsService.stop();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeMenuScreen()),
          );
        }
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) async {
    if (_currentStep == 0 || _currentStep == 7) return;

    int tappedDot = _identifyDotZone(event.position);
    if (tappedDot == _currentStep) {
      _hapticService.successPulse();
      setState(() => _currentStep++);
      _playInstructions();
    } else if (tappedDot != -1) {
      _hapticService.errorBuzz();
      String lang = AppState().languageNotifier.value;
      String langCode = lang == "sw" ? "sw-KE" : "en-US";
      await _ttsService.speak(AppStrings.getWrongSingleDot(lang, tappedDot), language: langCode);
      _playInstructions();
    }
  }

  int _identifyDotZone(Offset tapPosition) {
    int closestDot = -1;
    double minDistance = double.infinity;
    // Read from the global vault
    AppState().calibratedDots.forEach((dotNumber, calibratedPosition) {
      double distance = sqrt(pow(tapPosition.dx - calibratedPosition.dx, 2) + pow(tapPosition.dy - calibratedPosition.dy, 2));
      if (distance < minDistance) {
        minDistance = distance;
        closestDot = dotNumber;
      }
    });
    return (minDistance < 200) ? closestDot : -1;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dots = AppState().calibratedDots;
    
    // Highlight the dot corresponding to the current step (1-6)
    Map<int, Color> dotColors = {};
    if (_currentStep >= 1 && _currentStep <= 6) {
      dotColors[_currentStep] = NuruColors.amber;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: BrailleCanvasPainter(
              dots: dots,
              dotColors: dotColors,
              activePointers: const [],
            ),
          ),
          SafeArea(
            child: GestureDetector(
              onVerticalDragEnd: _handleVerticalDrag,
              behavior: HitTestBehavior.opaque,
              child: Listener(
                onPointerUp: _handlePointerUp,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
