import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../main.dart' as import_main;
import '../../theme/colors.dart';
import '../../services/haptic_service.dart';
import '../../services/tts_service.dart';
import '../../services/narration_service.dart';
import '../../config/app_constants.dart';
import '../../config/app_strings.dart';
import '../../data/local/app_state.dart';
import 'dashboard/student_list_screen.dart';
import 'login_screen.dart';

class PinGateOverlay extends StatefulWidget {
  final Widget child;
  const PinGateOverlay({super.key, required this.child});

  static _PinGateOverlayState? of(BuildContext context) {
    return context.findAncestorStateOfType<_PinGateOverlayState>();
  }

  static void trigger(BuildContext context) {
    of(context)?.triggerSupervisorGate();
  }

  @override
  State<PinGateOverlay> createState() => _PinGateOverlayState();
}

class _PinGateOverlayState extends State<PinGateOverlay> {
  final HapticService _hapticService = HapticService();
  final TtsService _ttsService = TtsService();

  void triggerSupervisorGate() async {
    _hapticService.successPulse();
    await _ttsService.stop(); 
    await NarrationService.instance.stop();
    
    if (AppState().isSupervisorMode) {
      _ttsService.speak("Opening Supervisor Dashboard.", language: "en-US");
      _openDashboard();
    } else {
      _ttsService.speak("Supervisor access requested. Enter password.", language: "en-US");
      _openLogin();
    }
  }

  void _openLogin() async {
    try {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      await Future.delayed(const Duration(milliseconds: 300));
      if (import_main.globalNavigatorKey.currentState == null) {
        _ttsService.speak("Navigation error. Navigator is null.", language: "en-US");
        return;
      }
      import_main.globalNavigatorKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: NuruColors.bone,
            body: LoginScreen(
              onLoginSuccess: () {
                import_main.globalNavigatorKey.currentState!.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const StudentListScreen()),
                  (route) => false,
                ).then((_) {
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.portraitUp,
                    DeviceOrientation.landscapeLeft,
                    DeviceOrientation.landscapeRight,
                  ]);
                });
              },
              onCancel: () {
                import_main.globalNavigatorKey.currentState!.pop();
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.landscapeRight,
                ]);
              },
            ),
          ),
        ),
      );
    } catch (e) {
      _ttsService.speak("Failed to open login screen.", language: "en-US");
      debugPrint("Error opening login: $e");
    }
  }

  void _openDashboard() async {
    try {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      await Future.delayed(const Duration(milliseconds: 300));
      if (import_main.globalNavigatorKey.currentState == null) {
        _ttsService.speak("Navigation error. Navigator is null.", language: "en-US");
        return;
      }
      import_main.globalNavigatorKey.currentState!.pushAndRemoveUntil(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (context, animation, secondaryAnimation) => const StudentListScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: child,
              ),
            );
          },
        ),
        (route) => false,
      ).then((_) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      });
    } catch (e) {
      _ttsService.speak("Failed to open dashboard.", language: "en-US");
      debugPrint("Error opening dashboard: $e");
    }
  }

  Timer? _supervisorTimer;
  int _activePointers = 0;

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointers == 0) {
      _supervisorTimer = Timer(const Duration(seconds: 6), triggerSupervisorGate);
      
      // Haptic progress every 1 second
      Timer(const Duration(seconds: 1), () { if (_supervisorTimer?.isActive ?? false) _hapticService.tick(); });
      Timer(const Duration(seconds: 2), () { if (_supervisorTimer?.isActive ?? false) _hapticService.tick(); });
      Timer(const Duration(seconds: 3), () { if (_supervisorTimer?.isActive ?? false) _hapticService.tick(); });
      Timer(const Duration(seconds: 4), () { if (_supervisorTimer?.isActive ?? false) _hapticService.tick(); });
      Timer(const Duration(seconds: 5), () { if (_supervisorTimer?.isActive ?? false) _hapticService.tick(); });
    }
    _activePointers++;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    // Ignore movement completely. Any continuous 6-second touch triggers the dashboard.
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activePointers--;
    if (_activePointers <= 0) {
      _activePointers = 0;
      _supervisorTimer?.cancel();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers--;
    if (_activePointers <= 0) {
      _activePointers = 0;
      _supervisorTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
