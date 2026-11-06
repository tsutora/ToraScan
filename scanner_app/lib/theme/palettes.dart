import 'package:flutter/material.dart';

import 'app_theme.dart';

/// One selectable theme: a pastel light set and its deep counterpart.
///
/// Every family is built from the same shape — a tinted paper background, a
/// white surface, near-black ink, hairlines, and one accent — so the layout and
/// the type ramp never change, only the colour.
///
/// The dark set always puts the page on pure black; only the surfaces and the
/// accent carry the family's colour. A tinted background was uncomfortable to
/// read on at night, which is exactly when a scanner gets used.
class ToraPaletteFamily {
  const ToraPaletteFamily({
    required this.id,
    required this.label,
    required this.light,
    required this.dark,
  });

  final String id;
  final String label;
  final ToraPalette light;
  final ToraPalette dark;

  /// The accent, used for the swatch in the theme drawer.
  Color get swatch => light.accent;
}

class ToraPalettes {
  const ToraPalettes._();

  static const ToraPaletteFamily neutral = ToraPaletteFamily(
    id: 'neutral',
    label: 'Paper',
    light: ToraPalette.light,
    dark: ToraPalette.dark,
  );

  static const ToraPaletteFamily mint = ToraPaletteFamily(
    id: 'mint',
    label: 'Mint',
    light: ToraPalette(
      bg: Color(0xFFEDF5F0),
      surface: Color(0xFFFFFFFF),
      surface2: Color(0xFFE6F0EA),
      ink: Color(0xFF14201A),
      inkSoft: Color(0xFF55635B),
      inkFaint: Color(0xFF8A968F),
      line: Color(0xFFDCE6E0),
      lineStrong: Color(0xFFC3D2C9),
      accent: Color(0xFF3E8E6B),
      accentText: Color(0xFF2A6A4E),
      accentWash: Color(0xFFDFF0E7),
      onAccent: Color(0xFFFFFFFF),
    ),
    dark: ToraPalette(
      bg: Color(0xFF000000),
      surface: Color(0xFF152019),
      surface2: Color(0xFF1B2820),
      ink: Color(0xFFEAF2ED),
      inkSoft: Color(0xFF9AA8A0),
      inkFaint: Color(0xFF6C7A72),
      line: Color(0xFF24312A),
      lineStrong: Color(0xFF35443C),
      accent: Color(0xFF7FD3AC),
      accentText: Color(0xFF94E0BC),
      accentWash: Color(0xFF16261E),
      onAccent: Color(0xFF082018),
    ),
  );

  static const ToraPaletteFamily lilac = ToraPaletteFamily(
    id: 'lilac',
    label: 'Lilac',
    light: ToraPalette(
      bg: Color(0xFFF3F0FA),
      surface: Color(0xFFFFFFFF),
      surface2: Color(0xFFEDE8F6),
      ink: Color(0xFF1A1626),
      inkSoft: Color(0xFF5D5770),
      inkFaint: Color(0xFF918BA3),
      line: Color(0xFFE3DEF0),
      lineStrong: Color(0xFFCDC5E2),
      accent: Color(0xFF6C5AA8),
      accentText: Color(0xFF53438A),
      accentWash: Color(0xFFE9E3F7),
      onAccent: Color(0xFFFFFFFF),
    ),
    dark: ToraPalette(
      bg: Color(0xFF000000),
      surface: Color(0xFF191622),
      surface2: Color(0xFF201C2C),
      ink: Color(0xFFEFEBF8),
      inkSoft: Color(0xFFA29BB5),
      inkFaint: Color(0xFF726C84),
      line: Color(0xFF2A2537),
      lineStrong: Color(0xFF3C3550),
      accent: Color(0xFFB7A6E8),
      accentText: Color(0xFFC9BCF2),
      accentWash: Color(0xFF211B31),
      onAccent: Color(0xFF150F26),
    ),
  );

