import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_app/models/crop_quad.dart';
import 'package:scanner_app/models/document_draft.dart';
import 'package:scanner_app/models/scan_document.dart';
import 'package:scanner_app/models/scan_preset.dart';

CropQuad _quad(double inset) => CropQuad(
  tlX: inset,
  tlY: inset,
  trX: 1 - inset,
  trY: inset,
  brX: 1 - inset,
  brY: 1 - inset,
  blX: inset,
  blY: 1 - inset,
);

ScanDocument _document() => ScanDocument(
  id: 'doc',
  title: 'Doc',
  pagePaths: <String>['a.jpg', 'b.jpg', 'c.jpg'],
  originalPaths: <String>['oa.jpg', 'ob.jpg', 'oc.jpg'],
  pagePresets: <ScanPreset>[
    ScanPreset.auto,
    ScanPreset.grayscale,
    ScanPreset.blackWhite,
  ],
  pageCrops: <CropQuad>[_quad(0.1), _quad(0.2), _quad(0.3)],
  pdfPath: 'doc.pdf',
  createdAt: DateTime(2026, 11, 1),
);

void main() {
  test('a fresh draft is clean and copies every parallel list', () {
    final DocumentDraft draft = DocumentDraft.from(_document());

    expect(draft.length, 3);
    expect(draft.dirty, isFalse);
    expect(draft.pages[0].pagePath, 'a.jpg');
    expect(draft.pages[0].originalPath, 'oa.jpg');
    expect(draft.pages[0].preset, ScanPreset.auto);
    expect(draft.pages[0].sourcePreset, ScanPreset.auto);
    expect(draft.pages[0].crop.tlX, closeTo(0.1, 1e-9));
    expect(draft.pages[0].changed, isFalse);
    expect(draft.pages[0].displayPath, 'a.jpg');
  });

  test('reorder moves a page with its preset and crop', () {
    final DocumentDraft draft = DocumentDraft.from(_document());

    draft.applyOrder(<int>[2, 0, 1]);

    expect(draft.pages.map((DraftPage p) => p.pagePath), <String>[
      'c.jpg',
      'a.jpg',
      'b.jpg',
    ]);
    expect(draft.pages.map((DraftPage p) => p.originalPath), <String>[
      'oc.jpg',
      'oa.jpg',
      'ob.jpg',
    ]);
    expect(draft.pages.map((DraftPage p) => p.preset), <ScanPreset>[
      ScanPreset.blackWhite,
      ScanPreset.auto,
      ScanPreset.grayscale,
    ]);
    expect(draft.pages[1].crop.tlX, closeTo(0.1, 1e-9));
    expect(draft.pages[2].crop.tlX, closeTo(0.2, 1e-9));
    expect(draft.dirty, isTrue);
  });

  test('merged pages append to the draft and mark it dirty', () {
    final DocumentDraft draft = DocumentDraft.from(_document());

    draft.addAll(<DraftPage>[
      DraftPage(
        pagePath: 'merged.jpg',
        originalPath: 'merged.jpg',
        preset: ScanPreset.none,
        sourcePreset: ScanPreset.none,
        crop: CropQuad.full(),
        isNew: true,
        tempOriginalPath: 'merged.jpg',
      ),
    ]);

    expect(draft.length, 4);
    expect(draft.pages.last.pagePath, 'merged.jpg');
    expect(draft.pages.last.isNew, isTrue);
    expect(draft.pages.last.changed, isTrue);
    expect(draft.dirty, isTrue);
  });

  test('an empty merge changes nothing', () {
    final DocumentDraft draft = DocumentDraft.from(_document());

    draft.addAll(<DraftPage>[]);

    expect(draft.length, 3);
    expect(draft.dirty, isFalse);
  });

  test('a render replaces the page until it is cleared again', () {
    final DocumentDraft draft = DocumentDraft.from(_document());

    draft.setRender(0, preset: ScanPreset.grayscale, renderPath: 'render.jpg');
    expect(draft.pages[0].displayPath, 'render.jpg');
    expect(draft.pages[0].preset, ScanPreset.grayscale);
    expect(draft.pages[0].changed, isTrue);

    // Choosing the page's original filter again drops the render.
    draft.setRender(0, preset: ScanPreset.auto, renderPath: null);
    expect(draft.pages[0].displayPath, 'a.jpg');
    expect(draft.pages[0].preset, ScanPreset.auto);
    expect(draft.pages[0].changed, isFalse);
  });
}
