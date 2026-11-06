import 'crop_quad.dart';
import 'save_quality.dart';
import 'scan_preset.dart';

/// A single scanned document: its pages (JPEG files), the per-page
/// enhancement preset, the per-page crop, and the generated PDF.
class ScanDocument {
  /// Every parallel list is copied into a growable list of this document's
  /// own. The library hands over lists it does not own — a JSON decode, a
  /// fixed-length `filled` fallback, a `.cast()` view — and editing a page
  /// reorders and replaces entries in place. Owning growable copies here means
  /// no caller can hand us a list that throws halfway through an edit.
  ScanDocument({
    required this.id,
    required this.title,
    required List<String> pagePaths,
    required List<String> originalPaths,
    required List<ScanPreset> pagePresets,
    required this.pdfPath,
    required this.createdAt,
    List<CropQuad>? pageCrops,
    this.folderId,
    this.quality = SaveQuality.original,
    DateTime? updatedAt,
  }) : pagePaths = List<String>.of(pagePaths),
       originalPaths = List<String>.of(originalPaths),
       pagePresets = List<ScanPreset>.of(pagePresets),
       pageCrops = List<CropQuad>.of(
         pageCrops ?? List<CropQuad>.filled(pagePaths.length, CropQuad.full()),
       ),
       updatedAt = updatedAt ?? createdAt;

  final String id;
  String title;

  /// Working pages, in display order. These are what the PDF is built from.
  final List<String> pagePaths;

  /// Untouched copies straight from the scanner, used as the enhancement
  /// source so presets can be switched without compounding artefacts.
  final List<String> originalPaths;

  /// Preset applied to each working page, parallel to [pagePaths].
  final List<ScanPreset> pagePresets;

  /// Crop applied to each working page, parallel to [pagePaths].
  final List<CropQuad> pageCrops;

  /// Folder this document belongs to, or null when unfiled.
  String? folderId;

  /// The compression the pages were rendered at. New renders made by the
  /// editor use the same setting, so editing a small scan does not silently
  /// replace it with a large one.
  SaveQuality quality;

  /// Path of the generated PDF. Mutable because the file follows the scan's
  /// name and its folder inside the visible library tree.
  String pdfPath;

  final DateTime createdAt;
  DateTime updatedAt;

  int get pageCount => pagePaths.length;

  void reorderPages(int oldIndex, int newIndex) {
    _move(pagePaths, oldIndex, newIndex);
    _move(originalPaths, oldIndex, newIndex);
    _move(pagePresets, oldIndex, newIndex);
    _move(pageCrops, oldIndex, newIndex);
    touch();
  }

  void removePage(int index) {
    pagePaths.removeAt(index);
    originalPaths.removeAt(index);
    pagePresets.removeAt(index);
    pageCrops.removeAt(index);
    touch();
  }

  void touch() => updatedAt = DateTime.now();

  /// Rearranges every parallel list according to [order], where
  /// `order[i]` is the current index that should become position `i`.
  void applyPageOrder(List<int> order) {
    final List<String> pages = <String>[
      for (final int i in order) pagePaths[i],
    ];
    final List<String> originals = <String>[
      for (final int i in order) originalPaths[i],
    ];
    final List<ScanPreset> presets = <ScanPreset>[
      for (final int i in order) pagePresets[i],
    ];
    final List<CropQuad> crops = <CropQuad>[
      for (final int i in order) pageCrops[i],
    ];
    pagePaths
      ..clear()
      ..addAll(pages);
    originalPaths
      ..clear()
      ..addAll(originals);
    pagePresets
      ..clear()
      ..addAll(presets);
    pageCrops
      ..clear()
      ..addAll(crops);
    touch();
  }

  static void _move<T>(List<T> items, int oldIndex, int newIndex) {
    final T item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'pagePaths': pagePaths,
    'originalPaths': originalPaths,
    'pagePresets': pagePresets.map((ScanPreset p) => p.name).toList(),
    'pageCrops': pageCrops.map((CropQuad q) => q.toJson()).toList(),
    'folderId': folderId,
    'quality': quality.name,
    'pdfPath': pdfPath,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ScanDocument.fromJson(Map<String, dynamic> json) {
    final List<String> pages = (json['pagePaths'] as List<dynamic>)
        .cast<String>();
    final List<String> originals =
        (json['originalPaths'] as List<dynamic>?)?.cast<String>() ??
        List<String>.from(pages);
    final List<dynamic>? presetNames = json['pagePresets'] as List<dynamic>?;
    final List<dynamic>? cropJson = json['pageCrops'] as List<dynamic>?;

    return ScanDocument(
      id: json['id'] as String,
      title: json['title'] as String,
      pagePaths: pages,
      // A document written by an older build may have fewer originals.
      originalPaths: originals.length == pages.length
          ? originals
          : List<String>.from(pages),
      pagePresets: presetNames != null && presetNames.length == pages.length
          ? presetNames
                .map((dynamic e) => ScanPreset.fromName(e as String?))
                .toList()
          : List<ScanPreset>.filled(pages.length, ScanPreset.none),
      pageCrops: cropJson != null && cropJson.length == pages.length
          ? cropJson
                .map(
                  (dynamic e) => CropQuad.fromJson(e as Map<String, dynamic>?),
                )
                .toList()
          : List<CropQuad>.filled(pages.length, CropQuad.full()),
      folderId: json['folderId'] as String?,
      quality: SaveQuality.fromName(json['quality'] as String?),
      pdfPath: json['pdfPath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}
