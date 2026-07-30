import 'package:flutter/material.dart';

class NuruColors {
  static const Color background = Color(0xFFF7F8FB); // Screen background — cool porcelain
  static const Color ink = Color(0xFF1B1F3B);        // Primary text, headers
  static const Color inkMuted = Color(0xFF6B7089);   // Secondary text, timestamps
  static const Color indigo = Color(0xFF4C4FE0);     // Active filters, links, FAB
  static const Color sage = Color(0xFF2F9E68);       // Mastered status, passed 1st attempt
  static const Color amber = Color(0xFFE8A33D);      // Struggling status, passed after retries
  static const Color slate = Color(0xFFC7CBDA);      // Not-started status, locked stages
  static const Color coral = Color(0xFFF0577B);      // Failure events only
  
  // Legacy colors mapped to avoid breaking existing UI
  static const Color black = Color(0xFF050505);
  static const Color bone = background;
  static const Color clay = coral;
  static const Color green = sage;
  
}
