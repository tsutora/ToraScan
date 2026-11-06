// Clean A1 sheet: 6.00 x 12.00 m two-storey shop + office (G+1)
const fs = require('fs');
const SW = 841, SH = 594, W = 6000, D = 12000, EXT = 230, INT = 115;
const FONT = "Arial, Helvetica, sans-serif";
const INK = '#1e1e1e', MID = '#555555', SOFT = '#8a8a8a', GLASS = '#e6eff5', GLASS_L = '#3d6a8c';
let o = [];
const p = (s) => o.push(s);
const n = (v) => Number(v.toFixed(2));
const rect = (x, y, w, h, fill = 'none', stroke = 'none', sw = 0, extra = '') =>
  `<rect x="${n(x)}" y="${n(y)}" width="${n(Math.abs(w))}" height="${n(Math.abs(h))}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}" ${extra}/>`;
const line = (x1, y1, x2, y2, w = 0.13, color = INK, extra = '') =>
  `<line x1="${n(x1)}" y1="${n(y1)}" x2="${n(x2)}" y2="${n(y2)}" stroke="${color}" stroke-width="${w}" stroke-linecap="butt" ${extra}/>`;
const txt = (x, y, s, t = {}) => {
  const { size = 2.2, anchor = 'start', weight = 400, fill = INK, rot = 0, ls = 0 } = t;
  return `<text x="${n(x)}" y="${n(y)}" font-family="${FONT}" font-size="${size}" text-anchor="${anchor}" font-weight="${weight}" fill="${fill}"${rot ? ` transform="rotate(${rot} ${n(x)} ${n(y)})"` : ''}${ls ? ` letter-spacing="${ls}"` : ''}>${String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;')}</text>`;
};
const circ = (cx, cy, r, fill = '#fff', stroke = INK, sw = 0.16) =>
  `<circle cx="${n(cx)}" cy="${n(cy)}" r="${n(r)}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}"/>`;

// ---------------- dimensions ----------------
function dimH(x1, x2, y, label, size = 1.9, extTop = null) {
  p(line(x1, y, x2, y, 0.1, MID));
  p(line(x1 - 0.85, y + 0.85, x1 + 0.85, y - 0.85, 0.16, MID));
  p(line(x2 - 0.85, y + 0.85, x2 + 0.85, y - 0.85, 0.16, MID));
  if (extTop !== null) { p(line(x1, extTop, x1, y + 1.0, 0.08, SOFT)); p(line(x2, extTop, x2, y + 1.0, 0.08, SOFT)); }
  p(txt((x1 + x2) / 2, y - 1.2, label, { size, anchor: 'middle', fill: MID }));
}
function dimV(y1, y2, x, label, size = 1.9, extRight = null) {
  p(line(x, y1, x, y2, 0.1, MID));
  p(line(x - 0.85, y1 + 0.85, x + 0.85, y1 - 0.85, 0.16, MID));
  p(line(x - 0.85, y2 + 0.85, x + 0.85, y2 - 0.85, 0.16, MID));
  if (extRight !== null) { p(line(extRight, y1, x - 1.0, y1, 0.08, SOFT)); p(line(extRight, y2, x - 1.0, y2, 0.08, SOFT)); }
  p(txt(x - 1.1, (y1 + y2) / 2, label, { size, anchor: 'middle', rot: -90, fill: MID }));
}

