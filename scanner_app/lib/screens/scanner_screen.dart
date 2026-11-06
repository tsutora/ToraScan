import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/scan_capture.dart';
import '../models/scan_mode.dart';
import '../services/scan_processor.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../theme/tora_widgets.dart';

/// The camera.
///
/// A single page closes the camera as soon as the shot is ready. A batch keeps
/// it open: every shot is auto-cropped, enhanced into a small preview, and
/// dropped into the corner stack, so the user can keep feeding pages without
/// ever leaving the viewfinder. Adjusting the crops happens after Done, in the
/// normal crop screen.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key, required this.mode});

  final ScanMode mode;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  Directory? _session;
  final List<ScanCapture> _pages = <ScanCapture>[];
  final ImagePicker _picker = ImagePicker();

  bool _starting = true;
  bool _capturing = false;
  bool _importing = false;
  bool _torch = false;
  int _shot = 0;

  /// True once the pages were returned to the caller; until then the session
  /// folder is only cache and is removed on the way out.
  bool _handedOff = false;
  String? _error;

  ToraPalette get _p => ToraThemeScope.of(context).family.dark;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    // A session that was never handed back — the user backed out of the
    // scanner — leaves nothing worth keeping, so its frames go with it.
    final Directory? session = _session;
    if (!_handedOff && session != null) {
      unawaited(() async {
        try {
          await session.delete(recursive: true);
        } catch (_) {
          // The system cleans its own cache eventually.
        }
      }());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // The camera is a system resource; give it back while the app is away.
      _camera?.dispose();
      _camera = null;
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      _start();
    }
  }

  Future<void> _start() async {
    if (mounted) {
      setState(() {
        _starting = true;
        _error = null;
      });
    }
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera found');
      }
      final CameraDescription description = cameras.firstWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final CameraController controller = CameraController(
        description,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _camera = controller;
      _torch = false;
    } on CameraException catch (error) {
      _error = switch (error.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' => 'Camera access is needed to scan.',
        _ => 'Camera unavailable.',
      };
    } catch (_) {
      _error = 'Camera unavailable.';
    }
    if (mounted) {
      setState(() => _starting = false);
    }
  }

  Future<Directory> _ensureSession() async {
    final Directory? existing = _session;
    if (existing != null) {
      return existing;
    }
    final Directory cache = await getTemporaryDirectory();
    final Directory dir = Directory(
      '${cache.path}${Platform.pathSeparator}capture'
      '${Platform.pathSeparator}${DateTime.now().microsecondsSinceEpoch}',
    );
    await dir.create(recursive: true);
    _session = dir;
    return dir;
  }

  Future<void> _capture() async {
    final CameraController? camera = _camera;
    if (_capturing ||
        _importing ||
        camera == null ||
        !camera.value.isInitialized) {
      return;
    }

    setState(() => _capturing = true);
    final Stopwatch timer = Stopwatch()..start();
    try {
      final Directory dir = await _ensureSession();
      final XFile shot = await camera.takePicture();
      if (kDebugMode) {
        debugPrint('TORA capture ${timer.elapsedMilliseconds} ms');
      }
      _shot++;

      final String stamp = _shot.toString().padLeft(2, '0');
      final String raw = '${dir.path}${Platform.pathSeparator}raw_$stamp.jpg';
      final String thumb =
          '${dir.path}${Platform.pathSeparator}thumb_$stamp.jpg';

      await File(shot.path).copy(raw);
      try {
        await File(shot.path).delete();
      } catch (_) {
        // The camera cache is cleaned up by the system anyway.
      }

      final ScanCapture capture = await ScanProcessor.capture(
        rawPath: raw,
        thumbPath: thumb,
      );
      if (kDebugMode) {
        debugPrint('TORA prepared ${timer.elapsedMilliseconds} ms');
      }
      if (!mounted) {
        return;
      }

      if (widget.mode == ScanMode.single) {
        _handedOff = true;
        Navigator.of(context).pop(<ScanCapture>[capture]);
        return;
      }
      setState(() => _pages.add(capture));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not take the picture. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
    }
  }

  /// Adds pages the user already has.
  ///
  /// Single page means exactly one: the chosen image becomes the session and
  /// the scanner closes, just like the shutter. A batch appends as many as were
  /// picked to the corner stack. Either way the image goes through the same
  /// normalise-and-detect step as a camera frame, so the crop screen and the
  /// filters behave identically.
  Future<void> _importGallery() async {
    if (_importing || _capturing) {
      return;
    }

    setState(() => _importing = true);
    try {
      final List<XFile> files;
      if (widget.mode == ScanMode.single) {
        final XFile? one = await _picker.pickImage(source: ImageSource.gallery);
        files = one == null ? <XFile>[] : <XFile>[one];
      } else {
        files = await _picker.pickMultiImage();
      }

      if (files.isEmpty) {
        return;
      }
      if (!mounted) {
        return;
      }

      final Directory dir = await _ensureSession();
      for (final XFile file in files) {
        _shot++;
        final String stamp = _shot.toString().padLeft(2, '0');
        final ScanCapture capture = await ScanProcessor.prepare(
          sourcePath: file.path,
          rawPath: '${dir.path}${Platform.pathSeparator}raw_$stamp.jpg',
          thumbPath: '${dir.path}${Platform.pathSeparator}thumb_$stamp.jpg',
        );
        if (!mounted) {
          return;
        }

        if (widget.mode == ScanMode.single) {
          _handedOff = true;
          Navigator.of(context).pop(<ScanCapture>[capture]);
          return;
        }
        setState(() => _pages.add(capture));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not import those images. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _toggleTorch() async {
    final CameraController? camera = _camera;
    if (camera == null) {
      return;
    }
    try {
      await camera.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
      if (mounted) {
        setState(() => _torch = !_torch);
      }
    } on CameraException {
      // Some cameras have no torch; the shot still works without it.
    }
  }

  void _done() {
    if (_pages.isEmpty || _importing) {
      return;
    }
    _handedOff = true;
    Navigator.of(context).pop(List<ScanCapture>.from(_pages));
  }

  Future<void> _close() async {
    if (_importing) {
      return;
    }
    if (_pages.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Discard these pages?'),
        content: Text(
          '${_pages.length} ${_pages.length == 1 ? 'page has' : 'pages have'} '
          'not been saved yet.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep scanning'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _review() async {
    if (_pages.isEmpty) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _p.surface,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheet) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        ToraLabel('Pages', color: _p.ink),
                        const SizedBox(width: 10),
                        ToraMicro('${_pages.length}', color: _p.inkFaint),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('DONE'),
                        ),
                      ],
                    ),
                    ToraRule(),
                    SizedBox(
                      height: 300,
                      child: _pages.isEmpty
                          ? Center(
                              child: ToraMicro(
                                'No pages left',
                                color: _p.inkFaint,
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.only(top: 12),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    childAspectRatio: 0.72,
                                  ),
                              itemCount: _pages.length,
                              itemBuilder: (BuildContext context, int index) {
                                return _PageThumb(
                                  page: _pages[index],
                                  onDelete: () {
                                    setSheet(() => _pages.removeAt(index));
                                    setState(() {});
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark(_p),
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _viewfinder(),
              IgnorePointer(
                child: CustomPaint(
                  painter: _FramePainter(
                    color: _p.accent,
                    aspect: _previewAspect,
                  ),
                ),
              ),
              _topBar(),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _viewfinder() {
    final CameraController? camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: _starting
              ? const CircularProgressIndicator()
              : _ErrorView(
                  message: _error ?? 'Camera unavailable.',
                  onRetry: _start,
                ),
        ),
      );
    }

    // CameraPreview already carries the sensor's aspect ratio, so it is simply
    // centred at the largest size that fits. Covering the screen instead — the
    // obvious thing, and what this used to do — scales a 3:4 frame up to fill a
    // 9:20.5 screen, which magnifies the image ~1.8x and throws away the outer
    // 40% of the width. That both looks zoomed in and lies about the framing:
    // the photo would include everything the preview had cut off.
    return ColoredBox(
      color: Colors.black,
      child: Center(child: CameraPreview(camera)),
    );
  }

  /// Portrait width/height of the preview, for the bracket overlay.
  double get _previewAspect {
    final CameraController? camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      return 3 / 4;
    }
    final double ratio = camera.value.aspectRatio;
    if (ratio <= 0) {
      return 3 / 4;
    }
    return 1 / ratio;
  }

  Widget _topBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.black.withValues(alpha: 0.62),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: _close,
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, size: 22),
                  color: Colors.white,
                ),
                const Spacer(),
                ToraMicro(
                  widget.mode == ScanMode.batch
                      ? 'Batch${_pages.isEmpty ? '' : ' · ${_pages.length}'}'
                      : 'Single',
                  color: Colors.white70,
                ),
                const Spacer(),
                IconButton(
                  onPressed: _importing ? null : _importGallery,
                  tooltip: 'Import images',
                  icon: _importing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.photo_library_outlined, size: 21),
                  color: Colors.white,
                ),
                IconButton(
                  onPressed: _toggleTorch,
                  tooltip: 'Light',
                  icon: Icon(
                    _torch ? Icons.flash_on : Icons.flash_off,
                    size: 21,
                  ),
                  color: _torch ? _p.accent : Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.only(top: 46),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[
              Colors.black.withValues(alpha: 0.86),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: SizedBox(
              height: 84,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  SizedBox(
                    width: 84,
                    child: _pages.isEmpty ? null : _thumbButton(),
                  ),
                  _shutter(),
                  SizedBox(
                    width: 84,
                    child: widget.mode == ScanMode.batch ? _doneButton() : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: _review,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              width: 58,
              height: 76,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: ToraShape.tag,
                border: Border.all(color: Colors.white54, width: 1.5),
              ),
              child: Image.file(
                File(_pages.last.thumbPath),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xFF1A1A1A)),
              ),
            ),
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _p.accent,
                  borderRadius: ToraShape.tag,
                ),
                child: Text(
                  '${_pages.length}',
                  style: toraType(
                    10,
                    FontWeight.w800,
                    tracking: 0.4,
                    color: _p.onAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shutter() {
    return GestureDetector(
      onTap: _capture,
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: _capturing ? 54 : 58,
            height: _capturing ? 54 : 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _capturing ? Colors.white24 : Colors.white,
            ),
            child: _capturing
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black54,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _doneButton() {
    final bool ready = _pages.isNotEmpty && !_capturing;
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: ready ? _done : null,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white30,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'DONE',
              style: toraType(
                11,
                FontWeight.w800,
                tracking: 1.4,
                color: ready ? Colors.white : Colors.white30,
              ),
            ),
            const SizedBox(height: 2),
            ToraMicro(
              _pages.isEmpty
                  ? 'No pages'
                  : '${_pages.length} ${_pages.length == 1 ? 'page' : 'pages'}',
              color: ready ? Colors.white54 : Colors.white24,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.no_photography_outlined,
            color: Colors.white54,
            size: 32,
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _PageThumb extends StatelessWidget {
  const _PageThumb({required this.page, required this.onDelete});

  final ScanCapture page;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned.fill(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: ToraShape.tag,
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: page.thumbPath.isEmpty
                ? const ColoredBox(color: Color(0xFF1A1A1A))
                : Image.file(
                    File(page.thumbPath),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Color(0xFF1A1A1A)),
                  ),
          ),
        ),
        Positioned(
          top: -7,
          right: -7,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFF16181B),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// Four corner brackets: enough of a guide without covering the page.
///
/// The brackets hug the letterboxed preview, not the screen, so they frame
/// exactly what the camera will capture.
class _FramePainter extends CustomPainter {
  _FramePainter({required this.color, required this.aspect});

  final Color color;

  /// Portrait width/height of the preview.
  final double aspect;

  @override
  void paint(Canvas canvas, Size size) {
    const double side = 26;
    const double inset = 14;

    double width = size.width;
    double height = width / aspect;
    if (height > size.height) {
      height = size.height;
      width = height * aspect;
    }
    final Rect preview = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: width,
      height: height,
    );
    final Rect rect = preview.deflate(inset);
    if (rect.width <= 0 || rect.height <= 0) {
      return;
    }

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(side, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft + const Offset(0, side), paint);

    canvas.drawLine(
      rect.topRight,
      rect.topRight + const Offset(-side, 0),
      paint,
    );
    canvas.drawLine(
      rect.topRight,
      rect.topRight + const Offset(0, side),
      paint,
    );

    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + const Offset(side, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + const Offset(0, -side),
      paint,
    );

    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(-side, 0),
      paint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(0, -side),
      paint,
    );
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.aspect != aspect;
}
