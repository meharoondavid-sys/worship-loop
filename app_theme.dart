import 'package:flutter/material.dart';

/// Design tokens and theme system for Worship Loop.
/// Inspired by professional digital audio workstations (DAWs) and live stage mixers.
class AppColors {
  AppColors._();

  // Core Stage Palette
  static const Color background = Color(0xFF0C0F14); // Deep matte graphite
  static const Color surface = Color(0xFF151921); // Charcoal mixer panel
  static const Color surfaceElevated = Color(0xFF1D232E); // Raised control bays
  static const Color surfaceSubtle = Color(0xFF101319); // Recessed track wells

  // Borders and Dividers
  static const Color border = Color(0xFF262E3B); // Subtle section demarcation
  static const Color borderSubtle = Color(0xFF1A202A);
  static const Color divider = Color(0xFF232A36);

  // Typography Colors
  static const Color textPrimary = Color(0xFFEDF2F7); // High-contrast stage off-white
  static const Color textSecondary = Color(0xFF94A3B8); // Soft readable studio grey
  static const Color textMuted = Color(0xFF64748B); // Low-priority metadata
  static const Color textOnDark = Color(0xFFF8FAFC);
  static const Color textOnAccent = Color(0xFF080D14);

  // Channel & Bus Accents
  static const Color padAccent = Color(0xFFE5A93C); // Warm amber / muted stage gold
  static const Color padAccentMuted = Color(0x33E5A93C);
  static const Color padSurfaceActive = Color(0x1FE5A93C);

  static const Color percussionAccent = Color(0xFF4A90E2); // Studio monitoring blue
  static const Color percussionAccentMuted = Color(0x334A90E2);
  static const Color percSurfaceActive = Color(0x1F4A90E2);

  // Emergency / Critical Action (Strictly for STOP ALL)
  static const Color emergency = Color(0xFFD32F2F); // Stage emergency red
  static const Color emergencyDark = Color(0xFF8B1E1E);
  static const Color emergencySurface = Color(0x26D32F2F);

  // Status & Telemetry
  static const Color statusReady = Color(0xFF34D399); // Stage ready green
  static const Color statusReadyBg = Color(0xFF10261D);
  static const Color statusReadyBorder = Color(0xFF1E4A37);

  // Inactive Controls
  static const Color inactiveTrack = Color(0xFF1A202A);
  static const Color inactiveButton = Color(0xFF212834);
  static const Color inactiveText = Color(0xFF788699);
}

class AppTypography {
  AppTypography._();

  static const TextStyle appTitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.2,
    color: AppColors.textSecondary,
  );

  static const TextStyle stageHeadline = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: AppColors.textPrimary,
  );

  static const TextStyle sectionHeader = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.6,
    color: AppColors.textPrimary,
  );

  static const TextStyle sectionSubtitle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: AppColors.textMuted,
  );

  static const TextStyle controlLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
    color: AppColors.textSecondary,
  );

  static const TextStyle channelName = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const TextStyle bpmValue = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle musicalKey = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
  );

  static const TextStyle buttonSmallLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
  );

  static const TextStyle statusBadge = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
  );

  static const TextStyle audioFileName = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle footer = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 22.0;
  static const double xxl = 28.0;

  static const double cardPadding = 14.0;
  static const double sectionSpacing = 24.0;
}

class AppShapes {
  AppShapes._();

  static const double radiusSm = 8.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 18.0;
  static const double radiusPill = 99.0;

  static const double borderWidth = 1.0;
  static const double borderWidthActive = 1.5;

  static const double iconSm = 16.0;
  static const double iconMd = 22.0;
  static const double iconLg = 28.0;
}

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.percussionAccent,
        secondary: AppColors.padAccent,
        surface: AppColors.surface,
        error: AppColors.emergency,
        onPrimary: AppColors.textOnAccent,
        onSecondary: AppColors.textOnAccent,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      dividerColor: AppColors.divider,
      cardTheme: CardTheme(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusLg),
          side: const BorderSide(color: AppColors.border, width: AppShapes.borderWidth),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppShapes.radiusMd),
          ),
          textStyle: AppTypography.buttonLabel,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppShapes.radiusMd),
          ),
          textStyle: AppTypography.buttonSmallLabel,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusMd),
          side: const BorderSide(color: AppColors.border),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