// ---------------- plan mapping ----------------
function plan(tx, ty, s) {
  const X = (rx) => tx + rx * s;
  const Y = (ry) => ty + (D - ry) * s;
  const box = (x, y, w, h, fill = INK, extra = '') => p(rect(X(x), Y(y + h), w * s, h * s, fill, 'none', 0, extra));
  const ln = (x1, y1, x2, y2, w = 0.13, color = INK, extra = '') => p(line(X(x1), Y(y1), X(x2), Y(y2), w, color, extra));
  const lbl = (x, y, s2, t) => p(txt(X(x), Y(y), s2, t));
  return { X, Y, box, ln, lbl, tx, ty, s };
}
function glazingH(P, x1, x2, y) {
  P.box(x1, y, x2 - x1, EXT, GLASS);
  p(rect(P.X(x1), P.Y(y + EXT), (x2 - x1) * P.s, EXT * P.s, 'none', GLASS_L, 0.12));
  P.ln(x1, y + 70, x2, y + 70, 0.12, GLASS_L);
  P.ln(x1, y + 160, x2, y + 160, 0.12, GLASS_L);
}
function glazingV(P, y1, y2, x) {
  P.box(x, y1, EXT, y2 - y1, GLASS);
  p(rect(P.X(x), P.Y(y2), EXT * P.s, (y2 - y1) * P.s, 'none', GLASS_L, 0.12));
  P.ln(x + 70, y1, x + 70, y2, 0.12, GLASS_L);
  P.ln(x + 160, y1, x + 160, y2, 0.12, GLASS_L);
}
function door(P, hx, hy, w, aOpen, aClosed) {
  const r = w * P.s, cx = P.X(hx), cy = P.Y(hy), rad = Math.PI / 180;
  const pt = (a) => [cx + r * Math.cos(a * rad), cy + r * Math.sin(a * rad)];
  const [x1, y1] = pt(aOpen), [x2, y2] = pt(aClosed);
  p(line(cx, cy, x1, y1, 0.24));
  let d = aClosed - aOpen;
  while (d > 180) d -= 360;
  while (d < -180) d += 360;
  p(`<path d="M ${n(x1)} ${n(y1)} A ${n(r)} ${n(r)} 0 0 ${d > 0 ? 1 : 0} ${n(x2)} ${n(y2)}" fill="none" stroke="${SOFT}" stroke-width="0.11" stroke-dasharray="0.8 0.6"/>`);
}
function stair(P, x, y, w, run, up) {
  P.ln(x, y, x, y + run, 0.16);
  P.ln(x + w, y, x + w, y + run, 0.16);
  const t = 14;
  for (let i = 1; i < t; i++) P.ln(x, y + (run / t) * i, x + w, y + (run / t) * i, 0.1);
  const ax = x + w * 0.55;
  const y1 = up ? y + 300 : y + run - 300, y2 = up ? y + run - 300 : y + 300;
  P.ln(ax, y1, ax, y2, 0.18);
  const d = Math.sign(y2 - y1);
  P.ln(ax - 90, y2 - 140 * d, ax, y2, 0.18);
  P.ln(ax + 90, y2 - 140 * d, ax, y2, 0.18);
  P.lbl(ax + 130, (up ? y1 : y2) + 60, up ? 'UP' : 'DN', { size: 1.7, weight: 700, fill: MID });
}

function heading(x, y, title, scale) {
  p(txt(x, y, title, { size: 4.0, weight: 700, ls: 0.5 }));
  p(txt(x, y + 5.2, scale, { size: 1.8, fill: MID, ls: 0.3 }));
  p(line(x, y + 8.2, x + 26, y + 8.2, 0.5));
}

// =====================================================================
p(`<svg xmlns="http://www.w3.org/2000/svg" width="${SW}" height="${SH}" viewBox="0 0 ${SW} ${SH}">`);
p(`<defs>
<pattern id="earth" width="5" height="5" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
  <line x1="0" y1="0" x2="0" y2="5" stroke="#b0b0b0" stroke-width="0.2"/>
</pattern>
</defs>`);
p(rect(0, 0, SW, SH, '#fff'));
p(rect(6, 6, SW - 12, SH - 12, 'none', INK, 0.8));
p(rect(11, 11, SW - 22, SH - 22, 'none', INK, 0.25));

// =====================================================================
// PLANS
// =====================================================================
const gf = plan(58, 56, 1 / 50);
const ff = plan(203, 56, 1 / 50);

function grid(P, bubbles = true) {
  const ds = 'stroke-dasharray="7 1.2 1.2 1.2"';
  [0, 6000].forEach((x) => P.ln(x, -300, x, D + 280, 0.08, '#a5a5a5', ds));
  [0, 4000, 8000, 12000].forEach((y) => P.ln(-300, y, W + 260, y, 0.08, '#a5a5a5', ds));
  if (!bubbles) return;
  [['A', 0], ['B', 6000]].forEach(([t, x]) => {
    p(circ(P.X(x), P.Y(D + 280) - 4.6, 2.9, '#fff', MID, 0.14));
    p(txt(P.X(x), P.Y(D + 280) - 3.8, t, { size: 2.0, anchor: 'middle', weight: 700, fill: MID }));
  });
  [['1', 0], ['2', 4000], ['3', 8000], ['4', 12000]].forEach(([t, y]) => {
    p(circ(P.X(W + 260) + 4.6, P.Y(y), 2.9, '#fff', MID, 0.14));
    p(txt(P.X(W + 260) + 4.6, P.Y(y) + 0.7, t, { size: 2.0, anchor: 'middle', weight: 700, fill: MID }));
  });
}

