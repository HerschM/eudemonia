import 'package:flutter/material.dart';

/// Design tokens strictly conforming to UX.md Section 2
class PreviewTheme {
  // Color Palette Tokens
  static const Color background = Color(0xFF0A0A0C);
  static const Color surface = Color(0xFF16161A);
  static const Color surfaceElevated = Color(0xFF202026);
  static const Color borderSubtle = Color(0x14FFFFFF); // rgba(255, 255, 255, 0.08)
  static const Color borderFocus = Color(0x29FFFFFF); // rgba(255, 255, 255, 0.16)

  static const Color accentCapture = Color(0xFF10B981); // Emerald
  static const Color accentAction = Color(0xFF3B82F6); // Electric Blue
  static const Color accentAI = Color(0xFF8B5CF6); // Violet
  static const Color accentWarning = Color(0xFFF59E0B); // Amber
  static const Color accentError = Color(0xFFEF4444); // Rose Red

  static const Color captureCardBg = Color(0xFF16161A);
  static const Color stateEnqueuedBg = Color(0xFF26200A);
  static const Color stateSynthesisBg = Color(0xFF111827);
  static const Color stateFailedBg = Color(0xFF271111);

  static const Color numberBadgeBg = Color(0x0FFFFFFF); // rgba(255, 255, 255, 0.06)
  static const Color numberBadgeText = Color(0xFF9CA3AF);
  static const Color unreadDot = Color(0xFF60A5FA);

  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textTertiary = Color(0xFF6B7280);

  // Spacing & Corner Radii
  static const double cardRadius = 18.0;
  static const double buttonRadius = 12.0;
  static const double pillRadius = 20.0;
  static const double badgeRadius = 8.0;
  static const double modalRadius = 28.0;

  static BoxDecoration cardDecoration({Color? bgColor, Color? borderColor}) {
    return BoxDecoration(
      color: bgColor ?? surface,
      borderRadius: BorderRadius.circular(cardRadius),
      border: Border.all(
        color: borderColor ?? borderSubtle,
        width: 1.0,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accentAction,
      fontFamily: 'Inter',
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: accentAction,
        secondary: accentCapture,
      ),
    );
  }
}

