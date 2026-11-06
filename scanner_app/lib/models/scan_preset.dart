/// Enhancement presets offered in the page editor.
///
/// [none] means "as the scanner returned it" — ML Kit already applies the
/// filter the user picked during capture.
enum ScanPreset {
  none('As scanned'),
  // The stored id stays `auto` so existing library JSON keeps loading; only
  // the visible name changed, because "Auto" undersold what it does.
  auto('Enhanced'),
  lighten('Lighten'),
  grayscale('Gray'),
  blackWhite('B&W');

  const ScanPreset(this.label);

  final String label;

  static ScanPreset fromName(String? name) {
    for (final ScanPreset preset in ScanPreset.values) {
      if (preset.name == name) {
        return preset;
      }
    }
    return ScanPreset.none;
  }
}