// ---------------- GROUND FLOOR ----------------
p('<g id="gf">');
grid(gf);
// external walls
gf.box(0, 0, 900, EXT);
gf.box(5100, 0, 900, EXT);
gf.box(0, D - EXT, 1500, EXT);
gf.box(2400, D - EXT, 3600, EXT);
gf.box(0, 0, EXT, 2500);
gf.box(0, 4500, EXT, 7500);
gf.box(W - EXT, 0, EXT, 1800);
gf.box(W - EXT, 4200, EXT, 7800);
glazingH(gf, 900, 5100, 0);
[2300, 3700].forEach((x) => gf.box(x - 20, 60, 40, 110, GLASS_L));
[3300, 3900].forEach((x) => gf.box(x - 12, 60, 24, 110, GLASS_L));
glazingV(gf, 2500, 4500, 0);
glazingV(gf, 1800, 4200, W - EXT);
// partitions
gf.box(230, 6900, 2470, INT);
gf.box(3600, 6900, 2170, INT);
gf.box(1330, 7700, INT, 4070);
gf.box(1445, 9085, 1555, INT);
gf.box(3900, 9085, 140, INT);
gf.box(4040, 9085, INT, 2685);
gf.box(4155, 9885, 145, INT);
gf.box(5100, 9885, 670, INT);
gf.box(4155, 10000, INT, 1770);
// doors
door(gf, 2700, 6957, 900, 270, 0);
door(gf, 3000, 9142, 900, 270, 0);
door(gf, 4300, 9942, 800, 270, 0);
door(gf, 1500, 11885, 900, 90, 0);
gf.box(3300, 45, 600, 150, '#f6fbfd');
p(rect(gf.X(3300), gf.Y(195), 600 * gf.s, 150 * gf.s, 'none', GLASS_L, 0.16));
gf.ln(3600, 45, 3600, 195, 0.16, GLASS_L);
stair(gf, 230, 7700, 1100, 3600, true);
// fixtures
p(`<ellipse cx="${n(gf.X(4750))}" cy="${n(gf.Y(10750))}" rx="${n(225 * gf.s)}" ry="${n(295 * gf.s)}" fill="none" stroke="${MID}" stroke-width="0.13"/>`);
gf.box(4665, 10380, 170, 250, '#fff');
gf.box(5300, 10140, 420, 260, 'none');
p(rect(gf.X(5300), gf.Y(10400), 420 * gf.s, 260 * gf.s, 'none', MID, 0.13));
p(`<ellipse cx="${n(gf.X(5510))}" cy="${n(gf.Y(10270))}" rx="${n(150 * gf.s)}" ry="${n(100 * gf.s)}" fill="none" stroke="${MID}" stroke-width="0.13"/>`);
// labels
gf.lbl(3000, 4450, 'RETAIL  /  SHOP', { size: 3.0, anchor: 'middle', weight: 700, ls: 0.3 });
gf.lbl(3000, 4050, '36.94 m²', { size: 1.9, anchor: 'middle', fill: MID });
gf.lbl(2720, 8800, 'HALL', { size: 2.2, anchor: 'middle', weight: 700 });
gf.lbl(2720, 8250, '10.24 m²', { size: 1.7, anchor: 'middle', fill: MID });
gf.lbl(2700, 11200, 'STORE', { size: 2.2, anchor: 'middle', weight: 700 });
gf.lbl(2700, 10700, '6.67 m²', { size: 1.7, anchor: 'middle', fill: MID });
gf.lbl(4960, 11450, 'WC', { size: 2.2, anchor: 'middle', weight: 700 });
gf.lbl(4960, 11050, '2.66 m²', { size: 1.7, anchor: 'middle', fill: MID });
planDimsLocal(gf, '12 000');
heading(gf.X(0) - 14, 330, 'GROUND FLOOR PLAN', 'SCALE 1:50');
p('</g>');

