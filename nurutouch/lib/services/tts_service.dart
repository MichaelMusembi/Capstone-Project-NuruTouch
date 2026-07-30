import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../config/app_strings.dart';
import 'swahili_tts_engine.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final SwahiliTTSEngine _mmsTts = SwahiliTTSEngine();
  
  String _lastSpokenText = "";
  String _lastLanguage = "en-US";
  int _speechSessionId = 0;
  bool _isSpeaking = false;
  
  bool get isSpeaking => _isSpeaking;

  late Future<void> _initFuture;

  TtsService._internal() {
    _initFuture = _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setSpeechRate(0.5); 
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    // Block until the full utterance completes before returning — prevents reminder
    // from firing mid-sentence after only a 3-second delay.
    await _flutterTts.awaitSpeakCompletion(true);
    
    // Configure audio player for TTS/Accessibility so it plays loud and clear
    await _audioPlayer.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: true,
        usageType: AndroidUsageType.assistanceAccessibility,
        contentType: AndroidContentType.speech,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {AVAudioSessionOptions.duckOthers},
      ),
    ));
    await _audioPlayer.setVolume(1.0);

    try {
      await _mmsTts.init();
      print("MMS TTS Initialized Successfully!");
    } catch (e) {
      print("Failed to init MMS Engine: $e");
    }
  }

  Future<void> speak(String text, {String language = "en-US", bool appendReminder = false, bool isFeedback = false}) async {
    await _initFuture;

    if (!isFeedback) {
      _lastSpokenText = text;
      _lastLanguage = language;
    }

    _isSpeaking = true;
    _speechSessionId++;
    final int currentSession = _speechSessionId;
    
    await _flutterTts.stop();
    await _audioPlayer.stop();

    try {
      // CROSSOVER GUARD: If text contains obvious English UI words, fallback to English TTS
      if ((language == "sw-KE" || language.startsWith("sw")) && RegExp(r'\b(Dot|Press|Swipe|Tap|The)\b', caseSensitive: false).hasMatch(text)) {
        language = "en-US";
      }

      if (language == "sw-KE" || language.startsWith("sw")) {
        try {
          final List<String> chunks = text
              .split(RegExp(r'[.,!?\n;]+'))
              .map((c) => c.trim())
              .where((c) => c.isNotEmpty)
              .toList();

          if (chunks.isNotEmpty) {
            Future<String>? nextSynthesis = _mmsTts.synthesizeSpeech(chunks[0]);

            for (int i = 0; i < chunks.length; i++) {
              if (currentSession != _speechSessionId) return;

              final String wavPath = await nextSynthesis!;

              if (currentSession != _speechSessionId) return;

              if (i + 1 < chunks.length) {
                nextSynthesis = _mmsTts.synthesizeSpeech(chunks[i + 1]);
              }

              await _audioPlayer.play(DeviceFileSource(wavPath));
              
              await Future.any([
                _audioPlayer.onPlayerComplete.first,
                _audioPlayer.onPlayerStateChanged.firstWhere((state) => state == PlayerState.stopped),
              ]);
            }
          }
        } catch (e) {
          print("MMS generation error on text '$text': $e");
          if (currentSession == _speechSessionId) {
            // Play a generic error tone or fallback phrase instead of dead air
            await _flutterTts.setLanguage("sw-KE"); // Most devices have a default Swahili voice that's robotic but works as fallback
            await _flutterTts.speak("Samahani, sikupata hiyo."); 
          }
        }
      } else {
        // For English
        await _flutterTts.setLanguage("en-US"); // Force it to English US
        await _flutterTts.speak(text);
      }

      if (appendReminder && currentSession == _speechSessionId) {
        String reminderLang = language.startsWith("sw") ? "sw-KE" : "en-US";
        await speak(AppStrings.getNavigationReminder(reminderLang), language: reminderLang, isFeedback: true);
      }
    } finally {
      if (currentSession == _speechSessionId) {
        _isSpeaking = false;
      }
    }
  }
  
  Future<void> repeatLast() async {
    if (_lastSpokenText.isNotEmpty) {
      await speak(_lastSpokenText, language: _lastLanguage, appendReminder: false);
    }
  }

  Future<void> stop() async {
    _speechSessionId++;
    _isSpeaking = false;
    await _flutterTts.stop();
    await _audioPlayer.stop();
  }
}
