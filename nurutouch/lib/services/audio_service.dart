import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;

  final AudioPlayer _successPlayer = AudioPlayer();
  final AudioPlayer _errorPlayer = AudioPlayer();
  final AudioPlayer _dingPlayer = AudioPlayer();
  final AudioPlayer _chordPlayer = AudioPlayer();

  AudioService._internal() {
    // Preload for zero latency
    _successPlayer.setSource(AssetSource('sounds/success.wav'));
    _errorPlayer.setSource(AssetSource('sounds/error.wav'));
    _chordPlayer.setSource(AssetSource('sounds/success_chord.wav'));
  }

  Future<void> playSuccessChime() async {
    await _successPlayer.stop(); // Stop if already playing
    await _successPlayer.resume();
  }

  Future<void> playErrorThud() async {
    await _errorPlayer.stop();
    await _errorPlayer.resume();
  }
  
  Future<void> playDing(int step) async {
    await _dingPlayer.stop();
    int dingIndex = (step % 3) + 1;
    await _dingPlayer.play(AssetSource('sounds/ding_$dingIndex.wav'));
  }

  Future<void> playSuccessChord() async {
    await _chordPlayer.stop();
    await _chordPlayer.resume();
  }
}