// ---------------- FIRST FLOOR ----------------
p('<g id="ff">');
grid(ff);
ff.box(0, 0, 1200, EXT);
ff.box(2600, 0, 800, EXT);
ff.box(4800, 0, 1200, EXT);
ff.box(0, D - EXT, 1500, EXT);
ff.box(2400, D - EXT, 3600, EXT);
ff.box(0, 0, EXT, 2500);
ff.box(0, 4500, EXT, 7500);
ff.box(W - EXT, 0, EXT, 1800);
ff.box(W - EXT, 4200, EXT, 1800);
ff.box(W - EXT, 8400, EXT, 3600);
glazingH(ff, 1200, 2600, 0);
glazingH(ff, 3400, 4800, 0);
glazingH(ff, 1500, 2400, D - EXT);
glazingV(ff, 2500, 4500, 0);
glazingV(ff, 1800, 4200, W - EXT);
glazingV(ff, 6000, 8400, W - EXT);
[1900, 2300].forEach((x) => ff.box(x, 60, 20, 110, GLASS_L));
[4100, 4500].forEach((x) => ff.box(x, 60, 20, 110, GLASS_L));
ff.box(230, 6900, 2470, INT);
ff.box(3600, 6900, 2170, INT);
ff.box(1330, 7700, INT, 4070);
ff.box(4155, 7015, INT, 785);
ff.box(4155, 8600, INT, 1285);
ff.box(1445, 9085, 2595, INT);
ff.box(4040, 9085, INT, 2685);
ff.box(4155, 9885, 145, INT);
ff.box(5100, 9885, 670, INT);
ff.box(4155, 10000, INT, 1770);
door(ff, 2700, 6957, 900, 270, 0);
door(ff, 3000, 9142, 900, 270, 0);
door(ff, 4300, 9942, 800, 270, 0);
door(ff, 4212, 7800, 800, 0, 90);
// stair void
ff.box(230, 7700, 1100, 3600, '#f4f4f4');
stair(ff, 230, 7700, 1100, 3600, false);
// kitchenette
ff.box(W - EXT - 480, 7150, 480, 2500, 'none');
p(rect(ff.X(W - EXT - 480), ff.Y(9650), 480 * ff.s, 2500 * ff.s, 'none', MID, 0.12));
p(rect(ff.X(W - EXT - 400), ff.Y(8500), 320 * ff.s, 380 * ff.s, 'none', MID, 0.12));
p(`<ellipse cx="${n(ff.X(4750))}" cy="${n(ff.Y(10750))}" rx="${n(225 * ff.s)}" ry="${n(295 * ff.s)}" fill="none" stroke="${MID}" stroke-width="0.13"/>`);
ff.box(4665, 10380, 170, 250, '#fff');
// labels
ff.lbl(3000, 4700, 'OPEN PLAN OFFICE / STUDIO', { size: 3.0, anchor: 'middle', weight: 700, ls: 0.3 });
ff.lbl(3000, 4300, '36.94 m²', { size: 1.9, anchor: 'middle', fill: MID });
ff.lbl(2820, 8700, 'LANDING', { size: 2.1, anchor: 'middle', weight: 700 });
ff.lbl(2820, 8150, '5.92 m²', { size: 1.7, anchor: 'middle', fill: MID });
ff.lbl(4950, 8500, 'KITCHEN', { size: 1.9, anchor: 'middle', weight: 700, rot: -90 });
ff.lbl(4960, 11450, 'WC', { size: 2.2, anchor: 'middle', weight: 700 });
ff.lbl(4960, 11050, '2.66 m²', { size: 1.7, anchor: 'middle', fill: MID });
ff.lbl(2700, 11250, 'STORE / ARCHIVE', { size: 2.1, anchor: 'middle', weight: 700 });
ff.lbl(2700, 10750, '6.37 m²', { size: 1.7, anchor: 'middle', fill: MID });
planDimsLocal(ff, '12 000');
heading(ff.X(0) - 14, 330, 'FIRST FLOOR PLAN', 'SCALE 1:50');
p('</g>');

function planDimsLocal(P, dep) {
  const yb = P.Y(0) + 9;
  dimH(P.X(0), P.X(230), yb, '230');
  dimH(P.X(230), P.X(5770), yb, '5540');
  dimH(P.X(5770), P.X(6000), yb, '230');
  p(line(P.X(0), yb, P.X(6000), yb, 0.1, MID));
  dimH(P.X(0), P.X(6000), yb + 6.5, '6000', 2.0, yb);
  const xl = P.X(0) - 9;
  dimV(P.Y(0), P.Y(4000), xl, '4000');
  dimV(P.Y(4000), P.Y(8000), xl, '4000');
  dimV(P.Y(8000), P.Y(12000), xl, '4000');
  dimV(P.Y(0), P.Y(12000), xl - 6.5, '12 000', 2.0, xl);
}

