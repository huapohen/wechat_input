import 'package:flutter/material.dart';

/// Design tokens mirrored from shared/spec/design_tokens.json.
class AppColors {
  static const background = Color(0xFFE6F4F2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF7FBFA);
  static const accent = Color(0xFF24C891);
  static const accentDark = Color(0xFF0E8A68);
  static const accentSoft = Color(0xFFDFF6EC);
  static const text = Color(0xFF26332F);
  static const textSecondary = Color(0xFF5F6F69);
  static const muted = Color(0xFFB8BCC5);
  static const border = Color(0xFFDCE7E3);
  static const warning = Color(0xFFB45309);
  static const danger = Color(0xFFB23A3A);
  static const key = Color(0xFFFFFFFF);
  static const keyPressed = Color(0xFFE9F7F1);
  static const keySpecial = Color(0xFFDDF2EA);
  static const keyText = Color(0xFF26332F);
  static const keyboardBackground = Color(0xFFEAF4F1);

  static const darkBackground = Color(0xFF101917);
  static const darkSurface = Color(0xFF1A2421);
  static const darkSurfaceAlt = Color(0xFF202C28);
  static const darkText = Color(0xFFEAF3EF);
  static const darkSecondary = Color(0xFF9FB3AC);
  static const darkBorder = Color(0xFF31413B);
  static const darkKeyboard = Color(0xFF16211E);
  static const darkKey = Color(0xFF26332F);
  static const darkKeySpecial = Color(0xFF33443E);
  static const darkKeyPressed = Color(0xFF3A554B);
}

class AppTheme {
  static const double cardRadius = 20;
  static const double buttonRadius = 14;
  static const double keyRadius = 12;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
      primary: AppColors.accentDark,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.danger,
    );
    return _base(scheme, AppColors.background, AppColors.surface,
        AppColors.text, AppColors.textSecondary, AppColors.border);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      primary: AppColors.accent,
      onPrimary: const Color(0xFF062A1F),
      secondary: AppColors.accent,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      error: const Color(0xFFFF8A80),
    );
    return _base(scheme, AppColors.darkBackground, AppColors.darkSurface,
        AppColors.darkText, AppColors.darkSecondary, AppColors.darkBorder);
  }

  static ThemeData _base(ColorScheme scheme, Color background, Color surface,
      Color text, Color secondary, Color border) {
    final isDark = scheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      splashFactory: InkSparkle.splashFactory,
      textTheme: TextTheme(
        displaySmall: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: text, height: 1.2),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: text, height: 1.25),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: text, height: 1.3),
        titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: text, height: 1.3),
        bodyLarge: TextStyle(fontSize: 15, color: text, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: text, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, color: secondary, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: text),
      ).apply(bodyColor: text, displayColor: text),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: text),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: border.withValues(alpha: isDark ? .5 : .85)),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.accent : null),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.transparent : border),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: isDark ? const Color(0xFF254238) : AppColors.accentSoft,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: TextStyle(fontSize: 13, color: text),
        secondaryLabelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accentDark),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
        hintStyle: TextStyle(color: secondary.withValues(alpha: .8), fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF2C3B36) : const Color(0xFF26332F),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size(0, 44),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentDark,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        selectedIconTheme: const IconThemeData(color: AppColors.accentDark),
        selectedLabelTextStyle: const TextStyle(color: AppColors.accentDark, fontWeight: FontWeight.w600),
        unselectedIconTheme: IconThemeData(color: secondary),
        unselectedLabelTextStyle: TextStyle(color: secondary),
        indicatorColor: AppColors.accentSoft,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(secondary.withValues(alpha: .35)),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(5),
      ),
    );
  }
}

/// Semantic colors that are not part of ColorScheme.
class AppPalette {
  final bool dark;
  const AppPalette(this.dark);

  Color get card => dark ? AppColors.darkSurface : AppColors.surface;
  Color get cardAlt => dark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt;
  Color get bg => dark ? AppColors.darkBackground : AppColors.background;
  Color get text => dark ? AppColors.darkText : AppColors.text;
  Color get secondary => dark ? AppColors.darkSecondary : AppColors.textSecondary;
  Color get border => dark ? AppColors.darkBorder : AppColors.border;
  Color get accent => AppColors.accent;
  Color get accentDark => dark ? AppColors.accent : AppColors.accentDark;
  Color get soft => dark ? const Color(0xFF1F3B32) : AppColors.accentSoft;
  Color get keyboard => dark ? AppColors.darkKeyboard : AppColors.keyboardBackground;
  Color get key => dark ? AppColors.darkKey : AppColors.key;
  Color get keySpecial => dark ? AppColors.darkKeySpecial : AppColors.keySpecial;
  Color get keyPressed => dark ? AppColors.darkKeyPressed : AppColors.keyPressed;
}
