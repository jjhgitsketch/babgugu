// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppColors {
  // UI 초안 기준 코랄 레드
  static const primary = Color(0xFFF06B6B);
  static const primaryLight = Color(0xFFF58E8E);
  static const primaryDark = Color(0xFFD94F4F);
  static const primaryBg = Color(0xFFFFF0F0);
  static const secondary = Color(0xFFFFB347); // 노란 포인트 (구버전 호환)

  static const bg = Color(0xFFFFFFFF);
  static const bgGray = Color(0xFFF5F5F5);
  static const surface = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFFFF);

  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF888888);
  static const textLight = Color(0xFFBBBBBB);

  static const divider = Color(0xFFEEEEEE);
  static const tagBg = Color(0xFFFFF0F0);
  static const tagText = Color(0xFFF06B6B);

  static const matchHigh = Color(0xFF4CAF50);
  static const matchMid = Color(0xFFFF9800);
  static const matchLow = Color(0xFFF06B6B);

  // 카드 배경 (코랄)
  static const cardCoral = Color(0xFFF06B6B);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: AppColors.bg,
        ),
        fontFamily: 'pretendard',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: IconThemeData(color: AppColors.textPrimary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.bgGray,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      );
}