// =====================================================================
// FRONT ELEVATION 1:50
// =====================================================================
const fx0 = 388, fbase = 262, fs_ = 1 / 50;
const FX = (v) => fx0 + v * fs_, FY = (v) => fbase - v * fs_;
p('<g id="front-elev">');
heading(fx0, 88, 'FRONT ELEVATION', 'SCALE 1:50');
// ground
p(line(FX(-450), FY(0), FX(6450), FY(0), 0.55));
p(rect(FX(-450), FY(0), (6450 + 450) * fs_, 7, 'url(#earth)'));
// wall field
p(rect(FX(0), FY(7800), W * fs_, 7800 * fs_, '#fafafa', INK, 0.4));
// plinth
p(rect(FX(-40), FY(0), (W + 80) * fs_, -160 * -fs_, '#f0f0f0', INK, 0.3));
// shopfront recess
p(rect(FX(900), FY(3000), 4200 * fs_, 2850 * fs_, GLASS, GLASS_L, 0.32));
[2300, 3700].forEach((x) => p(rect(FX(x - 25), FY(3000), 50 * fs_, 2850 * fs_, GLASS_L)));
// entrance doors
p(rect(FX(2400), FY(2900), 1200 * fs_, 2750 * fs_, '#f2f8fb', GLASS_L, 0.3));
p(line(FX(3000), FY(2900), FX(3000), FY(150), 0.3, GLASS_L));
[2580, 3420].forEach((x) => p(line(FX(x), FY(1350), FX(x), FY(1150), 0.7, GLASS_L)));
// fascia
p(rect(FX(860), FY(3300), 4280 * fs_, 300 * fs_, INK));
p(txt(FX(3000), FY(3090), 'PAPER  &  TYPE', { size: 2.7, anchor: 'middle', weight: 700, fill: '#fff', ls: 1.4 }));
// floor band
p(line(FX(0), FY(3300), FX(W), FY(3300), 0.5));
// first floor windows
[1200, 3400].forEach((x) => {
  p(rect(FX(x - 80), FY(4350), (1400 + 160) * fs_, 80 * fs_, '#ededed', INK, 0.2));
  p(rect(FX(x), FY(6000), 1400 * fs_, 1650 * fs_, GLASS, GLASS_L, 0.32));
  p(line(FX(x + 700), FY(6000), FX(x + 700), FY(4350), 0.26, GLASS_L));
  p(rect(FX(x - 80), FY(6080), (1400 + 160) * fs_, 80 * fs_, '#ededed', INK, 0.2));
});
// parapet
p(rect(FX(-70), FY(7890), (W + 140) * fs_, 90 * fs_, '#f0f0f0', INK, 0.28));
p(line(FX(0), FY(6700), FX(W), FY(6700), 0.16, SOFT));
// level tags
[[0, '± 0.000', 'FFL'], [3300, '+ 3.300', 'FFL'], [6700, '+ 6.700', 'ROOF'], [7890, '+ 7.890', 'PARAPET']].forEach(([h, t, note]) => {
  p(line(FX(W), FY(h), FX(W + 300), FY(h), 0.09, SOFT));
  p(`<path d="M ${n(FX(W + 300))} ${n(FY(h) - 2.2)} L ${n(FX(W + 300) + 4.2)} ${n(FY(h))} L ${n(FX(W + 300))} ${n(FY(h) + 2.2)} Z" fill="${MID}"/>`);
  p(txt(FX(W + 300) + 5.6, FY(h) - 0.3, t, { size: 1.9, weight: 700 }));
  p(txt(FX(W + 300) + 5.6, FY(h) + 3.0, note, { size: 1.4, fill: SOFT, ls: 0.2 }));
});
// dims
dimH(FX(0), FX(W), FY(0) + 16, '6000', 2.0, FY(0));
dimV(FY(3300), FY(0), FX(0) - 10, '3300', 1.8, FX(0));
dimV(FY(6700), FY(3300), FX(0) - 10, '3400', 1.8, FX(0));
dimV(FY(7890), FY(6700), FX(0) - 10, '1190', 1.8, FX(0));
p('</g>');

