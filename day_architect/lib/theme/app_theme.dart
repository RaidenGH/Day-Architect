import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design tokens for Day Architect.
/// Matches the Figma mockup color palette exactly.
class AppColors {
  // Backgrounds
  static const bgDark = Color(0xFF14152B);
  static const bgMid = Color(0xFF1F2142);
  static const bgLight = Color(0xFF1B1D3A);

  // Accents
  static const accent = Color(0xFFE8935B); // amber-orange
  static const accentSoft = Color(0xFFF2A488); // coral
  static const sage = Color(0xFF9CAF94); // wellness green
  static const plum = Color(0xFF6E6A99); // muted purple

  // Text
  static const textPrimary = Color(0xFFF6F1E7);
  static const textSecondary = Color(0xFF8A87B0);
  static const textMuted = Color(0xFF5A5880);
  static const textAmberLight = Color(0xFFC9A98E);
  static const textLavender = Color(0xFFC9C4E0);

  // Surfaces
  static const cardSurface = Color(0x0DFFFFFF); // rgba(255,255,255,0.055)
  static const cardBorder = Color(0x0DFFFFFF);

  // Category chip colors
  static const chipAmberBg = Color(0x33E8935B);
  static const chipCoralBg = Color(0x33F2A488);
  static const chipSageBg = Color(0x339CAF94);
  static const chipPlumBg = Color(0x336E6A99);
}

class AppGradients {
  static const background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.bgLight, AppColors.bgMid, Color(0xFF1A1B38)],
  );

  static const accentButton = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.accent, AppColors.accentSoft],
  );
}

class AppTextStyles {
  static TextStyle heading({double size = 24, FontWeight weight = FontWeight.w700}) {
    return GoogleFonts.lora(
      fontSize: size,
      fontWeight: weight,
      color: AppColors.textPrimary,
    );
  }

  static TextStyle eyebrow({double size = 15}) {
    return GoogleFonts.lora(
      fontSize: size,
      fontStyle: FontStyle.italic,
      color: AppColors.textAmberLight,
    );
  }

  static TextStyle body({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
  }) {
    return GoogleFonts.poppins(fontSize: size, fontWeight: weight, color: color);
  }

  static TextStyle label({double size = 11}) {
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.0,
      color: AppColors.textMuted,
    );
  }
}

class AppTheme {
  /// Build the app theme with accessible contrast.
  static ThemeData get theme {
    return ThemeData(
      scaffoldBackgroundColor: AppColors.bgMid,
      fontFamily: GoogleFonts.poppins().fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accentSoft,
        surface: AppColors.bgMid,
        // Ensure sufficient contrast for accessibility
        onPrimary: AppColors.bgMid,
        onSecondary: AppColors.bgMid,
        onSurface: AppColors.textPrimary,
      ),
      useMaterial3: true,
      // Fix text contrast on primary/surface
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
        decorationColor: AppColors.textPrimary,
      ),
    );
  }
}
