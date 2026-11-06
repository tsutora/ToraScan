import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/crop_quad.dart';

/// Finds the page inside a camera capture, so a batch shot can be cropped the
/// moment it is taken instead of waiting for the user to drag eight handles.
///
/// The approach is deliberately simple and predictable: the page is almost
/// always the largest bright *and colourless* region of the frame, so the image
/// is downscaled, each pixel is scored by brightness weighted by neutrality
/// (which is what separates white paper from a bright gold envelope or a wooden
/// desk), blurred (which also closes the holes that text punches in the paper),
/// split with Otsu's threshold, and the largest connected region is reduced to
/// its convex hull. The four extreme points of that hull are the corners.
///
/// It is a heuristic, not a guarantee. When the page cannot be separated from
/// its background — a white sheet on a white desk, a dark magazine on a dark
/// table — the full frame is returned and nothing is cropped, which is always
/// safe because the crop screen lets the user pull the edges in afterwards.
class AutoCrop {
  const AutoCrop._();

  /// The analysis runs on a small copy; the quad is normalized, so the result
  /// applies to the full-resolution capture.
  static const int analysisEdge = 220;

  /// Below this share of the frame the "page" is too small to be believable.
  static const double minCoverage = 0.18;

  /// Above this share of the frame the detection is probably the background.
  static const double maxCoverage = 0.99;

  /// How sharp a step the quad's border must sit on, as a fraction of full
  /// scale. A page border is a hard edge; a threshold that merely cut through
  /// the middle of a shadowed page leaves a smooth ramp well below this.
  static const double minEdgeScore = 0.05;

  /// How many of the largest bright regions are considered as page candidates.
  static const int candidates = 3;

  static Future<CropQuad> detect(String path) async {
    final Uint8List bytes = await File(path).readAsBytes();
    return compute(detectBytes, bytes);
  }

