import 'package:flutter/material.dart';

class ValleyBrandColors {
  static const Color night = Color(0xFF07051F);
  static const Color cosmic = Color(0xFF151047);
  static const Color violet = Color(0xFF6F2CFF);
  static const Color lilac = Color(0xFFBB8CFF);
  static const Color cyan = Color(0xFF20C8F3);
  static const Color snow = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF121827);
  static const Color muted = Color(0xFF5A657A);
  static const Color success = Color(0xFF22B86B);
  static const Color warning = Color(0xFFF2A93B);
  static const Color danger = Color(0xFFE45B6A);
  static const Color surface = Color(0xFFF7F8FF);
  static const Color panelDark = Color(0xFF110C31);
  static const Color panelDarkStrong = Color(0xFF171043);
}

class ValleySurfacePalette extends ThemeExtension<ValleySurfacePalette> {
  const ValleySurfacePalette({
    required this.panel,
    required this.panelStrong,
    required this.border,
    required this.glow,
  });

  final Color panel;
  final Color panelStrong;
  final Color border;
  final Color glow;

  @override
  ThemeExtension<ValleySurfacePalette> copyWith({
    Color? panel,
    Color? panelStrong,
    Color? border,
    Color? glow,
  }) {
    return ValleySurfacePalette(
      panel: panel ?? this.panel,
      panelStrong: panelStrong ?? this.panelStrong,
      border: border ?? this.border,
      glow: glow ?? this.glow,
    );
  }

  @override
  ThemeExtension<ValleySurfacePalette> lerp(
    covariant ThemeExtension<ValleySurfacePalette>? other,
    double t,
  ) {
    if (other is! ValleySurfacePalette) {
      return this;
    }
    return ValleySurfacePalette(
      panel: Color.lerp(panel, other.panel, t) ?? panel,
      panelStrong: Color.lerp(panelStrong, other.panelStrong, t) ?? panelStrong,
      border: Color.lerp(border, other.border, t) ?? border,
      glow: Color.lerp(glow, other.glow, t) ?? glow,
    );
  }
}

class ValleyBrandTheme {
  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: ValleyBrandColors.violet,
      brightness: Brightness.light,
      primary: ValleyBrandColors.violet,
      secondary: ValleyBrandColors.cyan,
      surface: ValleyBrandColors.surface,
      error: ValleyBrandColors.danger,
    );

    return _base(
      scheme,
      const ValleySurfacePalette(
        panel: Color(0xFFF6F7FF),
        panelStrong: Color(0xFFFFFFFF),
        border: Color(0xFFE3E5F3),
        glow: ValleyBrandColors.violet,
      ),
    ).copyWith(
      scaffoldBackgroundColor: ValleyBrandColors.surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: ValleyBrandColors.night,
        foregroundColor: ValleyBrandColors.snow,
        centerTitle: false,
        elevation: 0,
      ),
    );
  }

  static ThemeData dark() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: ValleyBrandColors.violet,
      brightness: Brightness.dark,
      primary: ValleyBrandColors.violet,
      secondary: ValleyBrandColors.cyan,
      surface: ValleyBrandColors.cosmic,
      error: ValleyBrandColors.danger,
    );

    return _base(
      scheme,
      const ValleySurfacePalette(
        panel: ValleyBrandColors.panelDark,
        panelStrong: ValleyBrandColors.panelDarkStrong,
        border: Color(0x22FFFFFF),
        glow: ValleyBrandColors.cyan,
      ),
    ).copyWith(
      scaffoldBackgroundColor: ValleyBrandColors.night,
      appBarTheme: const AppBarTheme(
        backgroundColor: ValleyBrandColors.night,
        foregroundColor: ValleyBrandColors.snow,
        centerTitle: false,
        elevation: 0,
      ),
    );
  }

  static ThemeData _base(
    ColorScheme scheme,
    ValleySurfacePalette surfacePalette,
  ) {
    final TextTheme baseText = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
    ).textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[surfacePalette],
      textTheme: baseText.copyWith(
        displaySmall: baseText.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          height: 1.02,
          letterSpacing: 0,
        ),
        headlineSmall: baseText.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
        titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        bodyLarge: baseText.bodyLarge?.copyWith(height: 1.45),
        labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: surfacePalette.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ValleyBrandColors.violet,
          foregroundColor: ValleyBrandColors.snow,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ValleyBrandColors.cyan,
          side: const BorderSide(color: ValleyBrandColors.cyan),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfacePalette.panelStrong.withValues(alpha: 0.92),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: ValleyBrandColors.violet,
            width: 1.5,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfacePalette.panelStrong,
        indicatorColor: ValleyBrandColors.violet.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class ValleyLogoMark extends StatelessWidget {
  const ValleyLogoMark({super.key, this.size = 48, this.borderRadius = 14});

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        'assets/brand/logo-valley-official.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
