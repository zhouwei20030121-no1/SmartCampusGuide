import 'package:flutter/material.dart';

class AppTheme {
  // 与登录按钮统一色号 #023D83（深蓝）
  static const Color primary = Color(0xFF023D83);
  static const Color darkBlue = Color(0xFF011F44);
  static const Color lightBlue = Color(0xFF5A7DA5);
  static const Color textMain = Color(0xFF2C3E50);
  static const Color textSub = Color(0xFF7F8C8D);
  static const Color pageBg = Color(0xFFEEF2F7);
  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF39C12);
  static const Color danger = Color(0xFFE74C3C);

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
        // fontFamily 移除，使用系统默认字体（Android: Roboto, iOS: SF Pro）
      );
}
