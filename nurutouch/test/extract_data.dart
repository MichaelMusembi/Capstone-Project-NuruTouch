import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nurutouch/data/local/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    debugPrint("=== STARTING DATA EXTRACTION ===");
    final db = await DatabaseHelper.instance.database;
    
    final students = await db.query('students');
    final progress = await db.query('lessons_progress', where: 'passed = 1');
    
    Map<String, dynamic> data = {
      'students_count': students.length,
      'students': students,
      'progress': progress,
    };
    
    String jsonString = jsonEncode(data);
    debugPrint("=== JSON_DATA_START ===");
    final int chunkSize = 800;
    for (int i = 0; i < jsonString.length; i += chunkSize) {
      int end = (i + chunkSize < jsonString.length) ? i + chunkSize : jsonString.length;
      debugPrint(jsonString.substring(i, end));
    }
    debugPrint("=== JSON_DATA_END ===");
    
  } catch (e) {
    debugPrint("ERROR: $e");
  }
}
