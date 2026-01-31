import 'package:flutter/material.dart';

class AppTheme {
  // Палитра “Yandex-like”
  static const _bg = Color(0xFF0B0F14);
  static const _surface = Color(0xFF141926);
  static const _card = Color(0xFF242B3A); // серо-сиреневый
  static const _card2 = Color(0xFF2B3346);

  static const _accent = Color(0xFF4DA3FF); // “yandex blue”
  static const _danger = Color(0xFFE5484D);

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

    // Системный шрифт (как у Яндекса): iOS -> SF Pro, Android -> Roboto
    // Делаем только размеры/веса читабельнее.
    final baseText = Typography.material2021().white;

    final text = baseText
        .copyWith(
          titleLarge: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
          titleMedium: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
          titleSmall: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),

          bodyLarge: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          bodyMedium: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
          bodySmall: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),

          labelLarge: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
          labelMedium: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
          labelSmall: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: _bg,
      canvasColor: _bg,
      textTheme: text,

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(
          color: scheme.onSurface.withValues(alpha: 0.92),
        ),
        titleTextStyle: text.titleMedium,
      ),

      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: _card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
        titleTextStyle: text.titleMedium,
        contentTextStyle: text.bodyMedium,
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
            fontWeight: FontWeight.w700,
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
          fontWeight: FontWeight.w800,
          color: scheme.onSurface.withValues(alpha: 0.92),
        ),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      iconTheme: IconThemeData(color: scheme.onSurface.withValues(alpha: 0.92)),
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
