import 'package:flutter/material.dart';

/// Tora Basic Rule — palette.
///
/// Mirrors `tokens.css` / `design.md` in the project root. Light is primary;
/// dark is the alternate. There are no other colours: chart steps, dividers and
/// states all come from these values.
class ToraColors {
  const ToraColors._();

  // ---- light (primary) -----------------------------------------------------
  static const Color paper = Color(0xFFF7F7F4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF14161A);
  static const Color inkSoft = Color(0xFF5B6067);
  static const Color inkFaint = Color(0xFF8A8F96);
  static const Color line = Color(0xFFE1E1DC);
  static const Color lineStrong = Color(0xFFC9CAC4);
  static const Color accent = Color(0xFFE4552B);
  static const Color accentText = Color(0xFFB93E19);
  static const Color accentPress = Color(0xFFC8461F);
  static const Color accentWash = Color(0xFFFBEAE3);
  static const Color onAccent = Color(0xFFFFFFFF);

  // ---- dark (secondary) ----------------------------------------------------
  // Pure black, whatever family is selected: the tinted near-black backgrounds
  // were uncomfortable at night, so the colour lives in the accents and cards
  // instead of the page behind them.
  static const Color darkBase = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF16191C);
  static const Color darkSurface2 = Color(0xFF1D2124);
  static const Color darkInk = Color(0xFFF1F1EE);
  static const Color darkInkSoft = Color(0xFF9BA1A8);
  static const Color darkInkFaint = Color(0xFF6E757C);
  static const Color darkLine = Color(0xFF282C31);
  static const Color darkLineStrong = Color(0xFF3A4046);
  static const Color darkAccent = Color(0xFFFF7A4E);
  static const Color darkAccentText = Color(0xFFFF8C66);
  static const Color darkAccentWash = Color(0xFF2A1B15);
  static const Color darkOnAccent = Color(0xFF1A0E08);
}

