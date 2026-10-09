import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Brand palette. Blue reads as trust; navy ink keeps text calm and legible.
class KColors {
  // Light
  static const lBg = Color(0xFFF4F7FE);
  static const lSurface = Color(0xFFFFFFFF);
  static const lSurfaceAlt = Color(0xFFEAF0FD);
  static const lInk = Color(0xFF0B1736);
  static const lInkSoft = Color(0xFF4A5878);
  static const lOutline = Color(0xFFD5DEF0);
  static const lPrimary = Color(0xFF1A56DB);
  static const lPrimaryContainer = Color(0xFFDCE7FF);
  static const lOnPrimaryContainer = Color(0xFF0A2A6B);

  // Dark
  static const dBg = Color(0xFF070D1C);
  static const dSurface = Color(0xFF0E1730);
  static const dSurfaceAlt = Color(0xFF15203D);
  static const dInk = Color(0xFFE7EEFF);
  static const dInkSoft = Color(0xFF9AA9C9);
  static const dOutline = Color(0xFF243259);
  static const dPrimary = Color(0xFF6EA8FF);
  static const dPrimaryContainer = Color(0xFF1B3A7A);
  static const dOnPrimaryContainer = Color(0xFFDCE7FF);

  static const cyan = Color(0xFF22D3EE);
  static const sky = Color(0xFF38BDF8);
  static const indigo = Color(0xFF6366F1);
}

/// Semantic tokens that Material's ColorScheme does not cover.
@immutable
class KTokens extends ThemeExtension<KTokens> {
  const KTokens({
    required this.surfaceAlt,
    required this.inkSoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.hero,
    required this.userBubble,
    required this.glow,
  });

  final Color surfaceAlt;
  final Color inkSoft;
  final Color success;
  final Color warning;
  final Color danger;
  final Gradient hero;
  final Gradient userBubble;
  final Color glow;

  static KTokens of(BuildContext context) => Theme.of(context).extension<KTokens>()!;

  @override
  KTokens copyWith({Color? surfaceAlt}) => this;

  @override
  KTokens lerp(ThemeExtension<KTokens>? other, double t) {
    if (other is! KTokens) return this;
    return KTokens(
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      hero: t < 0.5 ? hero : other.hero,
      userBubble: t < 0.5 ? userBubble : other.userBubble,
      glow: Color.lerp(glow, other.glow, t)!,
    );
  }
}

class KTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme(
      brightness: b,
      primary: dark ? KColors.dPrimary : KColors.lPrimary,
      onPrimary: dark ? const Color(0xFF04122E) : Colors.white,
      primaryContainer: dark ? KColors.dPrimaryContainer : KColors.lPrimaryContainer,
      onPrimaryContainer: dark ? KColors.dOnPrimaryContainer : KColors.lOnPrimaryContainer,
      secondary: KColors.sky,
      onSecondary: const Color(0xFF04122E),
      secondaryContainer: dark ? const Color(0xFF123056) : const Color(0xFFE0F2FE),
      onSecondaryContainer: dark ? const Color(0xFFD7EEFF) : const Color(0xFF07354F),
      tertiary: KColors.indigo,
      onTertiary: Colors.white,
      error: dark ? const Color(0xFFFB7185) : const Color(0xFFE11D48),
      onError: Colors.white,
      surface: dark ? KColors.dSurface : KColors.lSurface,
      onSurface: dark ? KColors.dInk : KColors.lInk,
      surfaceContainerLowest: dark ? KColors.dBg : KColors.lBg,
      surfaceContainerLow: dark ? KColors.dSurface : KColors.lSurface,
      surfaceContainer: dark ? KColors.dSurfaceAlt : KColors.lSurfaceAlt,
      surfaceContainerHigh: dark ? const Color(0xFF1B2747) : const Color(0xFFE2EAFB),
      surfaceContainerHighest: dark ? const Color(0xFF223055) : const Color(0xFFD9E3F8),
      onSurfaceVariant: dark ? KColors.dInkSoft : KColors.lInkSoft,
      outline: dark ? KColors.dOutline : KColors.lOutline,
      outlineVariant: dark ? const Color(0xFF1B2747) : const Color(0xFFE6ECF7),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: dark ? KColors.dInk : KColors.lInk,
      onInverseSurface: dark ? KColors.dBg : KColors.lBg,
      inversePrimary: dark ? KColors.lPrimary : KColors.dPrimary,
    );

    final tokens = KTokens(
      surfaceAlt: dark ? KColors.dSurfaceAlt : KColors.lSurfaceAlt,
      inkSoft: dark ? KColors.dInkSoft : KColors.lInkSoft,
      success: dark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
      warning: dark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
      danger: dark ? const Color(0xFFFB7185) : const Color(0xFFE11D48),
      hero: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFF1B3A7A), Color(0xFF1A56DB), Color(0xFF0E7490)]
            : const [Color(0xFF1A56DB), Color(0xFF3B82F6), Color(0xFF06B6D4)],
      ),
      userBubble: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFF2B5FD9), Color(0xFF1E46A8)]
            : const [Color(0xFF2563EB), Color(0xFF1A56DB)],
      ),
      glow: dark ? const Color(0x553B82F6) : const Color(0x332563EB),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: b,
      scaffoldBackgroundColor: dark ? KColors.dBg : KColors.lBg,
      extensions: [tokens],
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
    );

    final text = base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return base.copyWith(
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.1),
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.15),
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 17, height: 1.45),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 15.5, height: 1.45),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.1),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: scheme.onSurface,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? KColors.dSurfaceAlt : KColors.lSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outline),
        labelStyle: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
