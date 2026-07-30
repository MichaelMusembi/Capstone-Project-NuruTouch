import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'models/lesson.dart';

class CurriculumDatabase {
  static final CurriculumDatabase _instance = CurriculumDatabase._internal();
  static CurriculumDatabase get instance => _instance;

  CurriculumDatabase._internal();

  List<Lesson> _englishLessons = [];
  List<Lesson> _swahiliLessons = [];

  List<Lesson> get englishLessons => _englishLessons;
  List<Lesson> get swahiliLessons => _swahiliLessons;

  Future<void> loadCurriculum() async {
    _englishLessons = [];
    _swahiliLessons = [];

    try {
      final jsonString = await rootBundle.loadString('assets/curriculum/lessons.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;
      
      if (data['english'] != null) {
        final enList = data['english'] as List;
        _englishLessons = enList.map((e) => Lesson.fromMap(e)).toList();
      }
      
      if (data['swahili'] != null) {
        final swList = data['swahili'] as List;
        _swahiliLessons = swList.map((e) => Lesson.fromMap(e)).toList();
      }
      
      print("Loaded ${_englishLessons.length} English lessons and ${_swahiliLessons.length} Swahili lessons.");
    } catch (e) {
      print('Error loading curriculum from JSON: $e');
    }
  }

  Lesson? getLessonById(String id, String languageCode) {
    final list = languageCode.startsWith('sw') ? _swahiliLessons : _englishLessons;
    try {
      return list.firstWhere((l) => l.id == id);
    } catch (e) {
      return null;
    }
  }
}