import 'package:flutter/material.dart';

class AppState {
  // Singleton Pattern
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  // The Vault
  Map<int, Offset> calibratedDots = {};
  final ValueNotifier<String> languageNotifier = ValueNotifier<String>("en");
  
  // Multi-user state
  int? currentStudentId;
  bool isSupervisorMode = false;

  bool get isCalibrated => calibratedDots.length == 6;

  void saveCalibration(Map<int, Offset> dots) {
    calibratedDots = dots;
  }

  void clearCalibration() {
    calibratedDots.clear();
  }
}
