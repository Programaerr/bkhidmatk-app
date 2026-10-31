import 'package:flutter/material.dart';

/// «جايك» brand palette, derived from the uploaded yellow/black logo.
class AppColors {
  static const gold = Color(0xFFFFD400);
  static const goldDeep = Color(0xFFE8BE00);
  static const goldSoft = Color(0xFFFFF3BF);
  static const ink = Color(0xFF0B0B0D);
  static const inkSoft = Color(0xFF17171A);
  static const inkMuted = Color(0xFF5F5F66);
  static const paper = Color(0xFFF6F6F0);
  static const paperDark = Color(0xFF08080A);
  static const line = Color(0xFFE9E9DF);
  static const lineDark = Color(0xFF25252B);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF2563EB);
  static const violet = Color(0xFF7C3AED);
}

class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? AppColors.inkSoft : Colors.white;
    final background = isDark ? AppColors.paperDark : AppColors.paper;
    final onSurface = isDark ? const Color(0xFFF4F4EE) : AppColors.ink;
    final muted = isDark ? const Color(0xFF9B9BA3) : AppColors.inkMuted;
    final outline = isDark ? AppColors.lineDark : AppColors.line;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.gold,
      onPrimary: AppColors.ink,
      primaryContainer: isDark ? const Color(0xFF3A3208) : AppColors.goldSoft,
      onPrimaryContainer: isDark ? AppColors.gold : const Color(0xFF5C4A00),
      secondary: isDark ? Colors.white : AppColors.ink,
      onSecondary: isDark ? AppColors.ink : Colors.white,
      secondaryContainer: isDark ? const Color(0xFF26262C) : const Color(0xFFF0F0E8),
      onSecondaryContainer: onSurface,
      tertiary: AppColors.info,
      onTertiary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: isDark ? const Color(0xFF202027) : const Color(0xFFF0F0EA),
      outline: outline,
      outlineVariant: outline,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: onSurface,
      onInverseSurface: surface,
      inversePrimary: AppColors.goldDeep,
    );

    const base = TextStyle(fontFamily: 'Cairo', height: 1.45);

    final textTheme = TextTheme(
      displaySmall: base.copyWith(fontSize: 34, fontWeight: FontWeight.w900, height: 1.2),
      headlineLarge: base.copyWith(fontSize: 28, fontWeight: FontWeight.w900, height: 1.25),
      headlineMedium: base.copyWith(fontSize: 24, fontWeight: FontWeight.w800, height: 1.3),
      headlineSmall: base.copyWith(fontSize: 21, fontWeight: FontWeight.w800, height: 1.3),
      titleLarge: base.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
      titleMedium: base.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      titleSmall: base.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      bodyLarge: base.copyWith(fontSize: 15, fontWeight: FontWeight.w400),
      bodyMedium: base.copyWith(fontSize: 13.5, fontWeight: FontWeight.w400),
      bodySmall: base.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: muted),
      labelLarge: base.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
      labelMedium: base.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: muted),
      labelSmall: base.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: muted),
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: outline),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Cairo',
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: onSurface),
        titleTextStyle: base.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: outline),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1B1B20) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: base.copyWith(fontSize: 13.5, color: muted),
        labelStyle: base.copyWith(fontSize: 13.5, color: muted),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.gold, width: 1.8),
        ),
        errorBorder: inputBorder.copyWith(borderSide: const BorderSide(color: AppColors.danger)),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.ink,
          minimumSize: const Size(0, 54),
          elevation: 0,
          textStyle: base.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size(0, 52),
          side: BorderSide(color: outline),
          textStyle: base.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.gold : AppColors.ink,
          textStyle: base.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF202027) : Colors.white,
        selectedColor: AppColors.gold,
        labelStyle: base.copyWith(fontSize: 12.5, fontWeight: FontWeight.w700),
        secondaryLabelStyle: base.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.gold.withValues(alpha: 0.22),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          base.copyWith(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? onSurface : muted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.gold.withValues(alpha: 0.22),
        selectedIconTheme: IconThemeData(color: onSurface),
        unselectedIconTheme: IconThemeData(color: muted),
        selectedLabelTextStyle: base.copyWith(fontSize: 12, fontWeight: FontWeight.w800),
        unselectedLabelTextStyle: base.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF2A2A31) : AppColors.ink,
        contentTextStyle: base.copyWith(fontSize: 13.5, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        insetPadding: const EdgeInsets.all(16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        titleTextStyle: base.copyWith(fontSize: 18, fontWeight: FontWeight.w800, color: onSurface),
        contentTextStyle: base.copyWith(fontSize: 14, color: onSurface),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.gold),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.ink : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.gold
              : (isDark ? const Color(0xFF2C2C33) : AppColors.line),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        headerBackgroundColor: AppColors.ink,
        headerForegroundColor: AppColors.gold,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: onSurface,
        unselectedLabelColor: muted,
        indicatorColor: AppColors.gold,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: base.copyWith(fontSize: 13.5, fontWeight: FontWeight.w800),
        unselectedLabelStyle: base.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onSurface,
        textColor: onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }
}
