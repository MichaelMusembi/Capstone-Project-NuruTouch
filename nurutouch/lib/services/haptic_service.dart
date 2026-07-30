import 'package:vibration/vibration.dart';

class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  int _lastTickTime = 0;

  // A tiny, crisp tick for a single dot press
  Future<void> tick() async {
    int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTickTime < 100) return; // Debounce 100ms
    _lastTickTime = now;
    
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(duration: 50, amplitude: 128); // Short & sharp
    }
  }

  int _lastSuccessTime = 0;

  // A longer, smooth pulse for a successful calibration or chord
  Future<void> successPulse() async {
    int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSuccessTime < 400) return; // Debounce 400ms
    _lastSuccessTime = now;
    
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(duration: 300, amplitude: 255);
    }
  }

  int _lastErrorTime = 0;

  // A double-buzz for an error
  Future<void> errorBuzz() async {
    int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastErrorTime < 500) return; // Debounce 500ms
    _lastErrorTime = now;
    
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(pattern: [0, 150, 100, 150]); 
    }
  }
}