// =====================================================================
// SECTION A-A 1:50
// =====================================================================
const sx0 = 562, sbase = 262, ss_ = 1 / 50;
const AX = (v) => sx0 + v * ss_, AY = (v) => sbase - v * ss_;
p('<g id="section-aa">');
heading(sx0, 88, 'SECTION A-A', 'SCALE 1:50');
p(rect(AX(-450), AY(0), (W + 900) * ss_, 26, 'url(#earth)'));
p(line(AX(-450), AY(0), AX(W + 450), AY(0), 0.45));
// footings
p(rect(AX(-185), AY(-1200), 600 * ss_, 250 * ss_, '#f0f0f0', INK, 0.3));
p(rect(AX(5585), AY(-1200), 600 * ss_, 250 * ss_, '#f0f0f0', INK, 0.3));
p(rect(AX(0), AY(0), 230 * ss_, 950 * ss_, '#f0f0f0', INK, 0.3));
p(rect(AX(5770), AY(0), 230 * ss_, 950 * ss_, '#f0f0f0', INK, 0.3));
// walls
p(rect(AX(0), AY(3300), 230 * ss_, 3300 * ss_, '#d8d8d8', INK, 0.4));
p(rect(AX(5770), AY(3300), 230 * ss_, 3300 * ss_, '#d8d8d8', INK, 0.4));
p(rect(AX(0), AY(6700), 230 * ss_, 3400 * ss_, '#d8d8d8', INK, 0.4));
p(rect(AX(5770), AY(6700), 230 * ss_, 3400 * ss_, '#d8d8d8', INK, 0.4));
// glazing
p(rect(AX(60), AY(3000), 110 * ss_, 2850 * ss_, GLASS, GLASS_L, 0.28));
p(rect(AX(60), AY(6000), 110 * ss_, 1650 * ss_, GLASS, GLASS_L, 0.28));
// slabs
p(rect(AX(230), AY(3300), 5540 * ss_, 150 * ss_, '#d8d8d8', INK, 0.35));
p(rect(AX(230), AY(6700), 5540 * ss_, 150 * ss_, '#d8d8d8', INK, 0.35));
// ground slab
p(rect(AX(230), AY(0), 5540 * ss_, 150 * ss_, '#e4e4e4', INK, 0.25));
// roof build-up
p(rect(AX(230), AY(6760), 5540 * ss_, 60 * ss_, '#ececec', 'none'));
// coping
p(rect(AX(0), AY(7800), 230 * ss_, 1100 * ss_, '#d8d8d8', INK, 0.4));
p(rect(AX(5770), AY(7800), 230 * ss_, 1100 * ss_, '#d8d8d8', INK, 0.4));
p(rect(AX(-70), AY(7890), 370 * ss_, 90 * ss_, '#f0f0f0', INK, 0.25));
p(rect(AX(5700), AY(7890), 370 * ss_, 90 * ss_, '#f0f0f0', INK, 0.25));
// DPC
p(line(AX(-4), AY(150), AX(234), AY(150), 0.7));
// levels
[[0, '± 0.000'], [3300, '+ 3.300'], [6700, '+ 6.700'], [7890, '+ 7.890'], [-1200, '- 1.200']].forEach(([h, t]) => {
  p(line(AX(W), AY(h), AX(W + 260), AY(h), 0.09, SOFT));
  p(txt(AX(W + 280), AY(h) + 0.8, t, { size: 1.7, weight: 700, fill: '#444444' }));
});
p(txt(AX(3000), AY(5100), 'OFFICE', { size: 1.9, anchor: 'middle', fill: SOFT, ls: 0.4 }));
p(txt(AX(3000), AY(1400), 'RETAIL', { size: 1.9, anchor: 'middle', fill: SOFT, ls: 0.4 }));
dimV(AY(3300), AY(0), AX(3300), '3300', 1.7);
dimV(AY(6700), AY(3300), AX(3300), '3400', 1.7);
p('</g>');

