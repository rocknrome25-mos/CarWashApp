import 'package:flutter/material.dart';

class AppTheme {
  static const _bg = Color(0xFF0B0F14);
  static const _surface = Color(0xFF141926);
  static const _card = Color(0xFF242B3A);
  static const _card2 = Color(0xFF2B3346);

  static const _accent = Color(0xFF4DA3FF);
  static const _danger = Color(0xFFE5484D);

  // ✅ snackbar: мягкий “blue-gray” но контрастный
  static const _snackBg = Color(0xFF1B2A3A); // темнее карточек, не как кнопка

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: Brightness.dark,
        ).copyWith(
          surface: _surface,
          surfaceContainerHighest: _card,
          surfaceContainerHigh: _card2,
          surfaceContainer: _card,
          error: _danger,
          primary: _accent,
        );

    TextStyle inter({
      required double size,
      required FontWeight weight,
      double height = 1.22,
      double letter = 0.0,
    }) {
      return TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letter,
      );
    }

    final base = Typography.material2021().white;

    final text = base.copyWith(
      titleLarge: inter(size: 22, weight: FontWeight.w800, height: 1.12),
      titleMedium: inter(size: 18, weight: FontWeight.w800, height: 1.14),
      titleSmall: inter(size: 15, weight: FontWeight.w700, height: 1.18),
      bodyLarge: inter(size: 15, weight: FontWeight.w400, height: 1.30),
      bodyMedium: inter(size: 13.5, weight: FontWeight.w400, height: 1.30),
      bodySmall: inter(size: 12.5, weight: FontWeight.w400, height: 1.30),
      labelLarge: inter(size: 13.5, weight: FontWeight.w600, height: 1.14),
      labelMedium: inter(size: 12.5, weight: FontWeight.w600, height: 1.14),
      labelSmall: inter(size: 11.5, weight: FontWeight.w600, height: 1.14),
    );

    // ✅ no nullable copyWith warning
    final snackText = (text.bodyMedium ?? const TextStyle()).copyWith(
      color: Colors.white.withValues(alpha: 0.95),
      fontWeight: FontWeight.w700,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: _bg,
      canvasColor: _bg,
      fontFamily: 'Inter',
      textTheme: text,

      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),

      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
      ),

      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _card2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.2),
        ),
        hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.55)),
        labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.85)),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _bg,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            color: scheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: scheme.onSurface.withValues(alpha: 0.85)),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: _card2,
        selectedColor: scheme.primary.withValues(alpha: 0.22),
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          color: scheme.onSurface.withValues(alpha: 0.90),
        ),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      iconTheme: IconThemeData(color: scheme.onSurface.withValues(alpha: 0.9)),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
      ),

      // ✅ SnackBar: контрастный, читаемый, мягкий
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _snackBg.withValues(alpha: 0.92),
        contentTextStyle: snackText,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: scheme.primary.withValues(
              alpha: 0.18,
            ), // лёгкая “синяя” рамка
          ),
        ),
      ),
    );
  }
}
