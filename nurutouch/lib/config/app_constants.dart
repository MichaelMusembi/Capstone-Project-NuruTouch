class AppConstants {
  // We will eventually load this from the database for parent/teacher profiles, 
  // but for now, it lives strictly in config, never hardcoded in the UI.
  static const String supervisorPin = "1234";
  
  // Gesture & Sensor Thresholds
  static const double swipeThreshold = 50.0;
  static const int holdToUnlockSeconds = 6;
}