// =====================================================================
// SECTION B-B 1:75
// =====================================================================
const bx0 = 372, bbase = 480, bs_ = 1 / 75;
const BX = (v) => bx0 + v * bs_, BY = (h) => bbase - h * bs_;
p('<g id="section-bb">');
heading(bx0, 352, 'SECTION B-B', 'SCALE 1:75');
p(rect(BX(-300), BY(0), (D + 600) * bs_, 14, 'url(#earth)'));
p(line(BX(-300), BY(0), BX(D + 300), BY(0), 0.4));
[[0], [D - 230]].forEach(([y]) => {
  p(rect(BX(y - 185), BY(-1200), 600 * bs_, 250 * bs_, '#f0f0f0', INK, 0.26));
  p(rect(BX(y), BY(0), 230 * bs_, 950 * bs_, '#f0f0f0', INK, 0.26));
});
p(rect(BX(0), BY(3300), 230 * bs_, 3300 * bs_, '#d8d8d8', INK, 0.3));
p(rect(BX(D - 230), BY(3300), 230 * bs_, 3300 * bs_, '#d8d8d8', INK, 0.3));
p(rect(BX(0), BY(6700), 230 * bs_, 3400 * bs_, '#d8d8d8', INK, 0.3));
p(rect(BX(D - 230), BY(6700), 230 * bs_, 3400 * bs_, '#d8d8d8', INK, 0.3));
p(rect(BX(6900), BY(3300), INT * bs_, 3400 * bs_, '#d8d8d8', INK, 0.25));
p(rect(BX(6900), BY(6700), INT * bs_, 3400 * bs_, '#d8d8d8', INK, 0.25));
p(rect(BX(230), BY(3300), 11540 * bs_, 150 * bs_, '#d8d8d8', INK, 0.3));
p(rect(BX(230), BY(6700), 11540 * bs_, 150 * bs_, '#d8d8d8', INK, 0.3));
p(rect(BX(230), BY(0), 11540 * bs_, 150 * bs_, '#e4e4e4', INK, 0.2));
p(rect(BX(60), BY(3000), 110 * bs_, 2850 * bs_, GLASS, GLASS_L, 0.24));
p(rect(BX(60), BY(6000), 110 * bs_, 1650 * bs_, GLASS, GLASS_L, 0.24));
p(rect(BX(D - 170), BY(6000), 110 * bs_, 1650 * bs_, GLASS, GLASS_L, 0.24));
p(rect(BX(0), BY(7800), 230 * bs_, 1100 * bs_, '#d8d8d8', INK, 0.3));
p(rect(BX(D - 230), BY(7800), 230 * bs_, 1100 * bs_, '#d8d8d8', INK, 0.3));
p(rect(BX(-60), BY(7890), 330 * bs_, 90 * bs_, '#f0f0f0', INK, 0.22));
p(rect(BX(D - 270), BY(7890), 330 * bs_, 90 * bs_, '#f0f0f0', INK, 0.22));
[[0, '± 0.000'], [3300, '+ 3.300'], [6700, '+ 6.700'], [7890, '+ 7.890']].forEach(([h, t]) => {
  p(line(BX(-60), BY(h), BX(-230), BY(h), 0.08, SOFT));
  p(txt(BX(-245), BY(h) + 0.7, t, { size: 1.5, weight: 700, fill: '#666666', anchor: 'end' }));
});
p(txt(BX(3200), BY(1600), 'RETAIL', { size: 1.7, anchor: 'middle', fill: SOFT, ls: 0.4 }));
p(txt(BX(9500), BY(1600), 'HALL', { size: 1.7, anchor: 'middle', fill: SOFT, ls: 0.4 }));
p(txt(BX(3200), BY(5200), 'OFFICE', { size: 1.7, anchor: 'middle', fill: SOFT, ls: 0.4 }));
p(txt(BX(9500), BY(5200), 'LANDING', { size: 1.7, anchor: 'middle', fill: SOFT, ls: 0.4 }));

p('</g>');

// =====================================================================
// DETAIL 1 : typical footing / plinth 1:15
// =====================================================================
const dx = 92, dbase = 470, dsc = 1 / 15;
const DX = (v) => dx + v * dsc, DY = (v) => dbase - v * dsc;
p('<g id="detail1">');
heading(44, 400, 'DETAIL 1', 'TYPICAL FOOTING & PLINTH — SCALE 1:15');
// external ground
p(rect(DX(-820), DY(0), 820 * dsc, 8, 'url(#earth)'));
p(line(DX(-820), DY(0), DX(0), DY(0), 0.45));
// interior floor slab + finish
p(rect(DX(230), DY(0), 700 * dsc, 120 * dsc, '#eaeaea', INK, 0.22));
p(line(DX(230), DY(-18), DX(930), DY(-18), 0.5));
// wall below DPC
p(rect(DX(0), DY(-150), 230 * dsc, 750 * dsc, '#d8d8d8', INK, 0.3));
// footing
p(rect(DX(-185), DY(-900), 600 * dsc, 250 * dsc, '#e0e0e0', INK, 0.3));
// DPC
p(line(DX(-14), DY(-150), DX(244), DY(-150), 0.85));
// wall above DPC
p(rect(DX(0), DY(600), 230 * dsc, 750 * dsc, '#d8d8d8', INK, 0.3));
const lead = (x1, y1, x2, y2, t) => {
  p(line(x1, y1, x2, y2, 0.09, SOFT));
  p(line(x2, y2, x2 + 5, y2, 0.09, SOFT));
  p(txt(x2 + 6, y2 + 0.8, t, { size: 1.45, fill: MID }));
};
lead(DX(115), DY(420), DX(520), DY(420), '230 BLOCKWORK');
lead(DX(115), DY(-150), DX(520), DY(-150), 'DPC AT -150');
lead(DX(500), DY(-60), DX(980), DY(-60), 'FLOOR FINISH ON SLAB');
lead(DX(-60), DY(-1020), DX(520), DY(-1020), '600 × 250 STRIP FOOTING');
lead(DX(0), DY(-1150), DX(520), DY(-1150) + 2, 'FOUNDING STRATA');
p('</g>');

