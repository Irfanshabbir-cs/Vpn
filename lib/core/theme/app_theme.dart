import 'package:flutter/material.dart';

/// Brand colors. Kept separate from ThemeData so widgets can reach for
/// brand-specific accents (e.g. connection-state greens/reds) regardless
/// of light/dark mode.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF5B5FEF);
  static const Color primaryDark = Color(0xFF3A3DBF);
  static const Color secondary = Color(0xFF00D68F);
  static const Color danger = Color(0xFFFF4757);
  static const Color warning = Color(0xFFFFB020);

  static const Color darkBg = Color(0xFF0E0F1A);
  static const Color darkSurface = Color(0xFF171827);
  static const Color lightBg = Color(0xFFF6F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);

  static const List<Color> connectedGradient = [Color(0xFF00D68F), Color(0xFF00B4D8)];
  static const List<Color> disconnectedGradient = [Color(0xFF3A3DBF), Color(0xFF5B5FEF)];
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      secondary: AppColors.secondary,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      cardTheme: CardThemeData(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: isDark ? Colors.white38 : Colors.black38,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  /// Reusable glassmorphism decoration for cards/overlays.
  static BoxDecoration glass({double radius = 24, bool dark = true}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: (dark ? Colors.white : Colors.black).withOpacity(0.06),
      border: Border.all(color: Colors.white.withOpacity(0.12)),
    );
  }
}