  /// The synchronous core, also used directly by tests.
  static CropQuad detectBytes(Uint8List bytes) {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return CropQuad.full();
    }
    return detectImage(img.bakeOrientation(decoded));
  }

  /// Detects the page in an already decoded (and upright) image.
  static CropQuad detectImage(img.Image source) {
    img.Image image = source;
    final int longest = image.width > image.height ? image.width : image.height;
    if (longest > analysisEdge) {
      image = image.width >= image.height
          ? img.copyResize(
              image,
              width: analysisEdge,
              interpolation: img.Interpolation.average,
            )
          : img.copyResize(
              image,
              height: analysisEdge,
              interpolation: img.Interpolation.average,
            );
    }

    final int w = image.width;
    final int h = image.height;
    if (w < 24 || h < 24) {
      return CropQuad.full();
    }

    // "Paperness": bright *and* neutral.
    //
    // Brightness alone cannot separate a white sheet from the things it is
    // usually photographed on — a gold manila envelope, a wooden desk, a
    // coloured folder are all as bright as the paper, so a luminance-only
    // threshold merges them and the detected quad wraps the background. Paper
    // is the one bright thing in the frame that is also nearly colourless, so
    // weighting brightness by neutrality pulls the page away from its
    // surroundings without any colour assumptions about the scene.
    final Uint8List paperness = Uint8List(w * h);
    final Uint8List luma = Uint8List(w * h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final img.Pixel p = image.getPixel(x, y);
        final int hi = math.max(
          p.r.toInt(),
          math.max(p.g.toInt(), p.b.toInt()),
        );
        final int lo = math.min(
          p.r.toInt(),
          math.min(p.g.toInt(), p.b.toInt()),
        );
        final double saturation = hi <= 0 ? 0 : (hi - lo) / hi;
        final double neutral = ((0.34 - saturation) / 0.18).clamp(0.0, 1.0);
        final double value = p.r * 0.299 + p.g * 0.587 + p.b * 0.114;
        paperness[y * w + x] = (value * neutral).round().clamp(0, 255).toInt();
        luma[y * w + x] = value.round().clamp(0, 255).toInt();
      }
    }

    // Blurring closes the letter-sized holes so the paper reads as one blob.
    final Uint8List paperBlur = _boxBlur(paperness, w, h, 2);

    // A page is not always white. A pink form, a yellow folder or a coloured
    // cover scores near zero on paperness, so pure brightness is analysed too
    // and the edge score decides which candidate really sits on a paper edge.
    final Uint8List lumaBlur = _boxBlur(luma, w, h, 2);

    CropQuad? best;
    double bestScore = 0;

    void consider(Uint8List blurred) {
      // A single global threshold is not enough. The histogram of a real
      // capture has three humps — shadow, whatever the page is lying on, and
      // the page itself — and Otsu then splits between the darkest two, so a
      // bright desk or floor tile joins the page. Rather than guess which hump
      // is the page, try a short ladder of thresholds and let [_edgeScore]
      // decide: the right threshold is the one whose quad actually sits on the
      // page's border.
      final List<int> histogram = List<int>.filled(256, 0);
      for (final int value in blurred) {
        histogram[value]++;
      }
      final int base = _otsu(blurred);
      final int bright = _percentile(histogram, blurred.length, 95);
      final List<int> ladder = <int>{
        base,
        base + ((bright - base) * 0.25).round(),
        base + ((bright - base) * 0.45).round(),
        base + ((bright - base) * 0.65).round(),
        base + ((bright - base) * 0.82).round(),
      }.where((int t) => t > 0).toList()..sort();

      for (final int threshold in ladder) {
        final Uint8List mask = Uint8List(w * h);
        for (int i = 0; i < mask.length; i++) {
          mask[i] = blurred[i] >= threshold ? 1 : 0;
        }
        for (final List<math.Point<int>> boundary in _largestBoundaries(
          mask,
          w,
          h,
        )) {
          if (boundary.length < 8) {
            continue;
          }
          final List<math.Point<int>> hull = _convexHull(boundary);
          if (hull.length < 4) {
            continue;
          }

          final math.Point<int> tl = _extreme(
            hull,
            (math.Point<int> p) => (p.x + p.y).toDouble(),
            largest: false,
          );
          final math.Point<int> br = _extreme(
            hull,
            (math.Point<int> p) => (p.x + p.y).toDouble(),
            largest: true,
          );
          final math.Point<int> tr = _extreme(
            hull,
            (math.Point<int> p) => (p.x - p.y).toDouble(),
            largest: true,
          );
          final math.Point<int> bl = _extreme(
            hull,
            (math.Point<int> p) => (p.x - p.y).toDouble(),
            largest: false,
          );

          final List<math.Point<int>> quad = <math.Point<int>>[tl, tr, br, bl];
          final double area = _polygonArea(quad).abs();
          final double coverage = area / (w * h);
          if (coverage < minCoverage || coverage > maxCoverage) {
            continue;
          }
          if (!_isConvex(quad)) {
            continue;
          }

          final double score = _edgeScore(luma, w, h, quad);
          if (_interiorLuma(luma, w, h, quad) < 120) {
            continue;
          }
          if (score > bestScore) {
            bestScore = score;
            best = CropQuad(
              tlX: tl.x / (w - 1),
              tlY: tl.y / (h - 1),
              trX: tr.x / (w - 1),
              trY: tr.y / (h - 1),
              brX: br.x / (w - 1),
              brY: br.y / (h - 1),
              blX: bl.x / (w - 1),
              blY: bl.y / (h - 1),
            );
          }
        }
      }
    }

    consider(paperBlur);
    consider(lumaBlur);

    // Below this the "edge" is a smooth ramp rather than the step a page
    // border makes, so there is no page to find and the frame is left whole.
    if (best == null || bestScore < minEdgeScore) {
      return CropQuad.full();
    }
    // The blur moves the thresholded border a pixel or two inside the true
    // edge. Growing the quad by a hair keeps the page's own margin instead of
    // shaving a strip of text off the capture.
    return _expand(best!, 0.008);
  }

  // ------------------------------------------------------------- internals

  static math.Point<int> _extreme(
    List<math.Point<int>> hull,
    double Function(math.Point<int>) score, {
    required bool largest,
  }) {
    math.Point<int> best = hull.first;
    double bestScore = score(best);
    for (final math.Point<int> point in hull.skip(1)) {
      final double value = score(point);
      if (largest ? value > bestScore : value < bestScore) {
        best = point;
        bestScore = value;
      }
    }
    return best;
  }

  /// Boundary pixels of the largest bright regions, biggest first.
  static List<List<math.Point<int>>> _largestBoundaries(
    Uint8List mask,
    int w,
    int h,
  ) {
    final Int32List labels = Int32List(w * h)..fillRange(0, w * h, -1);
    final Int32List queue = Int32List(w * h);

    final List<int> sizes = <int>[];
    int nextLabel = 0;

    for (int start = 0; start < mask.length; start++) {
      if (mask[start] == 0 || labels[start] != -1) {
        continue;
      }

      final int label = nextLabel++;
      int head = 0;
      int tail = 0;
      int size = 0;
      queue[tail++] = start;
      labels[start] = label;

      while (head < tail) {
        final int index = queue[head++];
        size++;
        final int x = index % w;
        final int y = index ~/ w;

        if (x > 0) {
          final int n = index - 1;
          if (mask[n] == 1 && labels[n] == -1) {
            labels[n] = label;
            queue[tail++] = n;
          }
        }
        if (x + 1 < w) {
          final int n = index + 1;
          if (mask[n] == 1 && labels[n] == -1) {
            labels[n] = label;
            queue[tail++] = n;
          }
        }
        if (y > 0) {
          final int n = index - w;
          if (mask[n] == 1 && labels[n] == -1) {
            labels[n] = label;
            queue[tail++] = n;
          }
        }
        if (y + 1 < h) {
          final int n = index + w;
          if (mask[n] == 1 && labels[n] == -1) {
            labels[n] = label;
            queue[tail++] = n;
          }
        }
      }

      sizes.add(size);
    }

    if (sizes.isEmpty) {
      return const <List<math.Point<int>>>[];
    }

    final List<int> order = List<int>.generate(sizes.length, (int i) => i)
      ..sort((int a, int b) => sizes[b].compareTo(sizes[a]));

    final List<List<math.Point<int>>> boundaries = <List<math.Point<int>>>[];
    for (final int label in order.take(candidates)) {
      final List<math.Point<int>> boundary = <math.Point<int>>[];
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final int index = y * w + x;
          if (labels[index] != label) {
            continue;
          }
          final bool edge =
              x == 0 ||
              y == 0 ||
              x == w - 1 ||
              y == h - 1 ||
              labels[index - 1] != label ||
              labels[index + 1] != label ||
              labels[index - w] != label ||
              labels[index + w] != label;
          if (edge) {
            boundary.add(math.Point<int>(x, y));
          }
        }
      }
      boundaries.add(boundary);
    }
    return boundaries;
  }

  /// How sharply the scene changes across the quad's four edges.
  ///
  /// Each edge is walked and the luminance sampled a couple of pixels either
  /// side of it. On a real page border one sample lands on paper and the other
  /// on the desk, so the difference is large; a border that was merely invented
  /// by a threshold — cutting through the middle of the page, or running
  /// through a continuous floor — has almost none. The average over all four
  /// edges is what picks the right candidate threshold.
  static double _edgeScore(
    Uint8List luma,
    int w,
    int h,
    List<math.Point<int>> quad,
  ) {
    const int samples = 40;
    const int reach = 2;
    double total = 0;
    int counted = 0;

    for (int e = 0; e < 4; e++) {
      final math.Point<int> a = quad[e];
      final math.Point<int> b = quad[(e + 1) % 4];
      final double dx = (b.x - a.x).toDouble();
      final double dy = (b.y - a.y).toDouble();
      final double length = math.sqrt(dx * dx + dy * dy);
      if (length < 1) {
        continue;
      }
      // Unit normal to this edge.
      final double nx = -dy / length;
      final double ny = dx / length;

      for (int i = 1; i < samples; i++) {
        final double t = i / samples;
        final double px = a.x + dx * t;
        final double py = a.y + dy * t;
        final int one = _lumaAt(luma, w, h, px + nx * reach, py + ny * reach);
        final int other = _lumaAt(
          luma,
          w,
          h,
          px - nx * reach,
          py - ny * reach,
        );
        // A sample that falls outside the frame is no evidence either way: a
        // page photographed right up to the edge has two borders with nothing
        // beyond them, and counting those as zero contrast would reject a
        // perfectly good detection.
        if (one < 0 || other < 0) {
          continue;
        }
        total += (one - other).abs();
        counted++;
      }
    }
    if (counted < 8) {
      return 0;
    }
    return total / counted / 255;
  }

  /// Mean luminance sampled on a grid inside the quad. A page is a bright
  /// surface; a laptop screen photographed in a dark room can produce a sharp,
  /// page-shaped region that is much darker than any paper.
  static double _interiorLuma(
    Uint8List luma,
    int w,
    int h,
    List<math.Point<int>> quad,
  ) {
    const int steps = 12;
    double total = 0;
    int counted = 0;
    for (int gy = 1; gy < steps; gy++) {
      for (int gx = 1; gx < steps; gx++) {
        final double u = gx / steps;
        final double v = gy / steps;
        // Bilinear interpolation of the four corners.
        final double topX = quad[0].x + (quad[1].x - quad[0].x) * u;
        final double topY = quad[0].y + (quad[1].y - quad[0].y) * u;
        final double bottomX = quad[3].x + (quad[2].x - quad[3].x) * u;
        final double bottomY = quad[3].y + (quad[2].y - quad[3].y) * u;
        final int value = _lumaAt(
          luma,
          w,
          h,
          topX + (bottomX - topX) * v,
          topY + (bottomY - topY) * v,
        );
        if (value < 0) {
          continue;
        }
        total += value;
        counted++;
      }
    }
    return counted == 0 ? 0 : total / counted;
  }

  /// Grows a quad by [amount] around its centre, then clamps it to the frame.
  static CropQuad _expand(CropQuad quad, double amount) {
    final double scale = 1 + amount;
    final double cx =
        (quad.tlX + quad.trX + quad.brX + quad.blX) / 4;
    final double cy =
        (quad.tlY + quad.trY + quad.brY + quad.blY) / 4;
    double grow(double value, double centre) =>
        (centre + (value - centre) * scale).clamp(0.0, 1.0);
    return CropQuad(
      tlX: grow(quad.tlX, cx),
      tlY: grow(quad.tlY, cy),
      trX: grow(quad.trX, cx),
      trY: grow(quad.trY, cy),
      brX: grow(quad.brX, cx),
      brY: grow(quad.brY, cy),
      blX: grow(quad.blX, cx),
      blY: grow(quad.blY, cy),
    );
  }

  /// Nearest-pixel luminance, or -1 outside the image.
  static int _lumaAt(Uint8List luma, int w, int h, double x, double y) {
    final int px = x.round();
    final int py = y.round();
    if (px < 0 || py < 0 || px >= w || py >= h) {
      return -1;
    }
    return luma[py * w + px];
  }

  static int _percentile(List<int> histogram, int total, double percent) {
    final int wanted = (total * percent / 100).round().clamp(1, total);
    int acc = 0;
    for (int i = 0; i < histogram.length; i++) {
      acc += histogram[i];
      if (acc >= wanted) {
        return i;
      }
    }
    return histogram.length - 1;
  }

  /// Andrew's monotone chain, counter-clockwise.
  static List<math.Point<int>> _convexHull(List<math.Point<int>> points) {
    final List<math.Point<int>> sorted = List<math.Point<int>>.from(points)
      ..sort(
        (math.Point<int> a, math.Point<int> b) =>
            a.x == b.x ? a.y - b.y : a.x - b.x,
      );

    final List<math.Point<int>> lower = <math.Point<int>>[];
    for (final math.Point<int> point in sorted) {
      while (lower.length >= 2 &&
          _cross(lower[lower.length - 2], lower.last, point) <= 0) {
        lower.removeLast();
      }
      lower.add(point);
    }

    final List<math.Point<int>> upper = <math.Point<int>>[];
    for (final math.Point<int> point in sorted.reversed) {
      while (upper.length >= 2 &&
          _cross(upper[upper.length - 2], upper.last, point) <= 0) {
        upper.removeLast();
      }
      upper.add(point);
    }

    lower.removeLast();
    upper.removeLast();
    return <math.Point<int>>[...lower, ...upper];
  }

  static int _cross(math.Point<int> o, math.Point<int> a, math.Point<int> b) =>
      (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

  static double _polygonArea(List<math.Point<int>> points) {
    double sum = 0;
    for (int i = 0; i < points.length; i++) {
      final math.Point<int> a = points[i];
      final math.Point<int> b = points[(i + 1) % points.length];
      sum += a.x * b.y - b.x * a.y;
    }
    return sum / 2;
  }

  /// True when the four corners run clockwise without folding over.
  static bool _isConvex(List<math.Point<int>> quad) {
    int sign = 0;
    for (int i = 0; i < quad.length; i++) {
      final int cross = _cross(
        quad[i],
        quad[(i + 1) % quad.length],
        quad[(i + 2) % quad.length],
      );
      if (cross == 0) {
        return false;
      }
      final int next = cross > 0 ? 1 : -1;
      if (sign == 0) {
        sign = next;
      } else if (sign != next) {
        return false;
      }
    }
    return true;
  }

  static int _otsu(Uint8List values) {
    final List<int> histogram = List<int>.filled(256, 0);
    for (final int value in values) {
      histogram[value]++;
    }

    final int total = values.length;
    double sum = 0;
    for (int i = 0; i < 256; i++) {
      sum += i * histogram[i];
    }

    double sumBackground = 0;
    int weightBackground = 0;
    double best = -1;
    int threshold = 128;

    for (int i = 0; i < 256; i++) {
      weightBackground += histogram[i];
      if (weightBackground == 0) {
        continue;
      }
      final int weightForeground = total - weightBackground;
      if (weightForeground == 0) {
        break;
      }
      sumBackground += i * histogram[i];
      final double meanBackground = sumBackground / weightBackground;
      final double meanForeground = (sum - sumBackground) / weightForeground;
      final double between =
          weightBackground *
          weightForeground *
          (meanBackground - meanForeground) *
          (meanBackground - meanForeground);
      if (between > best) {
        best = between;
        threshold = i;
      }
    }
    return threshold;
  }

  static Uint8List _boxBlur(Uint8List source, int w, int h, int radius) {
    final Uint8List horizontal = Uint8List(w * h);
    for (int y = 0; y < h; y++) {
      int acc = 0;
      int count = 0;
      for (int x = -radius; x < w + radius; x++) {
        final int add = x + radius;
        if (add < w) {
          acc += source[y * w + add];
          count++;
        }
        final int remove = x - radius - 1;
        if (remove >= 0) {
          acc -= source[y * w + remove];
          count--;
        }
        if (x >= 0 && x < w) {
          horizontal[y * w + x] = acc ~/ math.max(1, count);
        }
      }
    }

    final Uint8List vertical = Uint8List(w * h);
    for (int x = 0; x < w; x++) {
      int acc = 0;
      int count = 0;
      for (int y = -radius; y < h + radius; y++) {
        final int add = y + radius;
        if (add < h) {
          acc += horizontal[add * w + x];
          count++;
        }
        final int remove = y - radius - 1;
        if (remove >= 0) {
          acc -= horizontal[remove * w + x];
          count--;
        }
        if (y >= 0 && y < h) {
          vertical[y * w + x] = acc ~/ math.max(1, count);
        }
      }
    }
    return vertical;
  }
}
