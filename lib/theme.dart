import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Warna diambil langsung dari logo ModalKu.
class C {
  static const yellow = Color(0xFFFFCC00);
  static const cream = Color(0xFFF9EFCE);
  static const ink = Colors.black;
  static const red = Color(0xFFE00000);
  static const green = Color(0xFF1A9C00);
  static const greenText = Color(0xFF0B7A00);
  static const mute = Color(0xFF8A8270);
}

/// Huruf tebal bersudut untuk judul dan angka, selaras dengan logo.
TextStyle display(double size, {Color color = C.ink}) => GoogleFonts.chakraPetch(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
      height: 1.1,
    );

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: C.yellow).copyWith(
      primary: C.yellow,
      onPrimary: Colors.black,
      surface: C.cream,
    ),
  );
  OutlineInputBorder border(double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: C.ink, width: w),
      );
  return base.copyWith(
    scaffoldBackgroundColor: C.cream,
    textTheme: GoogleFonts.dmSansTextTheme(base.textTheme)
        .apply(bodyColor: C.ink, displayColor: C.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(2),
      enabledBorder: border(2),
      focusedBorder: border(3),
      labelStyle: const TextStyle(color: C.mute),
      floatingLabelStyle: const TextStyle(color: C.ink, fontWeight: FontWeight.w700),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: C.ink,
      inactiveTrackColor: Color(0x33000000),
      thumbColor: C.ink,
      overlayColor: Color(0x22000000),
    ),
  );
}
