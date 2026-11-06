/// How much detail a saved scan keeps.
///
/// The page is rendered at [maxEdge] on its long side with an area-average
/// downscale (never a nearest-neighbour one, which aliases text), then encoded
/// at [jpegQuality]. The steps are deliberately gentle: even the smallest
/// setting keeps a scanned A4 legible, and the original capture is always kept
/// in `orig/`, so nothing is ever lost for good.
enum SaveQuality {
  original('Original', 'Full detail · largest file', 2400, 88),
  high('High', 'Crisp text · much smaller', 1800, 86),
  balanced('Balanced', 'Everyday scans · small file', 1440, 82),
  small('Small', 'Sharing · still readable', 1080, 76);

  const SaveQuality(
    this.label,
    this.description,
    this.maxEdge,
    this.jpegQuality,
  );

  final String label;
  final String description;
  final int maxEdge;
  final int jpegQuality;

  static SaveQuality fromName(String? name) {
    for (final SaveQuality quality in SaveQuality.values) {
      if (quality.name == name) {
        return quality;
      }
    }
    return SaveQuality.original;
  }
}
