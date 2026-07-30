import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class NuruTextStyles {
  // Display / numbers — Fraunces (serif)
  static TextStyle display({Color color = NuruColors.ink, double fontSize = 36, FontWeight weight = FontWeight.w600}) {
    return GoogleFonts.fraunces(
      color: color,
      fontSize: fontSize,
      fontWeight: weight,
    );
  }

  // Body / UI — IBM Plex Sans
  static TextStyle body({Color color = NuruColors.ink, double fontSize = 16, FontWeight weight = FontWeight.normal}) {
    return GoogleFonts.ibmPlexSans(
      color: color,
      fontSize: fontSize,
      fontWeight: weight,
    );
  }

  // Data / code — IBM Plex Mono
  static TextStyle mono({Color color = NuruColors.inkMuted, double fontSize = 14, FontWeight weight = FontWeight.normal}) {
    return GoogleFonts.ibmPlexMono(
      color: color,
      fontSize: fontSize,
      fontWeight: weight,
    );
  }
}
