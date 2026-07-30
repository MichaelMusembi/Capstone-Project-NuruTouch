import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/tts_service.dart';
import '../../services/haptic_service.dart';
import '../../services/narration_service.dart';
import '../../theme/colors.dart';
import '../../data/local/app_state.dart';
import '../../data/local/database_helper.dart';
import '../learner/orientation_screen.dart';
import '../learner/adaptive_touch_screen.dart';
import '../../config/app_strings.dart';

class GatewayScreen extends StatefulWidget {
  const GatewayScreen({super.key});

  @override
  State<GatewayScreen> createState() => _GatewayScreenState();
}

class _GatewayScreenState extends State<GatewayScreen> {
  final TtsService _ttsService = TtsService();
  final HapticService _hapticService = HapticService();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _playWelcome();
  }

  void _playWelcome() async {
    await _ttsService.speak(AppStrings.getGatewayWelcome("sw-KE"), language: "sw-KE");
    await _ttsService.speak(AppStrings.getGatewayWelcome("en-US"), language: "en-US");
  }

  void _handleSwipe(DragEndDetails details) async {
    if (details.primaryVelocity! > 0) {
      // Swiped Right -> English
      AppState().languageNotifier.value = "en";
      _hapticService.successPulse();
      await NarrationService.instance.stop();
      await _ttsService.speak(AppStrings.getGatewaySelected("en-US"), language: "en-US");
      _launchLearnerFlow();
    } else if (details.primaryVelocity! < 0) {
      // Swiped Left -> Swahili
      AppState().languageNotifier.value = "sw";
      _hapticService.successPulse();
      await NarrationService.instance.stop();
      await _ttsService.speak(AppStrings.getGatewaySelected("sw-KE"), language: "sw-KE");
      _launchLearnerFlow();
    }
  }

  void _launchLearnerFlow() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const OrientationScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NuruColors.black,
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragEnd: _handleSwipe,
          child: Container(
            color: Colors.transparent,
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: Icon(Icons.touch_app, color: NuruColors.amber.withValues(alpha: 0.8), size: 60),
            ),
          ),
        ),
      ),
    );
  }
}
