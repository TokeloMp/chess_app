import 'package:flutter/material.dart';

// Text styles shared across the app, defined once so the look stays consistent
class AppText {
  static const String displayFamily = 'DMSerifDisplay';
  static const Color ink = Color(0xFF2B1D16);

  static const TextStyle status = TextStyle(fontFamily: displayFamily, fontSize: 24, color: ink);

  static const TextStyle dialogTitle = TextStyle(fontFamily: displayFamily, fontSize: 22, color: ink);

  static const TextStyle playerName = TextStyle(fontFamily: displayFamily, fontSize: 18, color: ink);
}