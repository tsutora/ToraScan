import 'crop_quad.dart';
import 'scan_document.dart';
import 'scan_preset.dart';

/// One page while a saved document is being edited.
///
/// The page keeps the file it came from and, separately, an optional fresh
/// render. That split is what lets a filter be tried and reverted without ever
/// touching the library: the render only becomes the page when the edit is
/// saved.
class DraftPage {
  DraftPage({
    required this.pagePath,
    required this.originalPath,
    required this.preset,
    required this.sourcePreset,
    required this.crop,
    this.renderPath,
    this.isNew = false,
    this.tempOriginalPath,
  });

  /// The page file in the library. For a page that arrived from a merged PDF
  /// this is a temporary file until the edit is saved.
  final String pagePath;

  /// The untouched source a different filter is rendered from.
  final String originalPath;

  ScanPreset preset;

  /// The preset the page had when editing began. Choosing it again drops the
  /// render instead of keeping a redundant one.
  final ScanPreset sourcePreset;

  final CropQuad crop;

  /// A fresh render that replaces [pagePath] when the edit is saved.
  String? renderPath;

  /// True for a page that arrived from a merged PDF and has no library files.
  final bool isNew;

  /// For a new page, the temporary file to copy into `orig/` on save.
  final String? tempOriginalPath;

  /// What the editor shows: the pending render, or the page on disk.
  String get displayPath => renderPath ?? pagePath;

  bool get changed => renderPath != null || isNew;
}

/// An in-memory edit of a saved document.
///
/// Nothing here writes to the library. The editor renders changed pages into a
/// temporary folder and this object records what should replace what. Saving is
/// an explicit, confirmed step; cancelling deletes the folder and leaves every
/// file exactly as it was.
class DocumentDraft {
  DocumentDraft._(this.pages);

  factory DocumentDraft.from(ScanDocument doc) {
    return DocumentDraft._(<DraftPage>[
      for (int i = 0; i < doc.pagePaths.length; i++)
        DraftPage(
          pagePath: doc.pagePaths[i],
          originalPath: doc.originalPaths[i],
          preset: doc.pagePresets[i],
          sourcePreset: doc.pagePresets[i],
          crop: doc.pageCrops[i],
        ),
    ]);
  }

  final List<DraftPage> pages;

  bool _dirty = false;

  /// True once anything that would change the saved document has been done.
  bool get dirty => _dirty;

  int get length => pages.length;

  /// Rearranges the pages; `order[i]` is the current index that becomes
  /// position `i`. Every part of a page moves with it, so a page can never end
  /// up wearing another page's preset.
  void applyOrder(List<int> order) {
    final List<DraftPage> reordered = <DraftPage>[
      for (final int i in order) pages[i],
    ];
    pages
      ..clear()
      ..addAll(reordered);
    _dirty = true;
  }

  /// Appends pages imported from a merged PDF.
  void addAll(List<DraftPage> more) {
    if (more.isEmpty) {
      return;
    }
    pages.addAll(more);
    _dirty = true;
  }

  /// Points [index] at a fresh render, or back at the library file when
  /// [renderPath] is null.
  void setRender(
    int index, {
    required ScanPreset preset,
    required String? renderPath,
  }) {
    final DraftPage page = pages[index];
    page.preset = preset;
    page.renderPath = renderPath;
    _dirty = true;
  }

  /// Marks the draft as changed after a bulk operation that edited pages in
  /// place.
  void markDirty() => _dirty = true;
}
