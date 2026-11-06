import 'dart:io';

import 'package:flutter/widgets.dart';

/// The exact provider that `Image.file(..., cacheWidth: n)` builds.
///
/// This matters more than it looks. `Image.file` with a `cacheWidth` is keyed by
/// a [ResizeImage] wrapper, not by the [FileImage] underneath it, and the key
/// carries no modification time. Evicting the bare `FileImage` — the obvious
/// thing to write — therefore leaves the resized bitmap sitting in the cache,
/// and a page that was re-rendered on disk keeps showing its old pixels. That
/// is what made the filter chips look broken: the file was rewritten, the screen
/// was not.
ImageProvider pageImage(String path, {int cacheWidth = 1440}) =>
    ResizeImage.resizeIfNeeded(cacheWidth, null, FileImage(File(path)));

/// Drops [path] from the image cache so the next build reads the new bytes.
Future<void> evictPage(String path, {int cacheWidth = 1440}) =>
    pageImage(path, cacheWidth: cacheWidth).evict();
