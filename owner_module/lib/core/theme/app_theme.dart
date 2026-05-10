import 'package:flutter/material.dart';

/// Дополнительные поверхности приложения
extension AppSurfaces on ColorScheme {
  Color get bg1 => const Color(0xFFF6F7FB); // Фон приложения
  Color get bg2 => Colors.white; // Карточки / секции
  Color get bg3 => const Color(0xFFF1F5F9); // Элементы внутри секций
  Color get bg4 => const Color(0xFFE8EEF6); // Chips / inner blocks
}

class AppTheme {
  // Основные цвета
  static const _accent = Color(0xFF2563EB); // Accent
  static const _danger = Color(0xFFE5484D); // Ошибки
  static const _text = Color(0xFF111827); // Основной текст
  static const _muted = Color(0xFF6B7280); // Вторичный текст
  static const _snackBg = Color(0xFF1F2937); // SnackBar background

  static ThemeData dark() {
    // Базовая светлая схема
    final base = ColorScheme.fromSeed(
      seedColor: _accent,
      brightness: Brightness.light,
    );

    // Кастомная схема поверх Material 3
    final scheme = base.copyWith(
      primary: _accent,
      error: _danger,

      // Material 3 surfaces
      surface: base.bg2,
      surfaceContainerHighest: base.bg2,
      surfaceContainerHigh: base.bg3,
      surfaceContainer: base.bg4,

      onSurface: _text,
      onSurfaceVariant: _muted,
    );

    // Базовый стиль текста Inter
    TextStyle inter({
      required double size,
      required FontWeight weight,
      double height = 1.24,
      double letter = 0.12,
      Color color = _text,
    }) {
      return TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letter,
        color: color,
        decoration: TextDecoration.none,
      );
    }

    // Текстовая тема
    final text = TextTheme(
      // Большие заголовки
      headlineLarge: inter(size: 32, weight: FontWeight.w900, height: 1.12),

      headlineMedium: inter(size: 28, weight: FontWeight.w900, height: 1.14),

      headlineSmall: inter(size: 24, weight: FontWeight.w800, height: 1.16),

      // Заголовки секций
      titleLarge: inter(size: 22, weight: FontWeight.w900, height: 1.14),

      titleMedium: inter(size: 18, weight: FontWeight.w800, height: 1.16),

      titleSmall: inter(size: 15, weight: FontWeight.w800, height: 1.18),

      // Основной текст
      bodyLarge: inter(size: 15, weight: FontWeight.w500, height: 1.34),

      bodyMedium: inter(
        size: 13.5,
        weight: FontWeight.w500,
        height: 1.34,
        color: _text.withValues(alpha: 0.88),
      ),

      bodySmall: inter(
        size: 12.5,
        weight: FontWeight.w500,
        height: 1.32,
        color: _muted,
      ),

      // Labels / кнопки
      labelLarge: inter(size: 13.5, weight: FontWeight.w700, height: 1.18),

      labelMedium: inter(size: 12.5, weight: FontWeight.w700, height: 1.18),

      labelSmall: inter(size: 11.5, weight: FontWeight.w700, height: 1.18),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      colorScheme: scheme,

      // Глобальный фон
      scaffoldBackgroundColor: scheme.bg1,
      canvasColor: scheme.bg1,

      // Глобальный шрифт
      fontFamily: 'Inter',

      // Текстовая тема
      textTheme: text,

      // AppBar
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.bg1,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _text,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),

      // Карточки
      cardTheme: CardThemeData(
        color: scheme.bg2,
        elevation: 0,
        margin: EdgeInsets.zero,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),

          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),

      // Dialog windows
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.bg2,
        surfaceTintColor: Colors.transparent,

        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
      ),

      // Поля ввода
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.bg3,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),

          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.70),
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),

          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.70),
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),

          borderSide: BorderSide(color: scheme.primary, width: 1.3),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),

          borderSide: BorderSide(color: scheme.error),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),

          borderSide: BorderSide(color: scheme.error, width: 1.3),
        ),

        hintStyle: TextStyle(color: _muted.withValues(alpha: 0.80)),

        labelStyle: TextStyle(color: _text.withValues(alpha: 0.75)),

        floatingLabelStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),

      // Filled buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,

          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.38),

          disabledForegroundColor: Colors.white.withValues(alpha: 0.80),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),

          textStyle: text.labelLarge,

          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),

      // Outlined buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _text.withValues(alpha: 0.92),

          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.85),
          ),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),

          textStyle: text.labelLarge,

          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: text.labelLarge,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // Bottom navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.bg2,
        selectedItemColor: scheme.primary,
        unselectedItemColor: _muted,
        elevation: 0,

        selectedLabelStyle: text.labelSmall,
        unselectedLabelStyle: text.labelSmall,
      ),

      // NavigationBar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.bg1,

        indicatorColor: scheme.primary.withValues(alpha: 0.12),

        labelTextStyle: WidgetStatePropertyAll(text.labelSmall),

        iconTheme: WidgetStatePropertyAll(
          IconThemeData(color: _text.withValues(alpha: 0.84)),
        ),
      ),

      // Tabs
      tabBarTheme: TabBarThemeData(
        indicatorColor: scheme.primary,
        dividerColor: Colors.transparent,

        labelColor: scheme.primary,
        unselectedLabelColor: _muted,

        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge,
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: scheme.bg4,

        selectedColor: scheme.primary.withValues(alpha: 0.14),

        labelStyle: text.labelMedium?.copyWith(
          color: _text.withValues(alpha: 0.90),
        ),

        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.70)),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        tileColor: scheme.bg2,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),

        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,

        iconColor: _text.withValues(alpha: 0.82),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }

          return null;
        }),

        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary.withValues(alpha: 0.32);
          }

          return null;
        }),
      ),

      // Иконки
      iconTheme: IconThemeData(color: _text.withValues(alpha: 0.88)),

      // Divider
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.60),
      ),

      // Progress indicators
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,

        circularTrackColor: scheme.outlineVariant.withValues(alpha: 0.35),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _snackBg.withValues(alpha: 0.97),

        contentTextStyle: text.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),

        behavior: SnackBarBehavior.floating,

        elevation: 0,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
