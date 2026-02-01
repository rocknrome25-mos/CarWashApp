import 'package:flutter/material.dart';

class AppTheme {
  static const _bg = Color(0xFF0B0F14);
  static const _surface = Color(0xFF141926);
  static const _card = Color(0xFF242B3A);
  static const _card2 = Color(0xFF2B3346);

  static const _accent = Color(0xFF4DA3FF);
  static const _danger = Color(0xFFE5484D);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
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

    // ВАЖНО для web-чёткости:
    // - только целые размеры
    // - веса 400/500/600/700 (без 800)
    // - letterSpacing 0 (почти везде)
    TextStyle inter(double size, FontWeight weight, {double height = 1.22}) {
      return TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: const ['Roboto', 'Segoe UI', 'Arial'],
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: 0,
      );
    }

    TextStyle manrope(double size, FontWeight weight, {double height = 1.12}) {
      return TextStyle(
        fontFamily: 'Manrope',
        fontFamilyFallback: const ['Inter', 'Roboto', 'Segoe UI', 'Arial'],
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: 0,
      );
    }

    final base = Typography.material2021().white;

    final text = base.copyWith(
      // Заголовки — Manrope (но без 800)
      titleLarge: manrope(22, FontWeight.w700, height: 1.10),
      titleMedium: manrope(18, FontWeight.w700, height: 1.12),
      titleSmall: manrope(15, FontWeight.w600, height: 1.14),

      // Тело — Inter (максимальная читабельность)
      bodyLarge: inter(15, FontWeight.w400, height: 1.28),
      bodyMedium: inter(14, FontWeight.w400, height: 1.28),
      bodySmall: inter(12, FontWeight.w400, height: 1.26),

      // Кнопки/лейблы
      labelLarge: inter(14, FontWeight.w600, height: 1.14),
      labelMedium: inter(12, FontWeight.w600, height: 1.14),
      labelSmall: inter(11, FontWeight.w600, height: 1.12),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: _bg,
      canvasColor: _bg,
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
            fontFamilyFallback: const ['Roboto', 'Segoe UI', 'Arial'],
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
          fontFamilyFallback: const ['Roboto', 'Segoe UI', 'Arial'],
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _card,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