  static const ToraPaletteFamily sky = ToraPaletteFamily(
    id: 'sky',
    label: 'Sky',
    light: ToraPalette(
      bg: Color(0xFFEEF4FA),
      surface: Color(0xFFFFFFFF),
      surface2: Color(0xFFE6EFF8),
      ink: Color(0xFF121A23),
      inkSoft: Color(0xFF54616E),
      inkFaint: Color(0xFF8894A1),
      line: Color(0xFFDCE6F0),
      lineStrong: Color(0xFFC2D2E2),
      accent: Color(0xFF3B72A8),
      accentText: Color(0xFF2A567F),
      accentWash: Color(0xFFE0EDF9),
      onAccent: Color(0xFFFFFFFF),
    ),
    dark: ToraPalette(
      bg: Color(0xFF000000),
      surface: Color(0xFF141C23),
      surface2: Color(0xFF1A242D),
      ink: Color(0xFFEAF0F6),
      inkSoft: Color(0xFF97A4B1),
      inkFaint: Color(0xFF69747F),
      line: Color(0xFF222D37),
      lineStrong: Color(0xFF33414D),
      accent: Color(0xFF7FB6E4),
      accentText: Color(0xFF97C7EE),
      accentWash: Color(0xFF14222E),
      onAccent: Color(0xFF06141F),
    ),
  );

  static const ToraPaletteFamily peach = ToraPaletteFamily(
    id: 'peach',
    label: 'Peach',
    light: ToraPalette(
      bg: Color(0xFFFDF2EC),
      surface: Color(0xFFFFFFFF),
      surface2: Color(0xFFFAE9E0),
      ink: Color(0xFF211611),
      inkSoft: Color(0xFF6B574D),
      inkFaint: Color(0xFF9C877C),
      line: Color(0xFFEFDED4),
      lineStrong: Color(0xFFDEC6B8),
      accent: Color(0xFFC0603A),
      accentText: Color(0xFF9A4728),
      accentWash: Color(0xFFF9E4D9),
      onAccent: Color(0xFFFFFFFF),
    ),
    dark: ToraPalette(
      bg: Color(0xFF000000),
      surface: Color(0xFF1E1714),
      surface2: Color(0xFF251C18),
      ink: Color(0xFFF6EDE8),
      inkSoft: Color(0xFFB0A098),
      inkFaint: Color(0xFF7D6E66),
      line: Color(0xFF2E241F),
      lineStrong: Color(0xFF41332C),
      accent: Color(0xFFEFA283),
      accentText: Color(0xFFF7BBA2),
      accentWash: Color(0xFF2A1B15),
      onAccent: Color(0xFF1F0E07),
    ),
  );

  static const ToraPaletteFamily sand = ToraPaletteFamily(
    id: 'sand',
    label: 'Sand',
    light: ToraPalette(
      bg: Color(0xFFF7F4EC),
      surface: Color(0xFFFFFFFF),
      surface2: Color(0xFFF0EBDF),
      ink: Color(0xFF1E1B14),
      inkSoft: Color(0xFF605A4C),
      inkFaint: Color(0xFF938D7E),
      line: Color(0xFFE7E1D3),
      lineStrong: Color(0xFFD3CAB6),
      accent: Color(0xFF8C7238),
      accentText: Color(0xFF6B5628),
      accentWash: Color(0xFFF1E9D6),
      onAccent: Color(0xFFFFFFFF),
    ),
    dark: ToraPalette(
      bg: Color(0xFF000000),
      surface: Color(0xFF1D1A14),
      surface2: Color(0xFF252119),
      ink: Color(0xFFF2EEE3),
      inkSoft: Color(0xFFABA492),
      inkFaint: Color(0xFF7C7666),
      line: Color(0xFF2E2A21),
      lineStrong: Color(0xFF413B2F),
      accent: Color(0xFFD6B97E),
      accentText: Color(0xFFE3CA98),
      accentWash: Color(0xFF262015),
      onAccent: Color(0xFF1A1408),
    ),
  );

  static const List<ToraPaletteFamily> all = <ToraPaletteFamily>[
    neutral,
    mint,
    lilac,
    sky,
    peach,
    sand,
  ];

  static ToraPaletteFamily byId(String? id) {
    for (final ToraPaletteFamily family in all) {
      if (family.id == id) {
        return family;
      }
    }
    return neutral;
  }
}
