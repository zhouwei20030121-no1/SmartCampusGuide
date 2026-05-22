import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF4A90E2);
  static const Color lightBlue = Color(0xFF85C1E9);
  static const Color textMain = Color(0xFF2C3E50);
  static const Color textSub = Color(0xFF7F8C8D);
  static const Color pageBg = Color(0xFFEBF5FB);

  static ThemeData get theme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: pageBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: textMain,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        fontFamily: 'PingFang SC',
      );
}
