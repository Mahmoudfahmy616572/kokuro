import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class K {
  K._();

  // ── Accent (themeable at runtime) ────────────────────────
  static Color accent = const Color(0xFF7C5CFC);
  static Color accentSoft = const Color(0xFF9B82FD);
  static Color threadPrimary = const Color(0xFF7C5CFC);

  /// Preset accent palettes offered in the profile theme picker.
  /// Each entry is (displayColor, softColor).
  static const accentPresets = <(Color, Color)>[
    (Color(0xFF7C5CFC), Color(0xFF9B82FD)), // KOKURO purple
    (Color(0xFF4FC3F7), Color(0xFF81D4FA)), // sky blue
    (Color(0xFF26C6DA), Color(0xFF4DD0E1)), // cyan
    (Color(0xFFEF5350), Color(0xFFF06262)), // coral red
    (Color(0xFFAB47BC), Color(0xFFC86ED4)), // violet
    (Color(0xFF26A69A), Color(0xFF4DB6AC)), // teal
    (Color(0xFFFF7043), Color(0xFFFF8A65)), // orange
    (Color(0xFFEC407A), Color(0xFFF06292)), // pink
    (Color(0xFF9E9D24), Color(0xFFC0CA33)), // lime
    (Color(0xFF29B6F6), Color(0xFF4FC3F7)), // light blue
  ];

  /// Notifies the root widget to rebuild its theme whenever the accent
  /// changes at runtime (see the ValueListenableBuilder in `main.dart`).
  static final ValueNotifier<int> accentVersion = ValueNotifier<int>(0);

  /// Applies an accent theme: keeps `accent` cosmetics in sync so every
  /// K.accent reference across the app instantly follows the new color.
  /// Reload from SharedPreferences happens on app start via `K.restoreAccent`.
  static void setAccent((Color, Color) preset) {
    accent = preset.$1;
    accentSoft = preset.$2;
    threadPrimary = preset.$1;
    accentVersion.value++;
  }

  static const _accentKey = 'app_accent_index';

  static Future<void> restoreAccent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt(_accentKey) ?? 0;
      if (index >= 0 && index < accentPresets.length) {
        applyAccentIndex(index);
      }
    } catch (_) {}
  }

  static Future<void> saveAccentIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, index.clamp(0, accentPresets.length - 1));
  }

  /// Sets the accent from the preset index and persists the choice.
  static Future<void> applyAccentIndex(int index) async {
    final i = index.clamp(0, accentPresets.length - 1);
    setAccent(accentPresets[i]);
    await saveAccentIndex(i);
  }

  // ── Colors ──────────────────────────────────────────────
  static const bg = Color(0xFF06080F);
  static const bgAlt = Color(0xFF0B0E18);
  static const bgCard = Color(0xFF0F1220);
  static const bgSurface = Color(0xFF141829);
  static const border = Color(0xFF1E2336);
  static const borderSubtle = Color(0xFF161B2E);

  static const textPrimary = Color(0xFFECEEF4);
  static const textSecondary = Color(0xFF8B8FA3);
  static const textTertiary = Color(0xFF555A6E);

  static const coral = Color(0xFFFF6B6B);
  static const orange = Color(0xFFFF8A50);
  static const cyan = Color(0xFF56CCF2);
  static const pink = Color(0xFFED6FA0);
  static const gold = Color(0xFFFFD700);

  // thread colors
  static const threadSecondary = Color(0xFF56CCF2);
  static const threadWarm = Color(0xFFFF8A50);
  static const threadPink = Color(0xFFED6FA0);

  // ── Typography ──────────────────────────────────────────
  static const fontFamily = 'Inter';

  static const displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 56,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -1.5,
    height: 1.1,
  );
  static const displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -1,
    height: 1.15,
  );
  static const headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );
  static const headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.25,
  );
  static const titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    height: 1.3,
  );
  static const titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    height: 1.35,
  );
  static const bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );
  static const bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.5,
  );
  static const bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textTertiary,
    height: 1.4,
  );
  static const labelUppercase = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: textTertiary,
    letterSpacing: 1.5,
    height: 1.2,
  );
  static const rating = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: gold,
    height: 1.0,
  );
  static const statNumber = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    height: 1.0,
  );

  // ── Spacing ─────────────────────────────────────────────
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
  static const double s64 = 64;
  static const double s80 = 80;

  // ── Radius ──────────────────────────────────────────────
  static const double r4 = 4;
  static const double r8 = 8;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double r24 = 24;
  static const double r32 = 32;
  static const double rFull = 999;

  // ── Animation ───────────────────────────────────────────
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration durationVerySlow = Duration(milliseconds: 600);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve spring = Curves.elasticOut;

  // ── Glow ────────────────────────────────────────────────
  static List<BoxShadow> glow({
    required Color color,
    double blur = 24,
    double spread = 0,
  }) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.15),
        blurRadius: blur,
        spreadRadius: spread,
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.05),
        blurRadius: blur * 2,
        spreadRadius: spread,
      ),
    ];
  }

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}