// =====================================================================
// NOTES
// =====================================================================
p('<g id="notes">');
p(txt(552, 350, 'GENERAL NOTES', { size: 2.4, weight: 700, ls: 0.4 }));
p(line(552, 353, 578, 353, 0.5));
const notes = [
  '1.  All dimensions in millimetres. Verify on site',
  '     before fabrication. Do not scale this drawing.',
  '2.  230 mm external blockwork, 115 mm internal',
  '     partitions, plastered both faces.',
  '3.  Floor-to-floor 3300. Slab 150 thick.',
  '     Clear height 3150 GF / 3250 FF.',
  '4.  Strip footings 600 × 250 at 1200 below FFL,',
  '     bearing capacity 150 kN/m² minimum.',
  '5.  Shopfront: 10 mm toughened glazing in',
  '     powder-coated aluminium frames.',
  '6.  Roof: 150 slab, 1:80 fall, insulated,',
  '     two-layer membrane, 1100 parapet.',
  '7.  Stair: straight flight 1100 wide, 15 risers',
  '     at 223, goings 280, handrail both sides.',
];
notes.forEach((t, i) => p(txt(552, 360 + i * 5.4, t, { size: 1.75, fill: '#333' })));
p('</g>');

// =====================================================================
// TITLE BLOCK
// =====================================================================
const tb = { x: 545, y: 483, w: 281, h: 96 };
p('<g id="titleblock">');
p(rect(tb.x, tb.y, tb.w, tb.h, '#fff'));
p(rect(tb.x, tb.y, tb.w, tb.h, 'none', INK, 0.45));
p(rect(tb.x, tb.y, tb.w, 16, INK));
p(txt(tb.x + 4.5, tb.y + 11, 'SHOP + OFFICE  ·  G+1', { size: 3.4, weight: 700, fill: '#fff', ls: 0.6 }));
p(txt(tb.x + tb.w - 4.5, tb.y + 11, 'A-101', { size: 3.4, weight: 700, fill: '#fff', anchor: 'end', ls: 0.6 }));
p(line(tb.x, tb.y + 16, tb.x + tb.w, tb.y + 16, 0.3));
p(line(tb.x, tb.y + 36, tb.x + tb.w, tb.y + 36, 0.18, SOFT));
p(line(tb.x, tb.y + 56, tb.x + tb.w, tb.y + 56, 0.18, SOFT));
p(line(tb.x, tb.y + 72, tb.x + tb.w, tb.y + 72, 0.25));
p(line(tb.x + 156, tb.y + 16, tb.x + 156, tb.y + 72, 0.18, SOFT));
[66, 132, 196, 240].forEach((d) => p(line(tb.x + d, tb.y + 72, tb.x + d, tb.y + tb.h, 0.18, SOFT)));
const cell = (x, y, k, v, vs = 2.9) => {
  p(txt(x + 3, y + 4.6, k, { size: 1.45, fill: SOFT, weight: 700, ls: 0.3 }));
  p(txt(x + 3, y + 10.2, v, { size: vs, weight: 700 }));
};
cell(tb.x + 2, tb.y + 17.5, 'PROJECT', 'TWO-STOREY SHOP WITH OFFICE ABOVE');
cell(tb.x + 158, tb.y + 17.5, 'CLIENT', 'PRIVATE DEVELOPER');
cell(tb.x + 2, tb.y + 37.5, 'PLOT', '6.00 × 12.00 m   ·   72.00 m² PER FLOOR');
cell(tb.x + 158, tb.y + 37.5, 'LOCATION', 'PLOT No. —, CITY');
cell(tb.x + 2, tb.y + 57.5, 'SHEET TITLE', 'PLANS, ELEVATIONS & SECTIONS', 2.6);
cell(tb.x + 158, tb.y + 57.5, 'STATUS', 'FOR CONSTRUCTION');
const cb = (x, k, v, fs2 = 2.5) => {
  p(txt(x + 3, tb.y + 76, k, { size: 1.35, fill: SOFT, weight: 700, ls: 0.2 }));
  p(txt(x + 3, tb.y + 82.6, v, { size: fs2, weight: 700 }));
};
cb(tb.x + 2, 'DRAWN', 'AR');
cb(tb.x + 68, 'CHECKED', '—');
cb(tb.x + 134, 'SCALE', '1:50 · 1:75 · 1:15', 2.0);
cb(tb.x + 198, 'DATE', '26-10-2026', 2.2);
cb(tb.x + 242, 'SHEET', '1 / 1', 2.2);
p(txt(tb.x + 3, tb.y + 91, 'REV A   ·   ISSUED FOR CONSTRUCTION   ·   ALL DIMENSIONS IN mm', { size: 1.5, fill: SOFT, ls: 0.2 }));
p('</g>');

p('</svg>');
fs.writeFileSync(__dirname + '/shop-drawing.svg', o.join('\n'));
console.log('ok', o.length, 'nodes');
