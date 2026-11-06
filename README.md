# ToraScan

An Android document scanner that turns photos of paper into clean, readable pages and PDFs. Everything runs on the phone: no account, no ads, no watermark, no subscription, and no network permission at all.

Version 1.0.0 (`com.ownscan.scanner_app`) · Android 7.0+ (API 24)

## What it does

**Capture**
- Single page or a batch: the camera stays open while pages stack up, then they are cropped once.
- Automatic page-edge detection with 8 draggable corner points; a page can be rotated before cropping.
- Import from the gallery (JPG/PNG) or from an existing PDF. PDF pages are rasterised at 200 dpi onto a white background, one image per page.

**Clean up**
- Filters: **As scanned, Enhanced, Lighten, Gray, B&W**.
- Enhanced flattens uneven lighting and shadows, anchors paper at white, deepens ink and restores fine detail without a white halo around letters. Colour is kept: a pink form stays pink.
- Filters are chosen per page, with **Apply to all** for the whole document.
- Output quality: Original (2400 px, q88), High (1800 px, q86), Balanced (1440 px, q82), Small (1080 px, q76).

**Organise**
- The library is a real folder, `/storage/emulated/0/ToraScan`, readable by any file manager and over USB.
- Folders, with drag-to-reorder and an "All" sheet that lists every folder.
- Rename, Copy (duplicates the pages *and* the PDF), Delete, Share.
- One PDF per document, rebuilt whenever its pages change.
- Search by file name.

**Edit**
- Reorder pages, merge a PDF into the document, change the filter per page.
- Editing works on a draft: files are written only after Save and a confirmation. Backing out discards the draft and leaves the document exactly as it was.

## Flow

- Home (folders + all scans) → folder → document → editor.
- Capture: camera → crop → preview → name → save → share.
- Import: Single / Batch / From PDF → crop → preview → name → save.

## Build

Requirements: Flutter 3.x stable, Android SDK 36, JDK 17.

```bash
flutter pub get
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
```

Outputs land in `build/app/outputs/flutter-apk/`:

| APK | Size | Target |
| --- | --- | --- |
| `app-arm64-v8a-release.apk` | ~8.6 MB | most phones from 2016 onward |
| `app-armeabi-v7a-release.apk` | ~8.3 MB | older 32-bit devices |
| `app-x86_64-release.apk` | ~8.8 MB | emulators |

Use `flutter run` for a debug build. Release builds are currently signed with the debug keystore: they install over earlier builds of the same app, but are not ready for Play Store upload.

## Permissions

| Permission | Purpose |
| --- | --- |
| `CAMERA` | taking the page photos |
| `MANAGE_EXTERNAL_STORAGE` (API 30+) / `READ_EXTERNAL_STORAGE` + `WRITE_EXTERNAL_STORAGE` | writing the library into `/storage/emulated/0/ToraScan` |
| `RECORD_AUDIO` | declared by the camera plugin; the app never records audio |
| `ACCESS_NETWORK_STATE` | declared by a plugin; no data is sent |

The release manifest has **no `INTERNET` permission**, so the app cannot upload anything.

## Where files go

```
/storage/emulated/0/ToraScan/<Folder>/<Document>.pdf    shareable PDF
/storage/emulated/0/ToraScan/.library/<id>/orig/        untouched captures
/storage/emulated/0/ToraScan/.library/<id>/pages/       processed pages
/storage/emulated/0/ToraScan/.library/index.json        library index
```

`.library/` is the app's database. Copy it when backing up the folder, and leave it in place while the app is installed.

## Limits

- No OCR and no text search inside a document; search matches file names only.
- Portrait only.
- Android only.
- No cloud sync or accounts, by design.
