import 'dart:async';
import 'package:flutter/material.dart';
import 'adaptive_touch_screen.dart';

import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../services/haptic_service.dart';
import '../../services/tts_service.dart';
import '../../theme/colors.dart';
import '../../data/local/app_state.dart';
import 'calibration_screen.dart';
import '../../config/app_strings.dart';

class OrientationScreen extends StatefulWidget {
  const OrientationScreen({super.key});

  @override
  State<OrientationScreen> createState() => _OrientationScreenState();
}

class _OrientationScreenState extends State<OrientationScreen> {
  final TtsService _ttsService = TtsService();
  final HapticService _hapticService = HapticService();
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  Timer? _successTimer;
  bool _isTransitioning = false;
  bool _isIntroFinished = false;
  DateTime _lastNagTime = DateTime.now().subtract(const Duration(seconds: 5));

  @override
  void initState() {
    super.initState();
    // Programmatic Orientation Lock at the OS Level
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _startListening();
  }

  void _startListening() async {
    // Initial Audio-Guided Calibration Cue
    await _playOrientationText();
    if (!mounted) return;
    _isIntroFinished = true;

    _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      if (_isTransitioning || !_isIntroFinished) return;

      // REAL-TIME HARDWARE VERIFICATION
      // Y-axis tracks upright tilt. 
      // Tolerance of 5.0 allows them to hold it at a slight comfortable angle in their hands.
      // If Y > 5.0, they are holding it upright in portrait mode.
      bool isSidewaysOrFlat = event.y.abs() < 5.0;

      if (isSidewaysOrFlat) {
        // If correct, start a 2-second lock-in timer to ensure they are steady
        if (_successTimer == null || !_successTimer!.isActive) {
          _successTimer = Timer(const Duration(seconds: 2), _proceedToCanvas);
        }
      } else {
        // If they tilt it back upright, cancel the success timer
        _successTimer?.cancel();
        
        // CONTINUOUS GUIDANCE: Nag every 5 seconds if held incorrectly
        // ONLY if the intro text is not currently playing!
        if (!_ttsService.isSpeaking && DateTime.now().difference(_lastNagTime).inSeconds >= 5) {
          _hapticService.errorBuzz();
          _playNagText();
          _lastNagTime = DateTime.now();
        }
      }
    });
  }

  void _proceedToCanvas() async {
    if (_isTransitioning) return;
    _isTransitioning = true;
    _successTimer?.cancel();
    _accelerometerSubscription?.cancel();

    _hapticService.successPulse();
    String lang = AppState().languageNotifier.value;
    String langCode = lang == "en" ? "en-US" : "sw-KE";
    await _ttsService.speak(AppStrings.getOrientationGoodPosture(langCode), language: langCode);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const CalibrationScreen()),
    );
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _successTimer?.cancel();
    super.dispose();
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
              activePointers: const [],
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.screen_rotation, size: 80, color: Colors.blue),
                const SizedBox(height: 24),
                Text(
                  "Rotate device to Landscape",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _playOrientationText() async {
    String lang = AppState().languageNotifier.value;
    String langCode = lang == "en" ? "en-US" : "sw-KE";
    await _ttsService.speak(AppStrings.getOrientationHoldFlat(langCode), language: langCode, appendReminder: true);
  }

  Future<void> _playNagText() async {
    String lang = AppState().languageNotifier.value;
    String langCode = lang == "en" ? "en-US" : "sw-KE";
    await _ttsService.speak(AppStrings.getOrientationUpright(langCode), language: langCode, appendReminder: true);
  }
}

