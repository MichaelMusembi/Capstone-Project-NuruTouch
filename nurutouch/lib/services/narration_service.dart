import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import '../core/adaptive_learning/models/narration_step.dart';
import 'tts_service.dart';
import 'haptic_service.dart';

class NarrationService {
  static final NarrationService _instance = NarrationService._internal();
  static NarrationService get instance => _instance;

  NarrationService._internal();

  final TtsService _tts = TtsService();
  Map<dynamic, dynamic> _englishTemplates = {};
  Map<dynamic, dynamic> _swahiliTemplates = {};
  int _queueSessionId = 0;

  Future<void> stop() async {
    _queueSessionId++;
    await _tts.stop();
  }

  final Map<String, String> _swDotGroups = {
    "1,2": "vitone vya kwanza na pili",
    "1,3": "vitone vya kwanza na tatu",
    "1,4": "vitone vya kwanza na nne",
    "1,3,4": "vitone vya kwanza, tatu na nne",
    "1,2,3": "vitone vya kwanza, pili na tatu",
    "2,4": "vitone vya pili na nne",
    "2,3,4,5": "vitone vya pili, tatu, nne na tano",
    "1,3,4,5": "vitone vya kwanza, tatu, nne na tano",
    "1,2,4": "vitone vya kwanza, pili na nne",
    "1,2,4,5": "vitone vya kwanza, pili, nne na tano",
    "1,3,4,5,6": "vitone vya kwanza, tatu, nne, tano na sita",
    "1": "kitone cha kwanza",
    "2": "kitone cha pili",
    "3": "kitone cha tatu",
    "4": "kitone cha nne",
    "5": "kitone cha tano",
    "6": "kitone cha sita",
  };

  Future<void> init() async {
    try {
      final engStr = await rootBundle.loadString('assets/narration/english.yaml');
      _englishTemplates = loadYaml(engStr) as YamlMap;
    } catch (e) {
      print("Failed to load english.yaml narration");
    }

    try {
      final swaStr = await rootBundle.loadString('assets/narration/swahili.yaml');
      _swahiliTemplates = loadYaml(swaStr) as YamlMap;
    } catch (e) {
      print("Failed to load swahili.yaml narration");
    }
  }

  Future<void> speakTemplate(String key, String langCode, {Map<String, String>? variables, bool appendReminder = false}) async {
    final templates = langCode.startsWith('sw') ? _swahiliTemplates : _englishTemplates;
    String text = templates[key] ?? key; // fallback to key itself if missing

    if (variables != null) {
      variables.forEach((k, v) {
        text = text.replaceAll('{$k}', v);
      });
    }

    await speakRaw(text, langCode, appendReminder: appendReminder);
  }

  Future<void> speakGlobalNavigation(String action, String langCode) async {
    if (action == 'swipeDown') {
      await speakTemplate(langCode.startsWith('sw') ? 'sw_swipe_to_continue' : 'en_swipe_to_continue', langCode);
    }
  }

  String formatDots(List<int> dots, String langCode) {
    if (dots.isEmpty) return "";
    dots.sort();
    final dotStr = dots.join(',');
    
    if (langCode.startsWith('sw')) {
      return _swDotGroups[dotStr] ?? "vitone $dotStr";
    } else {
      return "dots $dotStr";
    }
  }

  Future<void> speakRaw(String text, String langCode, {bool appendReminder = false}) async {
    final ttsLang = langCode.startsWith('sw') ? "sw-KE" : "en-US";
    
    // Single letter pronunciation fix
    if (text.trim().length == 1 && RegExp(r'[a-zA-Z]').hasMatch(text.trim())) {
      text = "${text.trim()}.";
    }

    final chunks = text.split('<haptic_tick>');
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i].trim();
      
      // Clean any other unknown or malformed tags
      final cleanedChunk = chunk.replaceAll(RegExp(r'<[^>]*>'), '').trim();

      if (cleanedChunk.isNotEmpty) {
        await _tts.speak(cleanedChunk, language: ttsLang, appendReminder: (appendReminder && i == chunks.length - 1));
      }
      
      // Trigger haptic after chunk, if it was split by the tag
      if (i < chunks.length - 1) {
        try {
          await HapticService().tick();
        } catch (e) {
          print("Warning: Haptic feedback failed, continuing narration: $e");
        }
      }
    }
  }

  Future<void> playQueue(List<NarrationStep> queue, String langCode, {bool appendReminder = false}) async {
    final int currentSession = _queueSessionId;
    for (int i = 0; i < queue.length; i++) {
      if (currentSession != _queueSessionId) return;
      await speakRaw(queue[i].text, langCode, appendReminder: (appendReminder && i == queue.length - 1));
      // Wait a short moment between steps for natural pacing
      if (currentSession != _queueSessionId) return;
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }
}