/// One resolved set of tokens for the current brightness.
///
/// Attached to [ThemeData] as a [ThemeExtension], so a screen only has to ask
/// `ToraPalette.of(context)` and it always gets the palette that is actually in
/// force — whichever family the user picked in the theme drawer.
class ToraPalette extends ThemeExtension<ToraPalette> {
  const ToraPalette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.line,
    required this.lineStrong,
    required this.accent,
    required this.accentText,
    required this.accentWash,
    required this.onAccent,
  });

  static const ToraPalette light = ToraPalette(
    bg: ToraColors.paper,
    surface: ToraColors.surface,
    surface2: ToraColors.paper,
    ink: ToraColors.ink,
    inkSoft: ToraColors.inkSoft,
    inkFaint: ToraColors.inkFaint,
    line: ToraColors.line,
    lineStrong: ToraColors.lineStrong,
    accent: ToraColors.accent,
    accentText: ToraColors.accentText,
    accentWash: ToraColors.accentWash,
    onAccent: ToraColors.onAccent,
  );

  static const ToraPalette dark = ToraPalette(
    bg: ToraColors.darkBase,
    surface: ToraColors.darkSurface,
    surface2: ToraColors.darkSurface2,
    ink: ToraColors.darkInk,
    inkSoft: ToraColors.darkInkSoft,
    inkFaint: ToraColors.darkInkFaint,
    line: ToraColors.darkLine,
    lineStrong: ToraColors.darkLineStrong,
    accent: ToraColors.darkAccent,
    accentText: ToraColors.darkAccentText,
    accentWash: ToraColors.darkAccentWash,
    onAccent: ToraColors.darkOnAccent,
  );

  static ToraPalette of(BuildContext context) =>
      Theme.of(context).extension<ToraPalette>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color line;
  final Color lineStrong;
  final Color accent;
  final Color accentText;
  final Color accentWash;
  final Color onAccent;

  @override
  ToraPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? ink,
    Color? inkSoft,
    Color? inkFaint,
    Color? line,
    Color? lineStrong,
    Color? accent,
    Color? accentText,
    Color? accentWash,
    Color? onAccent,
  }) => ToraPalette(
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surface2: surface2 ?? this.surface2,
    ink: ink ?? this.ink,
    inkSoft: inkSoft ?? this.inkSoft,
    inkFaint: inkFaint ?? this.inkFaint,
    line: line ?? this.line,
    lineStrong: lineStrong ?? this.lineStrong,
    accent: accent ?? this.accent,
    accentText: accentText ?? this.accentText,
    accentWash: accentWash ?? this.accentWash,
    onAccent: onAccent ?? this.onAccent,
  );

  @override
  ToraPalette lerp(ThemeExtension<ToraPalette>? other, double t) {
    if (other is! ToraPalette) {
      return this;
    }
    return ToraPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      accentWash: Color.lerp(accentWash, other.accentWash, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

/// Shape and stroke constants. Radii stop at 6: nothing rounder exists.
class ToraShape {
  const ToraShape._();

  static const double rTag = 2;
  static const double rCard = 4;
  static const double rMax = 6;
  static const double stroke = 1;
  static const double strokeStrong = 1.5;

  static BorderRadius get tag => BorderRadius.circular(rTag);
  static BorderRadius get card => BorderRadius.circular(rCard);
  static BorderRadius get max => BorderRadius.circular(rMax);
}

class AppTheme {
  const AppTheme._();

  /// The system ships one typeface. Plus Jakarta Sans carries 300 ↔ 800.
  static const String fontFamily = 'PlusJakarta';

  static ThemeData light([ToraPalette palette = ToraPalette.light]) =>
      _build(palette, Brightness.light);

  static ThemeData dark([ToraPalette palette = ToraPalette.dark]) =>
      _build(palette, Brightness.dark);

  static ThemeData _build(ToraPalette p, Brightness brightness) {
    final ColorScheme scheme = ColorScheme(
      brightness: brightness,
      primary: p.accent,
      onPrimary: p.onAccent,
      primaryContainer: p.accentWash,
      onPrimaryContainer: p.accentText,
      secondary: p.ink,
      onSecondary: p.bg,
      secondaryContainer: p.surface2,
      onSecondaryContainer: p.ink,
      tertiary: p.accentText,
      onTertiary: p.onAccent,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.ink,
      surfaceContainerHighest: p.surface2,
      onSurfaceVariant: p.inkSoft,
      outline: p.lineStrong,
      outlineVariant: p.line,
      shadow: Colors.transparent,
      scrim: const Color(0x99000000),
      inverseSurface: p.ink,
      onInverseSurface: p.bg,
      inversePrimary: p.accentText,
    );

    // ---- type -------------------------------------------------------------
    TextStyle t(
      double size,
      FontWeight weight, {
      double tracking = 0,
      double height = 1.4,
      Color? color,
      bool tabular = false,
    }) => toraType(
      size,
      weight,
      tracking: tracking,
      height: height,
      color: color ?? p.ink,
      tabular: tabular,
    );

    // The deck ramp scaled to a phone. Hierarchy is weight, never colour.
    final TextTheme text = TextTheme(
      displayLarge: t(34, FontWeight.w800, tracking: -1.4, height: 1.0),
      displayMedium: t(28, FontWeight.w800, tracking: -1.1, height: 1.02),
      displaySmall: t(24, FontWeight.w800, tracking: -0.9, height: 1.05),
      headlineLarge: t(24, FontWeight.w700, tracking: -0.8, height: 1.1),
      headlineMedium: t(21, FontWeight.w700, tracking: -0.6, height: 1.12),
      headlineSmall: t(17, FontWeight.w700, tracking: -0.35, height: 1.2),
      titleLarge: t(16, FontWeight.w700, tracking: -0.3, height: 1.25),
      titleMedium: t(14.5, FontWeight.w600, tracking: -0.15, height: 1.3),
      titleSmall: t(13, FontWeight.w600, height: 1.3),
      bodyLarge: t(15, FontWeight.w400, height: 1.5),
      bodyMedium: t(14, FontWeight.w400, height: 1.5),
      bodySmall: t(12.5, FontWeight.w400, height: 1.45, color: p.inkSoft),
      labelLarge: t(13, FontWeight.w700, tracking: 0.2, height: 1.2),
      labelMedium: t(11, FontWeight.w700, tracking: 1.4, height: 1.2),
      labelSmall: t(10, FontWeight.w600, tracking: 1.2, height: 1.2),
    );

    OutlineInputBorder inputBorder(Color color, double width) =>
        OutlineInputBorder(
          borderRadius: ToraShape.card,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[p],
      scaffoldBackgroundColor: p.bg,
      canvasColor: p.bg,
      dividerColor: p.line,
      splashFactory: InkRipple.splashFactory,
      iconTheme: IconThemeData(color: p.ink, size: 22),
      dividerTheme: DividerThemeData(
        color: p.line,
        thickness: ToraShape.stroke,
        space: ToraShape.stroke,
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        titleTextStyle: text.headlineSmall,
        iconTheme: IconThemeData(color: p.ink, size: 22),
        actionsIconTheme: IconThemeData(color: p.ink, size: 22),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: ToraShape.card,
          side: BorderSide(color: p.line, width: ToraShape.stroke),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.accent,
        disabledColor: p.surface2,
        side: BorderSide(color: p.lineStrong, width: ToraShape.stroke),
        shape: RoundedRectangleBorder(borderRadius: ToraShape.tag),
        labelStyle: t(11, FontWeight.w700, tracking: 1.2),
        secondaryLabelStyle: t(11, FontWeight.w700, tracking: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          disabledBackgroundColor: p.line,
          disabledForegroundColor: p.inkFaint,
          elevation: 0,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: t(13, FontWeight.w700, tracking: 0.3),
          shape: RoundedRectangleBorder(borderRadius: ToraShape.card),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accentText,
          textStyle: t(12, FontWeight.w700, tracking: 1.2),
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: ToraShape.card),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          side: BorderSide(color: p.lineStrong, width: ToraShape.strokeStrong),
          minimumSize: const Size(0, 48),
          textStyle: t(13, FontWeight.w700, tracking: 0.2),
          shape: RoundedRectangleBorder(borderRadius: ToraShape.card),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        extendedTextStyle: t(12.5, FontWeight.w700, tracking: 1.4),
        shape: RoundedRectangleBorder(borderRadius: ToraShape.card),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: ToraShape.max,
          side: BorderSide(color: p.line, width: ToraShape.stroke),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: ToraShape.card,
          side: BorderSide(color: p.lineStrong, width: ToraShape.stroke),
        ),
        textStyle: text.bodyMedium,
        labelTextStyle: WidgetStatePropertyAll<TextStyle?>(text.bodyMedium),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: inputBorder(p.lineStrong, ToraShape.stroke),
        enabledBorder: inputBorder(p.lineStrong, ToraShape.stroke),
        focusedBorder: inputBorder(p.accent, ToraShape.strokeStrong),
        labelStyle: t(12, FontWeight.w600, tracking: 0.6, color: p.inkSoft),
        hintStyle: t(14, FontWeight.w400, color: p.inkFaint),
        floatingLabelStyle: t(
          11,
          FontWeight.w700,
          tracking: 1.2,
          color: p.accentText,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        contentTextStyle: t(13, FontWeight.w600, color: p.bg),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: ToraShape.card),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.line,
        circularTrackColor: p.line,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.inkSoft,
        textColor: p.ink,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        shape: RoundedRectangleBorder(borderRadius: ToraShape.card),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.line,
        thumbColor: p.accent,
        overlayColor: p.accentWash,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: p.ink, borderRadius: ToraShape.tag),
        textStyle: t(11, FontWeight.w600, tracking: 0.6, color: p.bg),
      ),
    );
  }
}

/// A Tora text style for use outside [ThemeData] - the design-system widgets
/// build their own styles so they look identical wherever they are placed.
///
/// The bundled Plus Jakarta Sans is variable, so the weight axis is set
/// explicitly; without it every weight would render as regular.
TextStyle toraType(
  double size,
  FontWeight weight, {
  double tracking = 0,
  double height = 1.4,
  Color color = ToraColors.ink,
  bool tabular = false,
}) => TextStyle(
  fontFamily: AppTheme.fontFamily,
  fontSize: size,
  fontWeight: weight,
  fontVariations: <FontVariation>[
    FontVariation('wght', weight.value.toDouble()),
  ],
  letterSpacing: tracking,
  height: height,
  color: color,
  fontFeatures: tabular
      ? const <FontFeature>[FontFeature.tabularFigures()]
      : null,
);
