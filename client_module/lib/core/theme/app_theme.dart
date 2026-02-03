import 'package:flutter/material.dart';

/// Global theme (Yandex-like):
/// 1) bg1 = screen background
/// 2) bg2 = section background
/// 3) bg3 = element background (dropdowns, tiles inside section)
/// 4) bg4 = inner elements (price pills, small chips)
extension AppSurfaces on ColorScheme {
  Color get bg1 => const Color(0xFF0B0F14); // screen
  Color get bg2 => const Color(0xFF151B26); // section
  Color get bg3 => const Color(0xFF1E2636); // element
  Color get bg4 => const Color(0xFF2A3448); // inner
}

class AppTheme {
  // Accent
  static const _accent = Color(0xFF4DA3FF);
  static const _danger = Color(0xFFE5484D);

  // SnackBar: мягкий blue-gray, но заметный
  static const _snackBg = Color(0xFF22364A);

  static ThemeData dark() {
    // ✅ base scheme
    final base = ColorScheme.fromSeed(
      seedColor: _accent,
      brightness: Brightness.dark,
    );

    // ✅ enforce our surfaces (bg1..bg4)
    final scheme = base.copyWith(
      primary: _accent,
      error: _danger,

      // Material 3 surfaces
      surface: base.bg2, // section
      surfaceContainerHighest: base.bg2, // section
      surfaceContainerHigh: base.bg3, // element
      surfaceContainer: base.bg4, // inner
    );

    // ---- Typography: fix "letters stick together" ----
    // For web (especially Chrome), Inter with 0.0 letterSpacing can look "stuck".
    // We apply small positive spacing for titles/labels + a stable height.
    TextStyle inter({
      required double size,
      required FontWeight weight,
      double height = 1.24,
      double letter = 0.18,
    }) {
      return TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letter,
        // Avoid extra effects that can blur on web
        decoration: TextDecoration.none,
      );
    }

    final typo = Typography.material2021().white;

    final text = typo.copyWith(
      // Titles
      titleLarge: inter(
        size: 22,
        weight: FontWeight.w800,
        height: 1.14,
        letter: 0.20,
      ),
      titleMedium: inter(
        size: 18,
        weight: FontWeight.w800,
        height: 1.16,
        letter: 0.20,
      ),
      titleSmall: inter(
        size: 15,
        weight: FontWeight.w700,
        height: 1.18,
        letter: 0.18,
      ),

      // Body
      bodyLarge: inter(
        size: 15,
        weight: FontWeight.w400,
        height: 1.34,
        letter: 0.12,
      ),
      bodyMedium: inter(
        size: 13.5,
        weight: FontWeight.w400,
        height: 1.34,
        letter: 0.12,
      ),
      bodySmall: inter(
        size: 12.5,
        weight: FontWeight.w400,
        height: 1.32,
        letter: 0.10,
      ),

      // Labels / Buttons
      labelLarge: inter(
        size: 13.5,
        weight: FontWeight.w600,
        height: 1.18,
        letter: 0.14,
      ),
      labelMedium: inter(
        size: 12.5,
        weight: FontWeight.w600,
        height: 1.18,
        letter: 0.14,
      ),
      labelSmall: inter(
        size: 11.5,
        weight: FontWeight.w600,
        height: 1.18,
        letter: 0.14,
      ),
    );

    // no nullable copyWith warnings
    final snackText = (text.bodyMedium ?? const TextStyle()).copyWith(
      color: Colors.white.withValues(alpha: 0.98),
      fontWeight: FontWeight.w700,
      letterSpacing: 0.12,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,

      // ✅ Level 1 background (screen)
      scaffoldBackgroundColor: scheme.bg1,
      canvasColor: scheme.bg1,

      // ✅ global font
      fontFamily: 'Inter',
      textTheme: text,

      // AppBar: transparent like Yandex
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),

      // Cards: use section/bg2 by default
      cardTheme: CardThemeData(
        color: scheme.bg2,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.bg2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
      ),

      // Inputs: element/bg3
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.bg3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.60),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.2),
        ),
        hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.60)),
        labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.85)),
      ),

      // Buttons
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
          foregroundColor: scheme.onSurface.withValues(alpha: 0.92),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.70),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),

      // NavigationBar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.bg1,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            letterSpacing: 0.12,
            color: scheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: scheme.onSurface.withValues(alpha: 0.85)),
        ),
      ),

      // Chips: inner/bg4
      chipTheme: ChipThemeData(
        backgroundColor: scheme.bg4,
        selectedColor: scheme.primary.withValues(alpha: 0.22),
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          letterSpacing: 0.12,
          color: scheme.onSurface.withValues(alpha: 0.92),
        ),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.60)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      iconTheme: IconThemeData(color: scheme.onSurface.withValues(alpha: 0.90)),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.50),
      ),

      // ✅ SnackBar: мягкий, но читаемый (не как кнопка)
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _snackBg.withValues(alpha: 0.96),
        contentTextStyle: snackText,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.28)),
        ),
      ),
    );
  }
}
