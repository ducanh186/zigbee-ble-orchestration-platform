import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeMode { light, dark, grey }

class ThemeController extends ChangeNotifier {
  AppThemeMode _mode = AppThemeMode.dark;

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

    final baseTextTheme = ThemeData(brightness: brightness).textTheme;
    final interTextTheme = GoogleFonts.interTextTheme(
      baseTextTheme,
    ).apply(bodyColor: palette.textPrimary, displayColor: palette.textPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      textTheme: interTextTheme,
      primaryTextTheme: interTextTheme,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        titleTextStyle: GoogleFonts.inter(
          color: palette.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
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

  // Tokens aligned with the "Zigbee Smart Building Design System (Remix)"
  // /colors_and_type.css. Dark surfaces are lifted ~3% versus the previous
  // values so ambient eyes have less contrast burn while keeping AA legibility.
  static const dark = AppPalette(
    background: Color(0xFF161A21),
    surface: Color(0xFF1F232C),
    surfaceElevated: Color(0xFF2A2F3A),
    primary: Color(0xFF8AAEFF),
    primaryTint: Color(0x338AAEFF),
    primaryOn: Color(0xFF0F1115),
    success: Color(0xFF34D399),
    successTint: Color(0x2934D399),
    warning: Color(0xFFFBBF24),
    warningTint: Color(0x2EFBBF24),
    error: Color(0xFFF87171),
    errorTint: Color(0x29F87171),
    textPrimary: Color(0xFFF9FAFB),
    textSecondary: Color(0xFFB0B3BC),
    border: Color(0xFF383F4D),
  );

  // The third mode in the design system is "cream / be sữa" — warm milk-beige,
  // log-friendly. The enum value is still called `grey` to avoid churn in
  // ThemeController + Settings widgets that toggle it.
  static const grey = AppPalette(
    background: Color(0xFFF0EBE0),
    surface: Color(0xFFF8F4EB),
    surfaceElevated: Color(0xFFFDFAF3),
    primary: Color(0xFF6B5F4E),
    primaryTint: Color(0x1F6B5F4E),
    primaryOn: Color(0xFFFFFFFF),
    success: Color(0xFF5E7A56),
    successTint: Color(0x215E7A56),
    warning: Color(0xFF9A7836),
    warningTint: Color(0x249A7836),
    error: Color(0xFFA35D55),
    errorTint: Color(0x21A35D55),
    textPrimary: Color(0xFF1F1A12),
    textSecondary: Color(0xFF756B5D),
    border: Color(0xFFDDD6C7),
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
