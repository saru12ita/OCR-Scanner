import 'package:flutter/material.dart';

class AppColors {
  static const bgDeep = Color(0xFF080E1F);
  static const bgCard = Color(0xFF0D1630);
  static const bgSurface = Color(0xFF111D3A);
  static const bgInput = Color(0xFF162040);
  static const bluePri = Color(0xFF3355FF);
  static const blueLight = Color(0xFF4F6DFF);
  static const blueGlow = Color(0x593355FF);
  static const accent = Color(0xFF7C9DFF);
  static const textHi = Color(0xFFEEF2FF);
  static const textMid = Color(0xFF8898CC);
  static const textLo = Color(0xFF4A5C8A);
  static const orange = Color(0xFFFF8C42);
  static const green = Color(0xFF22D48B);
  static const red = Color(0xFFFF4F6D);

  static const blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bluePri, blueLight],
  );

  static const meshGradient = RadialGradient(
    center: Alignment(0, -0.7),
    radius: 1.2,
    colors: [Color(0x2E3355FF), Color(0x003355FF)],
  );
}
