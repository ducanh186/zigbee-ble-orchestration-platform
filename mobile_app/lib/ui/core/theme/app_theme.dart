import 'package:flutter/material.dart';

enum AppThemeMode { light, dark, grey }

class ThemeController extends ChangeNotifier {
  AppThemeMode _mode = AppThemeMode.light;

  AppThemeMode get mode => _mode;

  void setMode(AppThemeMode mode) {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    notifyListeners();
  }
}

class AppTheme {
  static ThemeData theme(AppThemeMode mode) {
    final palette = switch (mode) {
      AppThemeMode.light => AppPalette.light,
      AppThemeMode.dark => AppPalette.dark,
      AppThemeMode.grey => AppPalette.grey,
    };
    final brightness = mode == AppThemeMode.dark
        ? Brightness.dark
        : Brightness.light;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
      primary: palette.primary,
      surface: palette.surface,
      error: palette.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      fontFamily: 'Inter',
      extensions: [palette],
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: palette.surface,
        indicatorColor: palette.primaryTint,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.primary,
    required this.primaryTint,
    required this.primaryOn,
    required this.success,
    required this.successTint,
    required this.warning,
    required this.warningTint,
    required this.error,
    required this.errorTint,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color primary;
  final Color primaryTint;
  final Color primaryOn;
  final Color success;
  final Color successTint;
  final Color warning;
  final Color warningTint;
  final Color error;
  final Color errorTint;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  static const light = AppPalette(
    background: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    primary: Color(0xFF4F7DFF),
    primaryTint: Color(0x1F4F7DFF),
    primaryOn: Color(0xFFFFFFFF),
    success: Color(0xFF22C55E),
    successTint: Color(0x1F22C55E),
    warning: Color(0xFFF59E0B),
    warningTint: Color(0x1FF59E0B),
    error: Color(0xFFEF4444),
    errorTint: Color(0x1FEF4444),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF6B7280),
    border: Color(0xFFE5E7EB),
  );

  static const dark = AppPalette(
    background: Color(0xFF0F1115),
    surface: Color(0xFF171A21),
    surfaceElevated: Color(0xFF20242D),
    primary: Color(0xFF7AA2FF),
    primaryTint: Color(0x267AA2FF),
    primaryOn: Color(0xFF0F1115),
    success: Color(0xFF34D399),
    successTint: Color(0x2634D399),
    warning: Color(0xFFFBBF24),
    warningTint: Color(0x26FBBF24),
    error: Color(0xFFF87171),
    errorTint: Color(0x26F87171),
    textPrimary: Color(0xFFF9FAFB),
    textSecondary: Color(0xFFA1A1AA),
    border: Color(0xFF2D3340),
  );

  static const grey = AppPalette(
    background: Color(0xFFF1F5F9),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF8FAFC),
    primary: Color(0xFF475569),
    primaryTint: Color(0x1F475569),
    primaryOn: Color(0xFFFFFFFF),
    success: Color(0xFF16A34A),
    successTint: Color(0x1F16A34A),
    warning: Color(0xFFD97706),
    warningTint: Color(0x1FD97706),
    error: Color(0xFFDC2626),
    errorTint: Color(0x1FDC2626),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    border: Color(0xFFE2E8F0),
  );

  @override
  ThemeExtension<AppPalette> copyWith() => this;

  @override
  ThemeExtension<AppPalette> lerp(
    covariant ThemeExtension<AppPalette>? other,
    double t,
  ) {
    return this;
  }
}

extension AppPaletteLookup on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
