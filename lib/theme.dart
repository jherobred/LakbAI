import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Brand palette, modelled on Google's Material 3 apps (Gemini, Files, Messages).
class KColors {
  // Light
  static const lBg = Color(0xFFFFFFFF);
  static const lSurface = Color(0xFFFFFFFF);
  static const lSurfaceAlt = Color(0xFFF0F4F9);
  static const lInk = Color(0xFF1F1F1F);
  static const lInkSoft = Color(0xFF444746);
  static const lOutline = Color(0xFFC4C7C5);
  static const lPrimary = Color(0xFF0B57D0);
  static const lPrimaryContainer = Color(0xFFD3E3FD);
  static const lOnPrimaryContainer = Color(0xFF041E49);

  // Dark
  static const dBg = Color(0xFF131314);
  static const dSurface = Color(0xFF1B1B1C);
  static const dSurfaceAlt = Color(0xFF1E1F20);
  static const dInk = Color(0xFFE3E3E3);
  static const dInkSoft = Color(0xFFC4C7C5);
  static const dOutline = Color(0xFF8E918F);
  static const dPrimary = Color(0xFFA8C7FA);
  static const dPrimaryContainer = Color(0xFF0842A0);
  static const dOnPrimaryContainer = Color(0xFFD3E3FD);

  static const blue = Color(0xFF4285F4);
  static const purple = Color(0xFF9B72CB);
  static const rose = Color(0xFFD96570);
  static const cyan = Color(0xFF4FC3F7);
  static const sky = Color(0xFF7CACF8);
  static const indigo = Color(0xFF6366F1);

  /// The blue-violet-rose sweep used for the AI's spark and its "thinking" shimmer.
  static const ai = [blue, purple, rose];
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
    required this.ai,
  });

  final Color surfaceAlt;
  final Color inkSoft;
  final Color success;
  final Color warning;
  final Color danger;
  final Gradient hero;
  final Color userBubble;
  final Color glow;
  final Gradient ai;

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
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      ai: t < 0.5 ? ai : other.ai,
    );
  }
}

class KTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final bg = dark ? KColors.dBg : KColors.lBg;
    final scheme = ColorScheme(
      brightness: b,
      primary: dark ? KColors.dPrimary : KColors.lPrimary,
      onPrimary: dark ? const Color(0xFF062E6F) : Colors.white,
      primaryContainer: dark ? KColors.dPrimaryContainer : KColors.lPrimaryContainer,
      onPrimaryContainer: dark ? KColors.dOnPrimaryContainer : KColors.lOnPrimaryContainer,
      secondary: dark ? const Color(0xFF7FCFFF) : const Color(0xFF00639B),
      onSecondary: dark ? const Color(0xFF003355) : Colors.white,
      secondaryContainer: dark ? const Color(0xFF004A77) : const Color(0xFFC2E7FF),
      onSecondaryContainer: dark ? const Color(0xFFC2E7FF) : const Color(0xFF001D35),
      tertiary: dark ? const Color(0xFF6DD58C) : const Color(0xFF146C2E),
      onTertiary: dark ? const Color(0xFF0A3818) : Colors.white,
      error: dark ? const Color(0xFFF2B8B5) : const Color(0xFFB3261E),
      onError: dark ? const Color(0xFF601410) : Colors.white,
      surface: dark ? KColors.dBg : KColors.lSurface,
      onSurface: dark ? KColors.dInk : KColors.lInk,
      surfaceContainerLowest: bg,
      surfaceContainerLow: dark ? KColors.dSurface : const Color(0xFFF8FAFD),
      surfaceContainer: dark ? KColors.dSurfaceAlt : KColors.lSurfaceAlt,
      surfaceContainerHigh: dark ? const Color(0xFF282A2C) : const Color(0xFFE9EEF6),
      surfaceContainerHighest: dark ? const Color(0xFF333537) : const Color(0xFFDDE3EA),
      onSurfaceVariant: dark ? KColors.dInkSoft : KColors.lInkSoft,
      outline: dark ? KColors.dOutline : KColors.lOutline,
      outlineVariant: dark ? const Color(0xFF444746) : const Color(0xFFE1E3E1),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: dark ? KColors.dInk : const Color(0xFF303030),
      onInverseSurface: dark ? KColors.dBg : const Color(0xFFF2F2F2),
      inversePrimary: dark ? KColors.lPrimary : KColors.dPrimary,
    );

    final tokens = KTokens(
      surfaceAlt: dark ? KColors.dSurfaceAlt : KColors.lSurfaceAlt,
      inkSoft: dark ? KColors.dInkSoft : KColors.lInkSoft,
      success: dark ? const Color(0xFF6DD58C) : const Color(0xFF188038),
      warning: dark ? const Color(0xFFFDD663) : const Color(0xFFB06000),
      danger: dark ? const Color(0xFFF28B82) : const Color(0xFFD93025),
      hero: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFF0842A0), Color(0xFF0B57D0), Color(0xFF5B3FA8)]
            : const [Color(0xFF0B57D0), Color(0xFF4285F4), Color(0xFF8E6CD8)],
      ),
      userBubble: dark ? const Color(0xFF333537) : const Color(0xFFE9EEF6),
      glow: dark ? const Color(0x334285F4) : const Color(0x224285F4),
      ai: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: KColors.ai),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: b,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
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
        headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w500, letterSpacing: -0.4, height: 1.15),
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w500, letterSpacing: -0.3, height: 1.2),
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w500, letterSpacing: -0.1),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w500),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 16.5, height: 1.5),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 15, height: 1.45),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.1),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: scheme.onSurface,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w500, fontSize: 21),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: bg,
        labelStyle: TextStyle(fontWeight: FontWeight.w500, color: scheme.onSurface),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary, linearTrackColor: scheme.surfaceContainerHigh),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
      // Every transition paints the themed background itself, so no white
      // window ever shows through mid-animation (most visible in dark mode).
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(backgroundColor: bg),
          TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
