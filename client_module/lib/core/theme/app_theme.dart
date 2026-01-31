import 'package:flutter/material.dart';

class AppTheme {
  // Палитра “Yandex-like”
  static const _bg = Color(0xFF0B0F14);
  static const _surface = Color(0xFF141926);
  static const _card = Color(0xFF242B3A);
  static const _card2 = Color(0xFF2B3346);

  static const _accent = Color(0xFF4DA3FF);
  static const _danger = Color(0xFFE5484D);

  static ThemeData dark({required fontMode}) {
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

    // ✅ БАЗОВЫЕ “разлипляющие” параметры:
    // - letterSpacing слегка положительный
    // - height чуть выше
    // - body вес пониже (600 вместо 700)
    TextStyle base({
      required double size,
      required FontWeight weight,
      double height = 1.22,
      double letter = 0.15,
    }) {
      return TextStyle(
        fontFamily: 'Manrope',
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letter,
      );
    }

    final text = Typography.material2021().white.copyWith(
      // Заголовки — жирные, но с умеренным letterSpacing
      titleLarge: base(size: 21, weight: FontWeight.w800, height: 1.12, letter: 0.05),
      titleMedium: base(size: 17, weight: FontWeight.w800, height: 1.14, letter: 0.06),
      titleSmall: base(size: 15, weight: FontWeight.w800, height: 1.16, letter: 0.06),

      // Тело — ключевое: делаем легче и “воздушнее”
      bodyLarge: base(size: 15, weight: FontWeight.w600, height: 1.26, letter: 0.18),
      bodyMedium: base(size: 13.5, weight: FontWeight.w600, height: 1.28, letter: 0.18),
      bodySmall: base(size: 12.5, weight: FontWeight.w600, height: 1.28, letter: 0.18),

      // Лейблы/кнопки — чуть плотнее, но не слипшиеся
      labelLarge: base(size: 13.5, weight: FontWeight.w700, height: 1.16, letter: 0.10),
      labelMedium: base(size: 12.5, weight: FontWeight.w700, height: 1.16, letter: 0.10),
      labelSmall: base(size: 11.5, weight: FontWeight.w700, height: 1.16, letter: 0.10),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: _bg,
      canvasColor: _bg,
      textTheme: text,

      // ✅ глобально задаём fontFamily тоже (некоторые виджеты берут отсюда)
      fontFamily: 'Manrope',

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
        labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.80)),
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
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            letterSpacing: 0.08,
            color: scheme.onSurface.withValues(alpha: 0.80),
          ),
        ),
        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: scheme.onSurface.withValues(alpha: 0.80)),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: _card2,
        selectedColor: scheme.primary.withValues(alpha: 0.22),
        labelStyle: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          letterSpacing: 0.10,
          color: scheme.onSurface.withValues(alpha: 0.90),
        ),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      iconTheme: IconThemeData(color: scheme.onSurface.withValues(alpha: 0.85)),
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
