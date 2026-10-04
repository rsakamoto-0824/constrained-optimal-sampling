// 実務制約付き最適サンプリングの評価結果を説明する資料（技術報告書 report/technical_report.tex の要約版）
// 使い方: NODE_PATH="$(npm root -g)" node build_deck.js <出力パス>
// 数値はすべて deck_data.json（prepare_data.py が results/csv から作る）から読む。

const fs = require('fs');
const path = require('path');
const pptxgen = require('pptxgenjs');

const BASE_DIR = __dirname;
const REPO_DIR = path.join(BASE_DIR, '..', '..');
const FIG_DIR = path.join(REPO_DIR, 'report', 'figures');   // 報告書に載せた図（Git管理）
const OUTPUT_PATH = process.argv[2] || path.join(BASE_DIR, 'deck_raw.pptx');
const D = JSON.parse(fs.readFileSync(path.join(BASE_DIR, 'deck_data.json'), 'utf8'));

// ---- 定数 ----
const SLIDE_W = 13.333;
const SLIDE_H = 7.5;
const MARGIN_X = 0.6;
const CONTENT_W = SLIDE_W - MARGIN_X * 2;
const RIGHT_EDGE = SLIDE_W - MARGIN_X;
const FONT = 'BIZ UDGothic';
const DECK_DATE = '2026年10月4日';
const TITLE_FONT_SIZE = 22;
const BODY_FONT_SIZE = 13;
const SOURCE_Y = 6.95;
const WAFER_RADIUS_MM = 150;
const USABLE_RADIUS_MM = 147;
const SHOT_W_MM = 26;
const SHOT_H_MM = 33;
const N_REF = D.n_ref;

const C = {
  night: '16213E',
  nightCard: '223058',
  ink: '1C2230',
  muted: '5B6275',
  line: 'C9CED9',
  grid: 'E6E9F0',
  gray: 'F3F5F8',
  white: 'FFFFFF',
  onDark: 'E3E8F4',
  onDarkSub: 'AEB8D3',
  accent: '2A78D6',       // 提案法（制約付き D 最適）と同じ青
  accentTint: 'E3EEFB',
  accentDark: '1D5AA6',
  good: '1B8A5A',
  goodTint: 'E2F3EA',
  bad: 'B8645A',
  badTint: 'F6E3E0',
  candidate: 'DDE2EA',
  partial: 'F1F3F6',
};
// 手法の色（報告書の図と同じ。D系=青、I系=紫、Human=橙、Poisson=青緑、Random=灰）
const M = {
  random: { label: 'Random', color: '6B6B67' },
  poisson: { label: 'Poisson', color: '1BAF7A' },
  human: { label: 'Human', color: 'EB6834' },
  dopt: { label: 'D-opt', color: '7FA8E6' },
  iopt: { label: 'I-opt', color: '8E83CF' },
  cdopt: { label: '制約付きD-opt', color: '2A78D6' },
  ciopt: { label: '制約付きI-opt', color: '4A3AA7' },
};
const ORDER_COLORS = { 3: 'A9C6EE', 4: '5C93DE', 5: '1D4F96' };

// ---- 数値の補助 ----
const fmt1 = (v) => (v === null || v === undefined ? '–' : v.toFixed(1));
const fmt2 = (v) => (v === null || v === undefined ? '–' : v.toFixed(2));
const pct0 = (v) => {
  const r = Math.round(v);
  return `${r > 0 ? '+' : r < 0 ? '−' : '±'}${Math.abs(r)}%`;
};
const imp = (o, prop, comp) => D.improvement[`${o}|${prop}|${comp}`].median;
const rms = (o, m, n) => D.mean_rms[`${o}|${m}|${n}`];
const red = (o, nref, m) => D.reduction[`${o}|${nref}|${m}`];
const reductionPct = (nref, n) => Math.round((100 * (nref - n)) / nref);
const range = (vals) => [Math.min(...vals), Math.max(...vals)];
const humanImp = [3, 4, 5].map((o) => imp(o, 'cdopt', 'human'));
const poissonImp = [3, 4, 5].map((o) => imp(o, 'cdopt', 'poisson'));
const randomImp = [3, 4, 5].map((o) => imp(o, 'cdopt', 'random'));
const doptImp = [3, 4, 5].map((o) => imp(o, 'cdopt', 'dopt'));
const red12 = [3, 4, 5].map((o) => red(o, 12, 'cdopt'));
const red19 = [3, 4, 5].map((o) => red(o, 19, 'cdopt'));
const redPctAll = [...red12.map((n) => reductionPct(12, n)), ...red19.map((n) => reductionPct(19, n))];
const augRows = (o) => D.aug[String(o)];
const augMaxImp = Math.max(...[3, 4, 5].flatMap((o) => augRows(o).flatMap((r) => [r.cd, r.ci]).filter((v) => v !== null)));
const softD = D.soft.filter((r) => r.crit === 'D');
const augN11 = [3, 4, 5].map((o) => augRows(o).find((r) => r.n === 11).cd);   // 制約付きD基準の 11 shot は全次数で Naive の方が有意に良い
const augN11I = [3, 4, 5].map((o) => augRows(o).find((r) => r.n === 11).ci);  // 制約付きI基準の 11 shot は拡張計画の方が良い
const augN11Worse = [3, 4, 5].every((o) => augRows(o).find((r) => r.n === 11).cd_worse);
const augN11IBetter = [3, 4, 5].every((o) => augRows(o).find((r) => r.n === 11).ci_sig);
if (!augN11Worse || !augN11IBetter) throw new Error('11 shot の逆転（D基準はNaiveが有意に良く、I基準は拡張計画が有意に良い）の記述が deck_data.json と合わない。結果⑧の文章を見直すこと');
const augLate = [3, 4, 5].flatMap((o) => augRows(o).filter((r) => r.n >= 13).map((r) => Math.abs(r.cd)));

// ---- プレゼンテーション ----
const pres = new pptxgen();
pres.layout = 'LAYOUT_WIDE';
pres.author = 'Claude Code';
pres.title = '実務制約付き最適サンプリングの評価結果';
pres.lang = 'ja-JP';
let pageNumber = 0;

// ---- 文字の補助関数 ----
function parseRich(text, baseOptions = {}) {
  const runs = [];
  const pattern = /([_^])\{([^}]*)\}/g;
  let last = 0;
  let match;
  while ((match = pattern.exec(text)) !== null) {
    if (match.index > last) runs.push({ text: text.slice(last, match.index), options: { ...baseOptions } });
    const script = match[1] === '_' ? { subscript: true } : { superscript: true };
    runs.push({ text: match[2], options: { ...baseOptions, ...script } });
    last = pattern.lastIndex;
  }
  if (last < text.length) runs.push({ text: text.slice(last), options: { ...baseOptions } });
  return runs;
}

function toRuns(item, baseOptions = {}) {
  if (typeof item === 'string') return parseRich(item, baseOptions);
  if (Array.isArray(item)) return item.flatMap((part) => toRuns(part, baseOptions));
  const { text, breakLine, ...rest } = item;
  const runs = parseRich(text, { ...baseOptions, ...rest });
  if (breakLine && runs.length) runs[runs.length - 1].options.breakLine = true;
  return runs;
}

function withBreaks(lines) {
  return lines.map((line, j) => ({ text: line, breakLine: j < lines.length - 1 }));
}

function addText(slide, content, x, y, w, h, options = {}) {
  let runs;
  if (typeof content === 'string') {
    runs = content.includes('\n') ? toRuns(withBreaks(content.split('\n'))) : toRuns(content);
  } else {
    runs = toRuns(content);
  }
  slide.addText(runs, {
    x, y, w, h,
    fontFace: FONT, fontSize: BODY_FONT_SIZE, color: C.ink, margin: 0, valign: 'top',
    isTextBox: true, lang: 'ja-JP',
    ...options,
  });
}

function paragraphs(items, { bullet = true, space = 6, indent = 14, color, fontSize } = {}) {
  const runs = [];
  items.forEach((item, index) => {
    const base = {};
    if (color) base.color = color;
    if (fontSize) base.fontSize = fontSize;
    const itemRuns = toRuns(item, base);
    itemRuns.forEach((run, j) => {
      if (j === 0) {
        run.options.bullet = bullet ? { indent } : false;
        run.options.paraSpaceAfter = space;
      }
      if (j === itemRuns.length - 1 && index < items.length - 1) run.options.breakLine = true;
    });
    runs.push(...itemRuns);
  });
  return runs;
}

function addBullets(slide, items, x, y, w, h, options = {}) {
  const { bullet, space, indent, ...textOptions } = options;
  slide.addText(paragraphs(items, { bullet, space, indent, color: textOptions.color, fontSize: textOptions.fontSize }), {
    x, y, w, h,
    fontFace: FONT, fontSize: BODY_FONT_SIZE, color: C.ink, margin: 0, valign: 'top',
    isTextBox: true, lang: 'ja-JP',
    ...textOptions,
  });
}

// ---- 図形の補助関数 ----
function addCard(slide, x, y, w, h, { fill = C.gray, line, radius = 0.08, lineWidth = 1 } = {}) {
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x, y, w, h, rectRadius: radius,
    fill: { color: fill },
    line: line ? { color: line, width: lineWidth } : { color: fill, width: 0.5 },
  });
}

function addRect(slide, x, y, w, h, { fill = C.gray, line, lineWidth = 0.75, transparency } = {}) {
  const fillOptions = { color: fill };
  if (transparency !== undefined) fillOptions.transparency = transparency;
  slide.addShape(pres.shapes.RECTANGLE, {
    x, y, w, h, fill: fillOptions, line: line ? { color: line, width: lineWidth } : { color: fill, width: 0.5 },
  });
}

function addLine(slide, x1, y1, x2, y2, { color = C.line, width = 1.5, dash, arrow = false } = {}) {
  const dx = x2 - x1;
  const dy = y2 - y1;
  const length = Math.hypot(dx, dy);
  let angle = (Math.atan2(dy, dx) * 180) / Math.PI;
  if (angle < 0) angle += 360;
  const lineOptions = { color, width };
  if (dash) lineOptions.dashType = dash;
  if (arrow) lineOptions.endArrowType = 'triangle';
  slide.addShape(pres.shapes.LINE, {
    x: (x1 + x2) / 2 - length / 2, y: (y1 + y2) / 2, w: length, h: 0,
    rotate: angle, line: lineOptions,
  });
}

function addNode(slide, cx, cy, diameter, fill, label, { color = C.white, fontSize = 13 } = {}) {
  slide.addShape(pres.shapes.OVAL, {
    x: cx - diameter / 2, y: cy - diameter / 2, w: diameter, h: diameter,
    fill: { color: fill }, line: { color: fill, width: 0.5 },
  });
  if (label) {
    addText(slide, label, cx - diameter / 2, cy - diameter / 2, diameter, diameter, {
      align: 'center', valign: 'middle', fontSize, bold: true, color,
    });
  }
}

function addDot(slide, cx, cy, diameter, color) {
  slide.addShape(pres.shapes.OVAL, {
    x: cx - diameter / 2, y: cy - diameter / 2, w: diameter, h: diameter,
    fill: { color }, line: { color, width: 0.5 },
  });
}

function addChip(slide, text, x, y, w, h, { fill = C.muted, color = C.white, fontSize = 10.5, bold = true, radius = 0.06 } = {}) {
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, rectRadius: radius, fill: { color: fill }, line: { color: fill, width: 0.5 } });
  addText(slide, text, x + 0.03, y, w - 0.06, h, { fontSize, bold, color, align: 'center', valign: 'middle' });
}

function drawPolygon(slide, pts, { fill, line, lineWidth = 0.5 } = {}) {
  const xs = pts.map((p) => p[0]);
  const ys = pts.map((p) => p[1]);
  const x0 = Math.min(...xs);
  const y0 = Math.min(...ys);
  const w = Math.max(Math.max(...xs) - x0, 0.01);
  const h = Math.max(Math.max(...ys) - y0, 0.01);
  slide.addShape(pres.shapes.CUSTOM_GEOMETRY, {
    x: x0, y: y0, w, h,
    points: [...pts.map(([x, y]) => ({ x: x - x0, y: y - y0 })), { close: true }],
    fill: { color: fill },
    line: line ? { color: line, width: lineWidth } : { color: fill, width: 0.25, transparency: 100 },
  });
}

// PNG の縦横の画素数（IHDR から読む）
function pngSize(file) {
  const buf = fs.readFileSync(file);
  return { w: buf.readUInt32BE(16), h: buf.readUInt32BE(20) };
}

// 枠（x, y, w, h）に収まる最大の大きさで、縦横比を保って画像を置く
function addImageFit(slide, file, x, y, w, h, { align = 'center' } = {}) {
  const { w: pw, h: ph } = pngSize(file);
  const scale = Math.min(w / pw, h / ph);
  const iw = pw * scale;
  const ih = ph * scale;
  const ix = align === 'left' ? x : x + (w - iw) / 2;
  slide.addImage({ path: file, x: ix, y: y + (h - ih) / 2, w: iw, h: ih });
  return { x: ix, y: y + (h - ih) / 2, w: iw, h: ih };
}

// ---- ウェーハの図 ----
const CIRCLE_POLYGON = Array.from({ length: 180 }, (_, i) => {
  const a = (2 * Math.PI * i) / 180;
  return [WAFER_RADIUS_MM * Math.cos(a), WAFER_RADIUS_MM * Math.sin(a)];
});

function clipPolygon(subject, clip) {
  let output = subject;
  for (let i = 0; i < clip.length && output.length; i += 1) {
    const [ax, ay] = clip[i];
    const [bx, by] = clip[(i + 1) % clip.length];
    const inside = ([px, py]) => (bx - ax) * (py - ay) - (by - ay) * (px - ax) >= 0;
    const intersect = ([px, py], [qx, qy]) => {
      const a1 = by - ay; const b1 = ax - bx; const c1 = a1 * ax + b1 * ay;
      const a2 = qy - py; const b2 = px - qx; const c2 = a2 * px + b2 * py;
      const det = a1 * b2 - a2 * b1;
      return [(b2 * c1 - b1 * c2) / det, (a1 * c2 - a2 * c1) / det];
    };
    const input = output;
    output = [];
    input.forEach((cur, j) => {
      const prev = input[(j + input.length - 1) % input.length];
      if (inside(cur)) {
        if (!inside(prev)) output.push(intersect(prev, cur));
        output.push(cur);
      } else if (inside(prev)) {
        output.push(intersect(prev, cur));
      }
    });
  }
  return output;
}

// shots: {x, y, ...}、style(shot) が {fill} を返す。半径領域の境界（正規化半径 0.5, 0.7）を破線で描く
function drawWafer(slide, cx, cy, radiusIn, shots, style, { regions = true, scanMarks = null } = {}) {
  const scale = radiusIn / WAFER_RADIUS_MM;
  const toSlide = ([x, y]) => [cx + x * scale, cy - y * scale];
  shots.forEach((shot) => {
    const x0 = shot.x - SHOT_W_MM / 2;
    const x1 = shot.x + SHOT_W_MM / 2;
    const y0 = shot.y - SHOT_H_MM / 2;
    const y1 = shot.y + SHOT_H_MM / 2;
    const clipped = clipPolygon([[x0, y0], [x1, y0], [x1, y1], [x0, y1]], CIRCLE_POLYGON);
    if (clipped.length < 3) return;
    drawPolygon(slide, clipped.map(toSlide), { fill: style(shot).fill, line: C.white, lineWidth: 0.75 });
  });
  if (regions) {
    [0.5, 0.7].forEach((r) => {
      const rad = r * WAFER_RADIUS_MM * scale;
      slide.addShape(pres.shapes.OVAL, { x: cx - rad, y: cy - rad, w: rad * 2, h: rad * 2, line: { color: C.good, width: 1, dashType: 'dash' } });
    });
    addLine(slide, cx - radiusIn, cy, cx + radiusIn, cy, { color: C.muted, width: 0.75 });
    addLine(slide, cx, cy - radiusIn, cx, cy + radiusIn, { color: C.muted, width: 0.75 });
  }
  if (scanMarks) {
    shots.filter(scanMarks).forEach((shot) => {
      const [sx, sy] = toSlide([shot.x, shot.y]);
      const size = 0.075;
      const pts = shot.scan === 'Up'
        ? [[sx, sy - size], [sx + size, sy + size * 0.8], [sx - size, sy + size * 0.8]]
        : [[sx, sy + size], [sx + size, sy - size * 0.8], [sx - size, sy - size * 0.8]];
      drawPolygon(slide, pts, { fill: C.white });
    });
  }
  slide.addShape(pres.shapes.OVAL, { x: cx - radiusIn, y: cy - radiusIn, w: radiusIn * 2, h: radiusIn * 2, line: { color: C.muted, width: 1.25 } });
  return { toSlide };
}

// ---- スライド共通 ----
function newContentSlide(kicker, title, notes) {
  const slide = pres.addSlide();
  pageNumber += 1;
  slide.background = { color: C.white };
  addDot(slide, MARGIN_X + 0.08, 0.5, 0.15, C.accent);
  addText(slide, kicker, MARGIN_X + 0.28, 0.35, 8.8, 0.3, { fontSize: 12, bold: true, color: C.accent, valign: 'middle' });
  addChip(slide, '制約付き最適サンプリング｜評価結果', RIGHT_EDGE - 3.2, 0.34, 3.2, 0.32, { fill: C.accentTint, color: C.accentDark, fontSize: 10.5 });
  addText(slide, title, MARGIN_X, 0.72, CONTENT_W, 0.62, { fontSize: TITLE_FONT_SIZE, bold: true, valign: 'middle' });
  addText(slide, String(pageNumber), SLIDE_W - 1.1, 7.05, 0.5, 0.3, { fontSize: 10, color: C.muted, align: 'right' });
  if (notes) slide.addNotes(notes.join('\n'));
  return slide;
}

function addSource(slide, text) {
  addText(slide, text, MARGIN_X, SOURCE_Y, 11.4, 0.36, { fontSize: 9, color: C.muted });
}

function addTakeaway(slide, text, x, y, w, h, { fill = C.accentTint, color = C.accentDark, fontSize = 13 } = {}) {
  addCard(slide, x, y, w, h, { fill });
  addText(slide, text, x + 0.25, y + 0.12, w - 0.5, h - 0.24, { fontSize, bold: true, color, valign: 'middle' });
}

function addTableBox(slide, rows, x, y, w, colW, { rowH, fontSize = 11.5 } = {}) {
  slide.addTable(rows, {
    x, y, w, colW, rowH,
    fontFace: FONT, fontSize, color: C.ink, valign: 'middle',
    border: { type: 'solid', pt: 0.75, color: C.line },
    margin: [0.04, 0.08, 0.04, 0.08],
  });
}

function cellRuns(text) {
  if (typeof text !== 'string') return text;
  return text.includes('\n') ? toRuns(withBreaks(text.split('\n'))) : toRuns(text);
}
function headCell(text, fill = C.muted, options = {}) {
  return { text: cellRuns(text), options: { bold: true, color: C.white, fill: { color: fill }, align: 'center', ...options } };
}
function bodyCell(text, options = {}) {
  return { text: cellRuns(text), options: { color: C.ink, ...options } };
}

function addStepCard(slide, x, y, w, h, num, title, body, { color = C.accent, fill = C.gray, titleSize = 13.5, bodySize = 11.5 } = {}) {
  addCard(slide, x, y, w, h, { fill });
  addNode(slide, x + 0.32, y + 0.33, 0.4, color, String(num), { fontSize: 12 });
  addText(slide, title, x + 0.62, y + 0.12, w - 0.75, 0.44, { fontSize: titleSize, bold: true, valign: 'middle' });
  addText(slide, body, x + 0.22, y + 0.64, w - 0.42, h - 0.72, { fontSize: bodySize });
}

function addStat(slide, x, y, w, h, value, label, { fill = C.gray, valueColor = C.accentDark, valueSize = 40, labelSize = 12 } = {}) {
  addCard(slide, x, y, w, h, { fill });
  addText(slide, value, x + 0.2, y + 0.18, w - 0.4, h * 0.5, { fontSize: valueSize, bold: true, color: valueColor, valign: 'middle' });
  addText(slide, label, x + 0.2, y + h * 0.58, w - 0.4, h * 0.38, { fontSize: labelSize, color: C.ink });
}

// グラフの共通設定（毎回新しいオブジェクトを返す）
function chartBase(extra = {}) {
  return {
    catAxisLabelFontFace: FONT, valAxisLabelFontFace: FONT, legendFontFace: FONT, dataLabelFontFace: FONT, titleFontFace: FONT,
    catAxisLabelFontSize: 11, valAxisLabelFontSize: 10, legendFontSize: 11, dataLabelFontSize: 10,
    catAxisLabelColor: C.ink, valAxisLabelColor: C.muted,
    valGridLine: { color: C.grid, size: 0.75 }, catGridLine: { style: 'none' },
    catAxisLineShow: true, valAxisLineShow: false,
    ...extra,
  };
}

// 候補shotとpartial shot（全shot）
const SHOTS = D.shots;
const shotById = Object.fromEntries(SHOTS.map((s) => [s.id, s]));
function designSet(key) {
  return new Set(D.designs_howa4_n12[key] || []);
}

// ====================================================================== 1. 表紙
{
  const slide = pres.addSlide();
  pageNumber += 1;
  slide.background = { color: C.night };
  addText(slide, 'wafer高次補正のalignment計測shot選択', MARGIN_X + 0.2, 1.35, 8.2, 0.45, { fontSize: 18, color: C.onDarkSub, bold: true });
  addText(slide, '実務制約付き最適サンプリングの\n評価結果', MARGIN_X + 0.2, 1.9, 7.9, 1.7, { fontSize: 36, bold: true, color: C.white });
  addText(slide, '象限・半径領域・scan方向・強制計測shotを満たすD/I最適計画を、\n1000枚の模擬waferでHOWA型3〜5次補正の残差により評価した', MARGIN_X + 0.2, 3.85, 7.9, 0.9, { fontSize: 15, color: C.onDark });
  addText(slide, `${DECK_DATE}　技術報告書（report/technical_report.tex）の説明資料`, MARGIN_X + 0.2, 6.2, 8.5, 0.35, { fontSize: 12, color: C.onDarkSub });
  // 右側：制約付きD-optの配置（HOWA 4次・12 shot）
  const chosen = designSet('base|cdopt');
  drawWafer(slide, 10.8, 3.6, 1.95, SHOTS, (s) => ({ fill: chosen.has(s.id) ? M.cdopt.color : (s.cand ? C.nightCard : '1B2848') }), { regions: false });
  addText(slide, '例：制約付きD最適で選んだ12 shot（HOWA 4次）', 8.75, 5.75, 4.1, 0.3, { fontSize: 10.5, color: C.onDarkSub, align: 'center' });
  slide.addNotes([
    'この資料は、技術報告書「wafer高次補正のアライメント計測shot選択における実務制約付き最適サンプリング手法の構築と評価」の結果を説明するものです。',
    '数値はすべて乱数で生成した模擬waferによるもので、実データ・社内データは使っていません。未確定の工程パラメータは仮定値です。',
    '右の図は、提案手法（制約付きD最適）がHOWA 4次・12 shotで選んだ配置です。',
  ].join('\n'));
}

// ====================================================================== 2. 要旨
{
  const slide = newContentSlide('要旨', '実務制約を守ったまま、従来の配置より少ないshotで同じ補正精度を出せる', [
    `制約付きD最適は、HumanやPoissonの配置よりwafer内の補正残差が小さくなりました。N=8〜19の中央値で、Humanより${Math.round(Math.min(...humanImp))}〜${Math.round(Math.max(...humanImp))}%、Poissonより${Math.round(Math.min(...poissonImp))}〜${Math.round(Math.max(...poissonImp))}%小さい値です。`,
    `Humanが12 shot・19 shotで得る残差を、それぞれ${Math.min(...red12)}〜${Math.max(...red12)} shot・${Math.min(...red19)}〜${Math.max(...red19)} shotで達成しました。計測shot数では${Math.min(...redPctAll)}〜${Math.max(...redPctAll)}%の削減です。`,
    '制約付き設計は全設計で象限・半径領域・scan方向の制約違反が0でした。制約なしのD最適は、半径領域の制約を全設計で外しています。',
    `代償として、制約なしのD最適より残差が大きくなる場合があります。3次ではほぼ同じ（${pct0(doptImp[0])}）ですが、4次${pct0(doptImp[1])}、5次${pct0(doptImp[2])}でした（正の値は制約付きが良い）。`,
  ]);
  const w = 3.85;
  addStat(slide, MARGIN_X, 1.6, w, 1.9, `${Math.round(Math.min(...humanImp))}〜${Math.round(Math.max(...humanImp))}%`, 'Human配置に対する補正残差の低減\n（平均RMS、N=8〜19の中央値）');
  addStat(slide, MARGIN_X + w + 0.3, 1.6, w, 1.9, `${Math.min(...redPctAll)}〜${Math.max(...redPctAll)}%`, '同じ残差に必要な計測shot数の削減\n（Humanの12・19 shotと比べて）');
  addStat(slide, MARGIN_X + 2 * (w + 0.3), 1.6, w, 1.9, '0件', '制約違反（象限・半径・scan方向）\n制約なしD最適は全設計で違反', { valueColor: C.good });
  addCard(slide, MARGIN_X, 3.8, CONTENT_W, 2.85, { fill: C.gray });
  addText(slide, '分かったこと', MARGIN_X + 0.3, 3.95, 4, 0.35, { fontSize: 14, bold: true, color: C.accentDark });
  addBullets(slide, [
    '制約付きD/I最適（提案法）は、制約を満たす配置の中で最も補正残差が小さい',
    `制約の代償は高次ほど大きい（制約なしD最適比：3次 ${pct0(doptImp[0])}、4次 ${pct0(doptImp[1])}、5次 ${pct0(doptImp[2])}）。主因は半径領域の上限で外周shotが減り、partial shot領域への外挿が悪くなること`,
    'wafer内側（候補shotのmark）だけで見ると、どの次数でも制約付きの方が残差が小さい',
    'scan方向依存の誤差が大きいほど、scan方向をそろえる制約付き設計が有利になる',
    `強制計測shotは情報量を考慮した拡張計画で選ぶ（追加shotが少ないとき素朴な方法より最大${Math.round(augMaxImp)}%小さい。素朴な方法はrank不足になることもある）`,
  ], MARGIN_X + 0.3, 4.4, CONTENT_W - 0.6, 2.2, { fontSize: 13, space: 5 });
}

// ====================================================================== 3. 背景
{
  const slide = newContentSlide('背景', '高次補正は推定する係数が多く、どのshotを測るかで精度が大きく変わる', [
    '高次補正では、総次数mの2変数多項式で wafer の変形を表します。項数は3次10、4次15、5次21で、X・Yで別々に推定します。',
    '1 shotを測ると4個のalignment markが得られます。少ないshotで多くの係数を決めるため、配置が悪いと計測誤差が補正値に大きく乗ります。',
    'D最適・I最適計画で配置を決める方法は昔からありますが、実際の工程では右の5つの要求も満たす必要があります。',
  ]);
  const cols = [
    { order: '3次', p: D.nmin['3'].p, nmin: D.nmin['3'].nmin },
    { order: '4次', p: D.nmin['4'].p, nmin: D.nmin['4'].nmin },
    { order: '5次', p: D.nmin['5'].p, nmin: D.nmin['5'].nmin },
  ];
  addText(slide, 'HOWA型モデルの項数（X・Yそれぞれ）', MARGIN_X, 1.6, 6, 0.35, { fontSize: 14, bold: true });
  cols.forEach((c, i) => {
    const x = MARGIN_X + i * 1.95;
    addCard(slide, x, 2.05, 1.75, 1.55, { fill: C.gray });
    addText(slide, String(c.p), x, 2.12, 1.75, 0.8, { fontSize: 40, bold: true, color: C.accentDark, align: 'center', valign: 'middle' });
    addText(slide, `${c.order}の項数`, x, 2.9, 1.75, 0.3, { fontSize: 12, align: 'center' });
    addText(slide, `最低${c.nmin} shot`, x, 3.2, 1.75, 0.3, { fontSize: 11, align: 'center', color: C.muted });
  });
  addBullets(slide, [
    '1 shot = 4 mark。最低限のshot数（full rankになる最小数）は3次3・4次4・5次6',
    '最低限に近いshot数では、配置しだいで推定がほぼ破綻する（例：5次6 shotのRandomは平均RMSが数百nm）',
    'alignment計測はスループットを直接下げるため、shot数は増やしたくない',
  ], MARGIN_X, 3.95, 5.6, 2.5, { fontSize: 13, space: 8 });
  addText(slide, '実工程で配置に求められること', 6.9, 1.6, 5.8, 0.35, { fontSize: 14, bold: true });
  const reqs = [
    ['象限', 'wafer四象限を概ね均等に測る'],
    ['半径領域', '中心・中間・外周の各領域を測る'],
    ['scan方向', 'Up/Downのshotを同数ずつ測る'],
    ['強制計測shot', '必ず測るshotを含める'],
    ['partial shot除外', '外周の欠けshotは測れない'],
  ];
  reqs.forEach(([head, body], i) => {
    const y = 2.05 + i * 0.86;
    addCard(slide, 6.9, y, 5.83, 0.72, { fill: C.gray });
    addChip(slide, head, 7.05, y + 0.16, 1.75, 0.4, { fill: C.accent, fontSize: 11.5 });
    addText(slide, body, 9.0, y + 0.1, 3.6, 0.52, { fontSize: 13, valign: 'middle' });
  });
}

// ====================================================================== 4. D最適の配置の問題
{
  const slide = newContentSlide('従来手法の課題', 'D最適だけで選ぶと、外周と中心に偏り、scan方向も片寄る', [
    `HOWA 4次・12 shotの例です。左の制約なしD最適は、外周（Outer）に${D.design_balance_howa4_n12.dopt.n_outer} shot、中間（Middle）に${D.design_balance_howa4_n12.dopt.n_middle} shotで、Up ${D.design_balance_howa4_n12.dopt.n_up}・Down ${D.design_balance_howa4_n12.dopt.n_down}と偏っています。`,
    `右の制約付きD最適は、Inner ${D.design_balance_howa4_n12.cdopt.n_inner}・Middle ${D.design_balance_howa4_n12.cdopt.n_middle}・Outer ${D.design_balance_howa4_n12.cdopt.n_outer}、Up ${D.design_balance_howa4_n12.cdopt.n_up}・Down ${D.design_balance_howa4_n12.cdopt.n_down}で、すべての上下限を満たします。`,
    `全次数・全shot数で数えると、制約なしD最適は半径領域の制約を${Math.round(D.violation.dopt.radial)}%、scan方向の制約を${Math.round(D.violation.dopt.scan)}%の設計で外しました。`,
  ]);
  const panels = [
    { key: 'base|dopt', title: '制約なしD最適', color: M.dopt.color, m: 'dopt' },
    { key: 'base|cdopt', title: '制約付きD最適（提案）', color: M.cdopt.color, m: 'cdopt' },
  ];
  panels.forEach((p, i) => {
    const cx = MARGIN_X + 2.1 + i * 4.55;
    const chosen = designSet(p.key);
    drawWafer(slide, cx, 4.05, 2.0, SHOTS, (s) => ({ fill: chosen.has(s.id) ? p.color : (s.cand ? C.candidate : C.partial) }),
      { scanMarks: (s) => chosen.has(s.id) });
    addText(slide, p.title, cx - 2.0, 1.55, 4.0, 0.35, { fontSize: 14, bold: true, align: 'center', color: i === 1 ? C.accentDark : C.ink });
    const b = D.design_balance_howa4_n12[p.m];
    addText(slide, `Inner ${b.n_inner}／Middle ${b.n_middle}／Outer ${b.n_outer}　Up ${b.n_up}／Down ${b.n_down}`, cx - 2.1, 6.15, 4.2, 0.3, { fontSize: 11.5, align: 'center' });
  });
  addCard(slide, 9.95, 1.6, 2.78, 4.95, { fill: C.gray });
  addText(slide, '図の見方', 10.15, 1.75, 2.4, 0.3, { fontSize: 12.5, bold: true });
  addBullets(slide, [
    '塗りのshot：選んだshot（▲Up／▼Down）',
    '薄い灰：候補shot（57）',
    'ごく薄い灰：partial shot（候補外）',
    '緑の破線：半径領域の境界（r = 0.5, 0.7）',
    '十字：象限の境界',
  ], 10.15, 2.15, 2.45, 2.3, { fontSize: 11, space: 4 });
  addText(slide, `半径領域の上下限（12 shot）：各2〜6 shot\nscan方向：Up・Down 各6 shot`, 10.15, 4.75, 2.45, 1.0, { fontSize: 11, color: C.muted });
  addSource(slide, 'HOWA 4次・12 shot（主評価条件）。results/csv/selected_shots.csv と design_metrics.csv');
}

// ====================================================================== 5. 手法のしくみ
{
  const slide = newContentSlide('提案手法', '制約を「区分ごとのshot数の上下限」にして、満たす入れ替えだけでD/I最適を探す', [
    '提案手法は、D最適・I最適の点交換法に、実務制約を整数の上下限として組み込んだものです。',
    '象限・半径領域・scan方向はどれも「区分ごとのshot数」で表せるので、同じ仕組みで扱えます。上下限はshot数に対する割合から自動で作ります。',
    '探索は modified Fedorov 交換法で、入れ替え後も上下限を満たす入れ替えだけを調べます。初期解を変えて200回、さらにD・Iの最良解を互いの初期解にして1回ずつ探します。',
    '強制計測shotは固定し、その情報量を含めたまま残りを選びます（拡張実験計画）。',
  ]);
  const steps = [
    ['候補shotを決める', 'shot矩形の4隅と4 markがusable領域（半径147 mm）内のshotだけ。107 shot中57 shotが候補'],
    ['上下限を作る', '象限：各1/4 ± max(5%×N, 1)\n半径：各1/3 ± max(10%×N, 1)\nscan：|Up − Down| ≤ 1'],
    ['制約付きで交換', '設計内のshotを1つずつ、上下限を満たす候補と入れ替え、D基準（log det）またはI基準（平均予測分散）が最も良くなる方に替える'],
    ['強制shotは拡張計画', '強制shotは外さず、その情報行列を含めた基準で残りを最適化する'],
  ];
  const w = (CONTENT_W - 0.3 * 3) / 4;
  steps.forEach(([title, body], i) => {
    const x = MARGIN_X + i * (w + 0.3);
    addStepCard(slide, x, 1.65, w, 2.1, i + 1, title, body, { bodySize: 12.5 });
    if (i < steps.length - 1) addLine(slide, x + w + 0.03, 2.7, x + w + 0.27, 2.7, { color: C.accent, width: 2, arrow: true });
  });
  addCard(slide, MARGIN_X, 4.1, CONTENT_W, 2.1, { fill: C.accentTint });
  addText(slide, '基準（大きいほど良い形にそろえて扱う）', MARGIN_X + 0.3, 4.28, 6, 0.3, { fontSize: 13, bold: true, color: C.accentDark });
  addBullets(slide, [
    'D最適：log det(M_{F} + M_{A}) を最大化（M は情報行列、F は強制shot、A は追加shot）',
    'I最適：wafer全面（5 mm格子）で平均した予測分散 tr(M^{-1}) を最小化',
    'soft制約も実装（上下限からのはみ出しshot数 × 重みλ を基準から引く）。主評価は hard 制約',
  ], MARGIN_X + 0.3, 4.72, CONTENT_W - 0.6, 1.4, { fontSize: 13.5, space: 6 });
}

// ====================================================================== 6. 評価の進め方
{
  const slide = newContentSlide('評価方法', '同じ1000枚の模擬waferで全手法を比べる（paired comparison）', [
    '真のwafer変形は、補正モデル（多項式）とは別の Fringe Zernike（動径次数7まで）で作りました。モデルで表せない成分が残る、現実に近い条件です。',
    '計測値には、scan方向に依存する誤差（Up/Downで符号が反転するoffsetと低次成分、方向で大きさが違うshotごとのばらつき）と、markごとの計測誤差を加えています。',
    '残差は、計測誤差を含まない真の変形と補正値の差を、partial shotを含む全有効mark 312点で評価しました。',
    '全手法で同じwafer・同じ誤差の乱数を使うので、waferごとの差をとって比べられます。',
  ]);
  const rows = [
    [headCell('項目'), headCell('条件（★は仮定値）')],
    [bodyCell('wafer・shot'), bodyCell('直径300 mm（edge exclusion 3 mm★）、shot 26×33 mm、候補57・partial 50')],
    [bodyCell('alignment mark'), bodyCell('1 shotに4点（shot中心から±12, ±15.5 mm★）')],
    [bodyCell('補正モデル'), bodyCell('HOWA型 3次（10項）・4次（15項）・5次（21項）、OLS')],
    [bodyCell('計測shot数'), bodyCell('N_{min}〜19 shot（= floor(57/3)）、1 shot刻み')],
    [bodyCell('真の変形'), bodyCell('Fringe Zernike 36項から10〜20項、σ_{k} = 3 nm / max(n, 1)、RMSは1〜8 nm★')],
    [bodyCell('scan方向の誤差★'), bodyCell('offset 0.3 nm＋1次成分0.5 nm（Up/Downで符号反転）＋shotごとのばらつき（Up 0.15・Down 0.25 nm）')],
    [bodyCell('mark計測誤差★'), bodyCell('1σ = 0.5 nm（0.25・1.0 nmでも評価）')],
    [bodyCell('wafer枚数'), bodyCell('1000枚（Randomは各条件200回抽選）')],
  ];
  addTableBox(slide, rows, MARGIN_X, 1.65, 7.2, [1.8, 5.4], { rowH: 0.48, fontSize: 11.5 });
  const regionFill = { Inner: 'CFE0F7', Middle: 'D3EEDC', Outer: 'F8DCC8' };
  const { toSlide } = drawWafer(slide, 10.35, 3.55, 1.85, SHOTS, (s) => ({ fill: s.cand ? regionFill[s.region] : C.partial }), { regions: false });
  SHOTS.filter((s) => s.mand).forEach((s) => {
    const [sx, sy] = toSlide([s.x, s.y]);
    addText(slide, '★', sx - 0.15, sy - 0.15, 0.3, 0.3, { fontSize: 11, color: C.ink, align: 'center', valign: 'middle' });
  });
  addLegendBox(slide, 8.5, 5.55, [[regionFill.Inner, 'Inner（r < 0.5）'], [regionFill.Middle, 'Middle（0.5〜0.7）'], [regionFill.Outer, 'Outer（r ≥ 0.7）']], 1.65);
  addLegendBox(slide, 10.55, 5.55, [[C.partial, 'partial shot（候補外）']], 1.8);
  addText(slide, '★ 強制計測shot（5 shot）', 10.55, 5.87, 2.2, 0.3, { fontSize: 11, valign: 'middle' });
  addText(slide, '評価点：全有効mark 312点（候補228＋partial 84）', 8.5, 6.55, 4.2, 0.3, { fontSize: 10.5, color: C.muted });
}

// ====================================================================== 7. 比べた手法
{
  const slide = newContentSlide('比較した手法', '7つの選び方を、同じshot数・同じwaferで比べた', [
    'Random・Poisson・Humanは最適化を使わない比較対象です。Humanは人の配置を模擬したルール（中心＋2つの円の上に等角度）で作りました。実際の配置をCSVで読み込むこともできます。',
    'D-opt・I-optは制約なしの最適計画、制約付きD-opt・I-optが提案法です。',
    '強制計測shotありの条件では、これに加えて、強制shotの情報を無視して残りを選ぶ素朴な方法（Naive）と、情報を考慮する拡張計画（Augmentation）を比べました。',
  ]);
  const items = [
    ['random', '候補から一様に抽選。200回のうち平均RMSが中央値の回を代表に', '最適化なし'],
    ['poisson', '点どうしの距離ができるだけ大きくなるよう空間的に均等に選ぶ', '最適化なし'],
    ['human', '中心＋2つの円の上に等角度に置き、最寄りのshotを選ぶ', '最適化なし'],
    ['dopt', '情報行列の行列式を最大化（係数の推定精度）', '制約なし'],
    ['iopt', 'wafer全面の平均予測分散を最小化（補正値の精度）', '制約なし'],
    ['cdopt', 'D最適を、象限・半径・scan方向の上下限の中で探す', '提案'],
    ['ciopt', 'I最適を、象限・半径・scan方向の上下限の中で探す', '提案'],
  ];
  items.forEach(([key, desc, kind], i) => {
    const col = i < 4 ? 0 : 1;
    const row = i < 4 ? i : i - 4;
    const x = MARGIN_X + col * 6.15;
    const y = 1.65 + row * 1.25;
    addCard(slide, x, y, 5.95, 1.08, { fill: kind === '提案' ? C.accentTint : C.gray });
    addDot(slide, x + 0.35, y + 0.54, 0.3, M[key].color);
    addText(slide, M[key].label, x + 0.65, y + 0.12, 2.2, 0.38, { fontSize: 14, bold: true, valign: 'middle' });
    addChip(slide, kind, x + 4.75, y + 0.15, 1.0, 0.3, { fill: kind === '提案' ? C.accent : C.muted, fontSize: 10 });
    addText(slide, desc, x + 0.65, y + 0.52, 5.1, 0.48, { fontSize: 12, color: C.muted, valign: 'middle' });
  });
  addCard(slide, MARGIN_X + 6.15, 1.65 + 3 * 1.25, 5.95, 1.08, { fill: C.white, line: C.line });
  addText(slide, '強制計測shotあり：上の手法に強制shotを含めたものと、Naive・Augmentation（提案）を比較', MARGIN_X + 6.4, 1.65 + 3 * 1.25 + 0.12, 5.5, 0.84, { fontSize: 11.5, valign: 'middle' });
}

// ====================================================================== 8. 結果① 制約
{
  const slide = newContentSlide('結果①　制約を守れたか', '制約を必ず満たしたのは提案法だけ。ほかの手法は大半の設計で違反', [
    '全次数・全shot数の設計（各手法47設計、Randomは抽選）について、いずれかの制約（象限・半径領域・scan方向）を外した割合です。',
    `制約なしのD最適は${Math.round(D.violation.dopt.any)}%、I最適は${Math.round(D.violation.iopt.any)}%の設計で違反しました。主に半径領域とscan方向です。`,
    `Humanは象限は満たしますが、scan方向の制約を${Math.round(D.violation.human.scan)}%の設計で外しました。列ごとにUp/Downが交互になるshot配置で、対称な配置を選ぶとUp/Downが片寄るためです。`,
    '提案法（制約付きD/I最適）は、強制計測shotありの条件も含めて違反0でした。自動テストでも確認しています。',
  ]);
  const keys = ['random', 'poisson', 'human', 'dopt', 'iopt', 'cdopt', 'ciopt'];
  const data = [{ name: 'いずれかの制約に違反した割合', labels: keys.map((k) => M[k].label), values: keys.map((k) => D.violation[k].any) }];
  slide.addChart(pres.charts.BAR, data, chartBase({
    x: MARGIN_X, y: 1.55, w: 7.6, h: 5.2, barDir: 'bar', chartColors: keys.map((k) => M[k].color),
    showValue: true, dataLabelFormatCode: '0"%"', dataLabelPosition: 'outEnd', dataLabelColor: C.ink,
    valAxisMinVal: 0, valAxisMaxVal: 100, valAxisMajorUnit: 25, valAxisLabelFormatCode: '0"%"',
    catAxisOrientation: 'maxMin', barGapWidthPct: 45, showLegend: false,
  }));
  const rows = [
    [headCell('手法'), headCell('象限'), headCell('半径'), headCell('scan')],
    ...['random', 'poisson', 'human', 'dopt', 'iopt', 'cdopt', 'ciopt'].map((k) => [
      bodyCell(M[k].label), bodyCell(`${Math.round(D.violation[k].quadrant)}%`, { align: 'right' }),
      bodyCell(`${Math.round(D.violation[k].radial)}%`, { align: 'right' }), bodyCell(`${Math.round(D.violation[k].scan)}%`, { align: 'right' }),
    ]),
  ];
  addText(slide, '制約ごとの違反の割合', 8.6, 1.6, 4, 0.3, { fontSize: 13, bold: true });
  addTableBox(slide, rows, 8.6, 2.0, 4.13, [1.73, 0.8, 0.8, 0.8], { rowH: 0.42, fontSize: 11.5 });
  addSource(slide, 'Randomは200抽選のうち違反した抽選の割合。results/csv/design_metrics.csv、random_draw_design_summary.csv');
}

// ====================================================================== 9. 結果② 残差とshot数
{
  const slide = newContentSlide('結果②　補正残差とshot数', '最適化した配置は少ないshot数で強い。Random・Humanは少shotで破綻する', [
    '1000 waferの平均Residual RMS（全有効mark）を計測shot数に対して描いたものです。縦軸は対数です。灰色の帯はRandom 200抽選の平均RMSの最良〜P95、点線はモデルで表せない成分による下限です。',
    `最適化した4手法（青・紫）はほぼ重なり、Poisson・Human・Randomより下にあります。5次の12 shotでは、D-opt ${fmt2(rms(5, 'dopt', 12))}、制約付きD-opt ${fmt2(rms(5, 'cdopt', 12))}、Poisson ${fmt2(rms(5, 'poisson', 12))}、Human ${fmt2(rms(5, 'human', 12))} nmでした。`,
    `Poissonはshot数によって外周のshotを含むかどうかが変わるため、残差が上下します（5次で12 shot ${fmt2(rms(5, 'poisson', 12))}、13 shot ${fmt2(rms(5, 'poisson', 13))}、15 shot ${fmt2(rms(5, 'poisson', 15))} nm）。`,
  ]);
  addImageFit(slide, path.join(FIG_DIR, 'fig03_rms_vs_shots_base.png'), MARGIN_X, 1.5, CONTENT_W, 4.75);
  addTakeaway(slide, `12 shotの平均RMS（5次）：制約付きD-opt ${fmt2(rms(5, 'cdopt', 12))} nm ／ Human ${fmt2(rms(5, 'human', 12))} nm ／ Poisson ${fmt2(rms(5, 'poisson', 12))} nm ／ Random ${fmt2(rms(5, 'random', 12))} nm`, MARGIN_X, 6.3, CONTENT_W, 0.55, { fontSize: 12.5 });
}

// ====================================================================== 10. 結果③ 従来配置との比較
{
  const slide = newContentSlide('結果③　従来の配置との比較', '提案法はHuman・Poisson・Randomより補正残差が明確に小さい', [
    '提案法（制約付きD最適）の平均RMSが、比較手法よりどれだけ小さいかを、N=8〜19の各shot数で求め、その中央値を示しています。',
    `Humanより${Math.round(humanImp[0])}%・${Math.round(humanImp[1])}%・${Math.round(humanImp[2])}%（3・4・5次）、Poissonより${Math.round(poissonImp[0])}%・${Math.round(poissonImp[1])}%・${Math.round(poissonImp[2])}%小さい値です。高次ほど差が大きくなります。`,
    'waferを復元抽出したbootstrapの95%信頼区間は、Human・Randomに対しては全shot数で0を上回り、Poissonに対しても12点中11〜12点で0を上回りました。',
    `${N_REF} shotで提案法の方が残差が小さかったwaferの割合（勝率）は、Humanに対して ${D.paired_ref['3|cdopt|human'].win.toFixed(2)}・${D.paired_ref['4|cdopt|human'].win.toFixed(2)}・${D.paired_ref['5|cdopt|human'].win.toFixed(2)} でした。`,
  ]);
  const data = [3, 4, 5].map((o) => ({
    name: `HOWA ${o}次`, labels: ['Humanに対して', 'Poissonに対して', 'Randomに対して'],
    values: [imp(o, 'cdopt', 'human'), imp(o, 'cdopt', 'poisson'), imp(o, 'cdopt', 'random')],
  }));
  slide.addChart(pres.charts.BAR, data, chartBase({
    x: MARGIN_X, y: 1.55, w: 8.1, h: 5.2, barDir: 'col', barGrouping: 'clustered', chartColors: [ORDER_COLORS[3], ORDER_COLORS[4], ORDER_COLORS[5]],
    showValue: true, dataLabelFormatCode: '0"%"', dataLabelPosition: 'outEnd', dataLabelColor: C.ink,
    valAxisMinVal: 0, valAxisMaxVal: 100, valAxisMajorUnit: 20, valAxisLabelFormatCode: '0"%"',
    showLegend: true, legendPos: 't', barGapWidthPct: 60,
    showTitle: true, title: '提案法（制約付きD最適）の平均RMSの低減率（N=8〜19の中央値）', titleFontSize: 12, titleColor: C.ink,
  }));
  addCard(slide, 9.0, 1.65, 3.73, 4.1, { fill: C.gray });
  addText(slide, `${N_REF} shotでの比較（5次）`, 9.2, 1.8, 3.4, 0.3, { fontSize: 13, bold: true });
  const p = (comp) => D.paired_ref[`5|cdopt|${comp}`];
  const pairRows = [[headCell('相手'), headCell('改善率'), headCell('95%CI'), headCell('勝率')]];
  ['human', 'poisson', 'random'].forEach((comp) => {
    pairRows.push([bodyCell(M[comp].label), bodyCell(`${fmt1(p(comp).imp)}%`, { align: 'right' }),
      bodyCell(`${fmt1(p(comp).lo)}〜${fmt1(p(comp).hi)}`, { align: 'center' }), bodyCell(fmt2(p(comp).win), { align: 'right' })]);
  });
  addTableBox(slide, pairRows, 9.2, 2.25, 3.35, [0.85, 0.75, 1.1, 0.65], { rowH: 0.45, fontSize: 10.5 });
  addText(slide, '改善率はwaferごとの値の平均。95%CIはwaferを復元抽出したbootstrap（2000回）。勝率は提案法の方が残差が小さかったwaferの割合', 9.2, 4.3, 3.35, 1.3, { fontSize: 10.5, color: C.muted });
  addSource(slide, 'results/csv/paired_comparison.csv（主評価条件、強制計測shotなし）');
}

// ====================================================================== 11. 結果④ shot削減
{
  const slide = newContentSlide('結果④　必要な計測shot数', 'Humanと同じ補正残差を、3〜6割少ないshotで達成できる', [
    'Humanの配置で12 shot・19 shotを測ったときの平均RMSを目標とし、各手法がその値以下になる最小のshot数を求めました。',
    `提案法（制約付きD最適）は、Humanの12 shotに対して${red12.join('・')} shot（3・4・5次）、19 shotに対して${red19.join('・')} shotでした。`,
    'waferごとのRMSの95%点（悪い側の5%）を目標にしても、必要なshot数はほぼ同じでした。',
    '制約なしのD最適はさらに1 shot程度少なくて済みますが、制約を満たしません。',
  ]);
  const methods = ['poisson', 'cdopt', 'dopt'];
  [12, 19].forEach((nref, k) => {
    const data = methods.map((m) => ({ name: M[m].label, labels: ['3次', '4次', '5次'], values: [3, 4, 5].map((o) => red(o, nref, m)) }));
    slide.addChart(pres.charts.BAR, data, chartBase({
      x: MARGIN_X + k * 6.1, y: 1.55, w: 5.9, h: 4.6, barDir: 'col', barGrouping: 'clustered', chartColors: methods.map((m) => M[m].color),
      showValue: true, dataLabelFormatCode: '0', dataLabelPosition: 'outEnd', dataLabelColor: C.ink,
      valAxisMinVal: 0, valAxisMaxVal: 20, valAxisMajorUnit: 5, showLegend: true, legendPos: 't', barGapWidthPct: 55,
      showTitle: true, title: `Humanの${nref} shotと同じ平均RMSに必要なshot数`, titleFontSize: 12, titleColor: C.ink,
    }));
  });
  addTakeaway(slide, `提案法の削減率：Humanの12 shotに対して ${red12.map((n) => `${reductionPct(12, n)}%`).join('・')}、19 shotに対して ${red19.map((n) => `${reductionPct(19, n)}%`).join('・')}（3・4・5次）`, MARGIN_X, 6.25, CONTENT_W, 0.6, { fontSize: 13 });
}

// ====================================================================== 12. 結果⑤ 制約の代償
{
  const slide = newContentSlide('結果⑤　制約の代償', '制約なしのD最適と比べると、高次ほど残差が増える。ただしwafer内側では逆転する', [
    '提案法の平均RMSが、制約なしのD最適より何%小さいかを、全有効mark（partial shotを含む312点）と、wafer内側（候補shotのmark 228点）で比べています。N=8〜19の中央値です。',
    `全有効markでは3次${pct0(doptImp[0])}、4次${pct0(doptImp[1])}、5次${pct0(doptImp[2])}と、高次ほど提案法が不利です。`,
    `wafer内側だけでは3次+${fmt1(D.interior_improvement['3'])}%、4次+${fmt1(D.interior_improvement['4'])}%、5次+${fmt1(D.interior_improvement['5'])}%で、提案法の方が良くなります。`,
    '半径領域の上限で最外周のshotが減るため、partial shot領域への外挿が悪くなり、その分wafer内側が良くなっています。どちらを重視するかは製品dieの配置で決まります。',
  ]);
  const data = [
    { name: '全有効mark（312点）', labels: ['3次', '4次', '5次'], values: doptImp },
    { name: 'wafer内側だけ（228点）', labels: ['3次', '4次', '5次'], values: [3, 4, 5].map((o) => D.interior_improvement[String(o)]) },
  ];
  slide.addChart(pres.charts.BAR, data, chartBase({
    x: MARGIN_X, y: 1.55, w: 7.3, h: 5.25, barDir: 'col', barGrouping: 'clustered', chartColors: [C.bad, C.good],
    showValue: true, dataLabelFormatCode: '+0.0"%";-0.0"%"', dataLabelPosition: 'outEnd', dataLabelColor: C.ink,
    valAxisMinVal: -10, valAxisMaxVal: 8, valAxisMajorUnit: 2, valAxisLabelFormatCode: '+0"%";-0"%";0"%"',
    showLegend: true, legendPos: 't', barGapWidthPct: 60,
    showTitle: true, title: '制約なしD最適に対する提案法の改善率（正なら提案法が良い）', titleFontSize: 12, titleColor: C.ink,
  }));
  // 右：評価点の領域
  const cx = 10.45;
  const cy = 3.85;
  drawWafer(slide, cx, cy, 1.9, SHOTS, (s) => ({ fill: s.cand ? 'B9D3F2' : 'F4C7A7' }), { regions: false });
  addLegendBox(slide, 8.4, 6.0, [['B9D3F2', '候補shot（wafer内側）'], ['F4C7A7', 'partial shot（外挿になる外周）']]);
  addSource(slide, 'results/csv/paired_comparison.csv、aggregated_metrics.csv（主評価条件）');
}

function addLegendBox(slide, x, y, items, labelW = 4.0) {
  items.forEach(([color, label], i) => {
    addRect(slide, x, y + i * 0.32 + 0.05, 0.25, 0.2, { fill: color, line: C.muted, lineWidth: 0.5 });
    addText(slide, label, x + 0.35, y + i * 0.32, labelW, 0.3, { fontSize: 11, valign: 'middle' });
  });
}

// ====================================================================== 13. 結果⑥ 外周とtail
{
  const slide = newContentSlide('結果⑥　残差がどこに残るか', '提案法は外周（partial shot）の残差がやや大きく、wafer内側の残差が小さい', [
    `${N_REF} shotでの1000 waferの平均値です。外周RMSは、waferごとの全体RMSと内側RMSからpartial shotのmark（84点）だけのRMSを求めたものです。`,
    `5次では、制約なしD最適の外周RMS ${fmt2(D.tail_ref['5|dopt'].edge)} nmに対して提案法は${fmt2(D.tail_ref['5|cdopt'].edge)} nmで、wafer内の最大残差も${fmt2(D.tail_ref['5|dopt'].max)}→${fmt2(D.tail_ref['5|cdopt'].max)} nmに増えます。`,
    `一方、wafer内側のRMSは${fmt2(D.tail_ref['5|dopt'].interior)}→${fmt2(D.tail_ref['5|cdopt'].interior)} nmで、提案法の方が小さくなります。`,
    'waferごとのRMSの95%点（1000枚の中の悪い側）は平均値と同じ順位でした。',
  ]);
  const head = [headCell('次数'), headCell('手法'), headCell('平均RMS'), headCell('内側RMS'), headCell('外周RMS'), headCell('P95（wafer）'), headCell('最大残差')];
  const rows = [head];
  [3, 4, 5].forEach((o) => {
    ['dopt', 'cdopt', 'human'].forEach((m, j) => {
      const t = D.tail_ref[`${o}|${m}`];
      const opts = m === 'cdopt' ? { fill: { color: C.accentTint } } : {};
      rows.push([
        bodyCell(j === 0 ? `${o}次` : '', { ...opts, align: 'center' }), bodyCell(M[m].label, opts),
        bodyCell(fmt2(t.mean), { ...opts, align: 'right' }), bodyCell(fmt2(t.interior), { ...opts, align: 'right' }),
        bodyCell(fmt2(t.edge), { ...opts, align: 'right' }), bodyCell(fmt2(t.p95w), { ...opts, align: 'right' }),
        bodyCell(fmt2(t.max), { ...opts, align: 'right' }),
      ]);
    });
  });
  addTableBox(slide, rows, MARGIN_X, 1.6, 8.2, [0.8, 1.9, 1.1, 1.1, 1.1, 1.1, 1.1], { rowH: 0.42, fontSize: 11.5 });
  addText(slide, `単位はnm。${N_REF} shot、主評価条件。内側＝候補shotのmark、外周＝partial shotのmark`, MARGIN_X, 6.0, 8.2, 0.3, { fontSize: 10.5, color: C.muted });
  addCard(slide, 9.1, 1.6, 3.63, 4.2, { fill: C.gray });
  addText(slide, '読み取り方', 9.3, 1.75, 3.2, 0.3, { fontSize: 13, bold: true });
  addBullets(slide, [
    '外周を重視するなら、半径領域の目標を外周寄りにするか、Innerの下限を緩める',
    'wafer内側（製品die）を重視するなら、提案法の既定の制約で良い',
    '最大残差は外周の外挿で決まるため、P99・Maxで判断する場合は特に注意',
  ], 9.3, 2.2, 3.25, 3.4, { fontSize: 12, space: 10 });
}

// ====================================================================== 14. 結果⑦ scan方向・計測誤差
{
  const slide = newContentSlide('結果⑦　誤差の大きさへの強さ', 'scan方向依存の誤差が大きいほど、提案法が有利になる', [
    `${N_REF} shotで、scan方向依存成分の大きさ（名目値に対する倍率）とmark計測誤差を変えたときの、制約なしD最適に対する提案法の改善率です。`,
    `scan成分が大きいほど提案法が有利になり、3次では4倍で+${fmt1(D.scan['3'][4].imp)}%、5次でも4倍で${pct0(D.scan['5'][4].imp)}まで差が縮まりました。scan方向の数をそろえることで、Up/Downで符号が変わる誤差の写り込みが減るためです。`,
    `ただし、数をそろえるだけで常に良くなるわけではありません（3次8 shotでは4倍でも${pct0(D.scan_n8_howa3_x4)}）。`,
    'mark計測誤差が大きいと、5次では提案法の不利が広がりました。制約付き設計は効率がやや低く、誤差を増幅しやすいためです。',
  ]);
  const scanLabels = D.scan['3'].map((r) => `${r.scale}倍`);
  const scanData = [3, 4, 5].map((o) => ({ name: `${o}次`, labels: scanLabels, values: D.scan[String(o)].map((r) => r.imp) }));
  slide.addChart(pres.charts.LINE, scanData, chartBase({
    x: MARGIN_X, y: 1.55, w: 6.0, h: 4.9, chartColors: [ORDER_COLORS[3], ORDER_COLORS[4], ORDER_COLORS[5]], lineSize: 2.5,
    lineDataSymbol: 'circle', lineDataSymbolSize: 8, showLegend: true, legendPos: 't',
    valAxisMinVal: -20, valAxisMaxVal: 25, valAxisMajorUnit: 5, valAxisLabelFormatCode: '+0"%";-0"%";0"%"',
    showTitle: true, title: 'scan方向依存成分の倍率と改善率', titleFontSize: 12, titleColor: C.ink,
    catAxisTitle: 'scan方向依存成分（名目値に対する倍率）', showCatAxisTitle: true, catAxisTitleFontSize: 10.5, catAxisTitleColor: C.muted,
  }));
  const noiseLabels = D.noise['3'].map((r) => `${r.sigma} nm`);
  const noiseData = [3, 4, 5].map((o) => ({ name: `${o}次`, labels: noiseLabels, values: D.noise[String(o)].map((r) => r.imp) }));
  slide.addChart(pres.charts.LINE, noiseData, chartBase({
    x: MARGIN_X + 6.15, y: 1.55, w: 5.98, h: 4.9, chartColors: [ORDER_COLORS[3], ORDER_COLORS[4], ORDER_COLORS[5]], lineSize: 2.5,
    lineDataSymbol: 'circle', lineDataSymbolSize: 8, showLegend: true, legendPos: 't',
    valAxisMinVal: -20, valAxisMaxVal: 25, valAxisMajorUnit: 5, valAxisLabelFormatCode: '+0"%";-0"%";0"%"',
    showTitle: true, title: 'mark計測誤差（1σ）と改善率', titleFontSize: 12, titleColor: C.ink,
    catAxisTitle: 'mark計測誤差 1σ', showCatAxisTitle: true, catAxisTitleFontSize: 10.5, catAxisTitleColor: C.muted,
  }));
  addTakeaway(slide, '縦軸：制約なしD最適に対する提案法の平均RMSの改善率（正なら提案法が良い）。名目条件は scan 1倍・誤差 0.5 nm', MARGIN_X, 6.35, CONTENT_W, 0.5, { fontSize: 11.5, fill: C.gray, color: C.ink });
}

// ====================================================================== 15. 結果⑧ 強制計測shot
{
  const slide = newContentSlide('結果⑧　強制計測shot', '追加shotが少ないときは、強制shotの情報量を考慮する拡張計画が有効', [
    '強制計測shot（中心と上下左右の5 shot）を必ず含める条件で、強制shotの情報量を考慮して残りを選ぶ拡張計画と、考慮せずに選んで後から足す素朴な方法（Naive）を比べました。',
    `拡張計画の残差は、追加shotが少ないほどNaiveより小さく、5次では9 shotで${fmt1(augRows(5).find((r) => r.n === 9).cd)}%、12 shotで${fmt1(augRows(5).find((r) => r.n === 12).cd)}%小さくなりました（制約付きD基準）。`,
    'Naiveは4次・5次の7 shot（追加2 shot）で設計がrank不足になり、補正係数を推定できませんでした。拡張計画は全shot数で推定できました。',
    `一方、制約付きD基準の11 shotでは、全次数でNaiveの方が有意に小さくなりました（${augN11.map((v) => fmt1(-v)).join('・')}%、3・4・5次）。制約付きI基準の11 shotでは拡張計画の方が小さい結果でした（${augN11I.map((v) => fmt1(v)).join('・')}%）。`,
    'D基準の拡張計画は11 shotでも情報量（D-efficiency）はNaiveより大きいのですが、4次・5次では平均予測分散（I-efficiency）が逆に悪く、これが主な理由と考えられます。最良値に届いた初期解は半数を超えており、探索不足ではありません。3次の理由は確認していません。報告書8.9節にも記載しています。',
    `13 shot以上の差は${Math.ceil(Math.max(...augLate))}%以内で、Naiveが有意に良い点もあります。強制shotの割合が大きい（追加shotが少ない）ほど、拡張計画を使う意味が大きくなります。`,
  ]);
  const ns = augRows(5).map((r) => String(r.n));
  const data = [3, 4, 5].map((o) => ({ name: `${o}次`, labels: ns, values: augRows(o).map((r) => (r.cd === null ? null : r.cd)) }));
  slide.addChart(pres.charts.LINE, data, chartBase({
    x: MARGIN_X, y: 1.55, w: 7.6, h: 5.2, chartColors: [ORDER_COLORS[3], ORDER_COLORS[4], ORDER_COLORS[5]], lineSize: 2.5,
    lineDataSymbol: 'circle', lineDataSymbolSize: 8, showLegend: true, legendPos: 't',
    valAxisMinVal: -20, valAxisMaxVal: 80, valAxisMajorUnit: 20, valAxisLabelFormatCode: '+0"%";-0"%";0"%"',
    showTitle: true, title: 'Naiveに対する拡張計画の改善率（制約付きD基準、平均RMS）', titleFontSize: 12, titleColor: C.ink,
    catAxisTitle: '計測shot数（強制shot 5を含む）', showCatAxisTitle: true, catAxisTitleFontSize: 10.5, catAxisTitleColor: C.muted,
  }));
  addCard(slide, 8.5, 1.6, 4.23, 3.75, { fill: C.gray });
  addText(slide, '強制shotそのものの影響（5次）', 8.7, 1.75, 3.9, 0.3, { fontSize: 13, bold: true });
  const rows = [[headCell('shot数'), headCell('強制shotなし'), headCell('強制shotあり（拡張計画）')]];
  [7, 9, 12, 19].forEach((n) => {
    const r = augRows(5).find((x) => x.n === n);
    rows.push([bodyCell(String(n), { align: 'center' }), bodyCell(fmt2(r.cdopt_base), { align: 'right' }), bodyCell(fmt2(r.cdopt_aug), { align: 'right' })]);
  });
  addTableBox(slide, rows, 8.7, 2.2, 3.85, [0.8, 1.3, 1.75], { rowH: 0.42, fontSize: 11.5 });
  addText(slide, '平均RMS [nm]、制約付きD最適。強制shotが計測の大半を占める少shot側では、外周を測る余地がなくなり残差が増える。19 shotではほぼ差がない', 8.7, 4.4, 3.85, 0.85, { fontSize: 11, color: C.muted });
  addCard(slide, 8.5, 5.55, 4.23, 1.2, { fill: C.badTint });
  addText(slide, `注意：制約付きD基準の11 shotでは、全次数でNaiveの方が有意に小さい（${fmt1(-Math.max(...augN11))}〜${fmt1(-Math.min(...augN11))}%）。I基準の拡張計画は11 shotでもNaiveより良い`, 8.7, 5.65, 3.85, 1.0, { fontSize: 11.5, valign: 'middle' });
  addSource(slide, 'results/csv/paired_comparison.csv（mandatory）、aggregated_metrics.csv');
}

// ====================================================================== 16. 結果⑨ 最適性と実補正性能
{
  const slide = newContentSlide('結果⑨　最適性の数値と実際の残差', 'D/I-efficiencyは目安になるが、最終判断には補正後の残差が必要', [
    '横軸は制約なしの最適計画を1とした効率、縦軸は同じshot数の制約なし最適に対する平均RMSの比です（全shot数の設計を点で表示）。',
    '効率が0.5未満（Random・Humanの少shot）では残差が1.5倍〜10倍以上になり（10倍を超える点は図の上端で切っています）、効率と残差の関係ははっきりしています。',
    `一方、効率0.85〜1.0の範囲では順位が一致しません。3次では提案法（D-efficiencyの中央値${fmt2(D.eff_median['3|cdopt'].d)}）の方がD最適（1.0）より残差が小さいshot数が多くありました（12点中${D.improvement['3|cdopt|dopt'].better}点で有意に小さく、${D.improvement['3|cdopt|dopt'].worse}点で有意に大きい）。D/I基準は計測誤差による分散だけを見ており、モデルで表せない成分やscan成分の写り込みを含まないためです。`,
    `提案法のD-efficiencyの中央値は3次${fmt2(D.eff_median['3|cdopt'].d)}・4次${fmt2(D.eff_median['4|cdopt'].d)}・5次${fmt2(D.eff_median['5|cdopt'].d)}でした。`,
  ]);
  addImageFit(slide, path.join(FIG_DIR, 'fig11_tradeoff_efficiency_vs_rms.png'), MARGIN_X, 1.5, 8.1, 5.35, { align: 'left' });
  addCard(slide, 9.0, 1.6, 3.73, 4.3, { fill: C.gray });
  addText(slide, 'D-efficiency の中央値', 9.2, 1.75, 3.4, 0.3, { fontSize: 13, bold: true });
  const rows = [[headCell('手法'), headCell('3次'), headCell('4次'), headCell('5次')]];
  [['random', 'Random'], ['human', 'Human'], ['poisson', 'Poisson'], ['cdopt', '制約付きD-opt'], ['ciopt', '制約付きI-opt']].forEach(([m, label]) => {
    rows.push([bodyCell(label), ...[3, 4, 5].map((o) => bodyCell(fmt2(D.eff_median[`${o}|${m}`].d), { align: 'right' }))]);
  });
  addTableBox(slide, rows, 9.2, 2.2, 3.35, [1.55, 0.6, 0.6, 0.6], { rowH: 0.42, fontSize: 10.5 });
  addText(slide, '制約なしD最適を1とする。Human・Poisson・RandomはN=8〜19（Randomは各shot数の抽選の中央値）、制約付きは全shot数の中央値', 9.2, 4.88, 3.35, 0.85, { fontSize: 10.5, color: C.muted });
}

// ====================================================================== 17. 結果⑩ soft制約
{
  const slide = newContentSlide('結果⑩　soft制約（罰則）での調整', 'scan方向は小さな罰則でそろう。半径領域をそろえるには大きな罰則が要る', [
    '制約を必ず守るhard制約の代わりに、上下限からはみ出したshot数×重みλを基準から引くsoft制約も評価しました（4次・12 shot、D基準）。',
    'λ=0.1程度でscan方向の違反は0になり、D-efficiencyの低下は5%以内でした。scan方向の均等化は、最適性をほとんど損なわずに満たせます。',
    '半径領域の違反を0にするにはλ≥0.5が必要で、D-efficiencyは約0.91まで下がりました。',
    '平均RMSは、半径の違反を2 shotだけ許したλ=0.1〜0.2が最も小さい値でした。制約を少し緩めると最も良くなる場合があります。運用では上下限そのものを調整する方が扱いやすいと考えます。',
  ]);
  const lams = softD.map((r) => r.lam);
  const head = [headCell('重み λ'), ...lams.map((l) => headCell(String(l)))];
  const rows = [
    head,
    [bodyCell('scan方向の違反 [shot]'), ...softD.map((r) => bodyCell(String(r.viol_scan), { align: 'center' }))],
    [bodyCell('半径領域の違反 [shot]'), ...softD.map((r) => bodyCell(String(r.viol_radial), { align: 'center' }))],
    [bodyCell('D-efficiency'), ...softD.map((r) => bodyCell(fmt2(r.d_eff), { align: 'center' }))],
    [bodyCell('平均RMS [nm]'), ...softD.map((r) => bodyCell(fmt2(r.rms), { align: 'center', bold: r.rms === Math.min(...softD.map((x) => x.rms)) }))],
  ];
  addTableBox(slide, rows, MARGIN_X, 1.7, CONTENT_W, [2.6, ...lams.map(() => (CONTENT_W - 2.6) / lams.length)], { rowH: 0.5, fontSize: 12 });
  const best = softD.reduce((a, b) => (b.rms < a.rms ? b : a));
  addStepCard(slide, MARGIN_X, 4.55, 3.85, 1.65, 1, 'scan方向', '小さな罰則（λ≈0.1）で違反0。効率の低下は小さい → 常に課してよい制約', { bodySize: 12 });
  addStepCard(slide, MARGIN_X + 4.15, 4.55, 3.85, 1.65, 2, '半径領域', '違反0にはλ≥0.5が必要。効率が下がり、外周の外挿が悪くなる → 次数とshot数で目標を調整', { bodySize: 12 });
  addStepCard(slide, MARGIN_X + 8.3, 4.55, 3.83, 1.65, 3, '最良の点', `λ=${best.lam}（半径の違反${best.viol_radial} shot）で平均RMS ${fmt2(best.rms)} nm。制約を少し緩めた方が良い場合がある`, { bodySize: 12 });
  addSource(slide, 'results/csv/soft_constraint_study.csv（4次・12 shot、D基準）。D-efficiencyはλ=0（制約なしD最適）を1とする');
}

// ====================================================================== 18. 代表例
{
  const TW = D.typical_wafer;
  const slide = newContentSlide('代表例', '典型的なwaferの補正後残差：提案法のRMSが最小、Randomは外周で外れる', [
    '報告書のAppendixに載せた代表wafer 3例のうち、典型例（Sample 1）の、HOWA 4次・12 shotでの補正後の残差です。典型例は「全手法の平均RMSが1000枚の中央値に最も近いwafer」という決まったルールで選びました（提案法に有利な例を選んだものではありません）。',
    '背景の色が残差の大きさ、矢印が残差のベクトルで、色と矢印の尺度は全手法で共通です。各図の上に、そのwaferのRMS・P95・最大値を示しています。',
    `この条件では制約付きD最適と制約付きI最適は同じ配置で、RMS ${fmt2(TW.cdopt.rms)} nm・最大${fmt2(TW.cdopt.max)} nmでした。D-opt ${fmt2(TW.dopt.rms)} nm、Human ${fmt2(TW.human.rms)} nm、Random ${fmt2(TW.random.rms)} nmです。`,
    'Randomは測っていない左上と下側の外周で外挿が大きく外れています。改善が大きい例（Sample 2）と難しい例（Sample 3）は報告書のAppendixにあります。',
  ]);
  addImageFit(slide, path.join(FIG_DIR, 'A3_sample1_residual_base.png'), MARGIN_X, 1.45, CONTENT_W, 5.45);
}

// ====================================================================== 19. 計算時間
{
  const slide = newContentSlide('計算時間と最適化の安定性', `設計は1件数秒、全体で約${Math.round(D.timing_min.total)}分。設計は一度作れば使い回せる`, [
    `本計算全体（設計618件、Random 200抽選、7条件×1000 waferの評価、統計、soft制約、図）は約${Math.round(D.timing_min.total)}分でした（MATLAB R2022b、ノートPC、並列化なし）。`,
    `最適化した設計${D.design_count}件の1件あたりの計算時間は、D基準で平均${fmt1(D.design_time_s['D|3'].mean)}〜${fmt1(D.design_time_s['D|5'].mean)}秒、I基準で平均${fmt1(D.design_time_s['I|3'].mean)}〜${fmt1(D.design_time_s['I|5'].mean)}秒（最大${Math.round(D.design_time_s['I|5'].max)}秒、5次のI基準）でした（multi-start 201回の合計）。`,
    `制約付き問題は局所解が多く、最良値に届いた初期解の割合は中央値で制約付きD ${Math.round(100 * D.start_fraction_median.cdopt)}%・制約付きI ${Math.round(100 * D.start_fraction_median.ciopt)}%でした（制約なしは${Math.round(100 * D.start_fraction_median.iopt)}〜${Math.round(100 * D.start_fraction_median.dopt)}%）。回数を確かめたところ、20回では${D.multistart_conditions}条件中${D.multistart['20'].below}条件で400回の最良値に届かず（効率最大${fmt1(100 * (1 - D.multistart['20'].min))}%低い）、200回では${D.multistart_conditions - D.multistart['200'].below}条件で一致、残る${D.multistart['200'].below}条件も効率${fmt2(D.multistart['200'].min)}でした。`,
  ]);
  addStat(slide, MARGIN_X, 1.65, 3.85, 2.0, `約${Math.round(D.timing_min.total)}分`, '本計算全体（1000 wafer、7条件）');
  addStat(slide, MARGIN_X + 4.15, 1.65, 3.85, 2.0, `${fmt1(D.design_time_s['D|3'].mean)}〜${fmt1(D.design_time_s['I|5'].mean)}秒`, '最適化した設計1件の計算時間\n（平均、次数・基準による）');
  addStat(slide, MARGIN_X + 8.3, 1.65, 3.83, 2.0, `${D.multistart_conditions - D.multistart['200'].below}/${D.multistart_conditions}`, 'multi-start 200回で400回と同じ\n最良値に到達した条件');
  const rows = [[headCell('工程'), headCell('時間 [分]')]];
  [['3_designs', 'sampling設計（618件、Randomを除く）'], ['5_evaluation', 'Monte Carlo評価（Random抽選を含む）'], ['6_statistics', '統計（paired comparison・bootstrap）'], ['6_soft_constraint_study', 'soft制約の補助評価'], ['7_figures', '図']].forEach(([k, label]) => {
    rows.push([bodyCell(label), bodyCell(fmt1(D.timing_min[k]), { align: 'right' })]);
  });
  addTableBox(slide, rows, MARGIN_X, 4.0, 6.4, [5.0, 1.4], { rowH: 0.42, fontSize: 11.5 });
  addCard(slide, 7.35, 4.0, 5.38, 2.6, { fill: C.accentTint });
  addText(slide, '運用のイメージ', 7.55, 4.15, 5, 0.3, { fontSize: 13, bold: true, color: C.accentDark });
  addBullets(slide, [
    '設計は真値に依存しないので、shot配置・mark配置・制約・次数ごとにレシピ作成時に一度計算する',
    '制約や強制shotは設定ファイルで変えられる',
    '量産中に毎wafer計算する必要はない',
  ], 7.55, 4.55, 5.0, 1.95, { fontSize: 12, space: 6 });
}

// ====================================================================== 20. 使い分け
{
  const slide = newContentSlide('どの方式をいつ使うか', '制約を守る必要があるなら制約付きD最適。強制shotがあれば拡張計画', [
    '結果をもとに、どの条件でどの方式が有利かを整理しました。',
    '制約なしのD最適とI最適の残差の差は、大半の条件で数%以内でした。制約付きの5次ではD基準の方が残差が小さいshot数が多かった（12点中11点）ので、迷う場合は制約付きD最適を推奨します。',
    '強制計測shotがある場合は、必ず拡張計画（Augmentation）で残りを選んでください。',
  ]);
  const rows = [
    [headCell('観点'), headCell('有利な方式'), headCell('根拠（主評価条件）')],
    [bodyCell('実務制約を守る'), bodyCell('制約付きD/I最適', { bold: true, color: C.accentDark }), bodyCell('違反0。ほかの手法は77〜100%の設計で違反')],
    [bodyCell('補正残差（平均）'), bodyCell('制約付きD/I最適\n（制約不要なら制約なしD/I最適）', { bold: true, color: C.accentDark }), bodyCell(`Human比${Math.round(Math.min(...humanImp))}〜${Math.round(Math.max(...humanImp))}%、Poisson比${Math.round(Math.min(...poissonImp))}〜${Math.round(Math.max(...poissonImp))}%小さい。制約なしとの差は3次≈0、4次${pct0(doptImp[1])}、5次${pct0(doptImp[2])}`)],
    [bodyCell('外周（partial shot）の残差・最大残差'), bodyCell('制約なしD/I最適', { bold: true }), bodyCell('外周shotが多く外挿に強い。重視する場合は半径の目標を外周寄りに')],
    [bodyCell('計測shot数を減らす'), bodyCell('制約付きD/I最適', { bold: true, color: C.accentDark }), bodyCell(`Humanと同じ残差を${Math.min(...redPctAll)}〜${Math.max(...redPctAll)}%少ないshotで達成`)],
    [bodyCell('scan方向依存の誤差が大きい'), bodyCell('制約付きD/I最適', { bold: true, color: C.accentDark }), bodyCell(`3次12 shotでscan成分4倍のとき+${fmt1(D.scan['3'][4].imp)}%`)],
    [bodyCell('強制計測shotがある'), bodyCell('制約付きD/I最適の拡張計画', { bold: true, color: C.accentDark }), bodyCell(`追加shotが少ないときNaiveより最大${Math.round(augMaxImp)}%小さい。Naiveは少shotでrank不足（D基準の11 shotは逆転）`)],
  ];
  addTableBox(slide, rows, MARGIN_X, 1.65, CONTENT_W, [3.1, 3.3, 5.73], { rowH: 0.66, fontSize: 12 });
}

// ====================================================================== 21. 限界と次の一手
{
  const slide = newContentSlide('限界と次の一手', '結論の大きさは仮定値しだい。実データでの確認が次の段階', [
    'この評価は、乱数で生成した模擬データによるものです。特にscan方向依存の誤差の大きさで、提案法が有利になるか不利になるかが入れ替わります。',
    '真の変形は動径次数7までのZernikeで、外周の急な変形（edge rolloffなど）は含みません。局所的な変形があると、空間的に分散した配置の価値は高まると考えられます。',
    '交換法は発見的な方法で、大域最適の保証はありません。multi-start 200回で最良値との差は効率で1%未満でした。',
  ]);
  const left = [
    ['仮定値への依存', 'scan方向の誤差・計測誤差・真の変形の大きさは仮定値。結論の向きはscan方向の誤差で変わる'],
    ['評価の重み', 'partial shot領域を含む全markで評価。製品dieの分布で重み付けすると結論が変わりうる'],
    ['扱っていない範囲', 'mark単位の選択、markの計測失敗、shot内補正、lot間の動的sampling'],
  ];
  const right = [
    ['実データでの確認', '実際のwafer変形の高次成分、scan方向の誤差、mark計測誤差を測って入れ替える'],
    ['重みつきI最適', '製品dieのある領域で予測分散を平均するI最適で、外周と内側のバランスを取る'],
    ['頑健な設計', 'モデルで表せない成分や計測失敗に強い設計（ベイズ最適計画など）を試す'],
  ];
  addText(slide, '限界', MARGIN_X, 1.6, 5.9, 0.35, { fontSize: 15, bold: true, color: C.bad });
  addText(slide, '次の一手', MARGIN_X + 6.2, 1.6, 5.9, 0.35, { fontSize: 15, bold: true, color: C.good });
  left.forEach(([t, b], i) => {
    addCard(slide, MARGIN_X, 2.05 + i * 1.5, 5.9, 1.3, { fill: C.badTint });
    addText(slide, t, MARGIN_X + 0.25, 2.15 + i * 1.5, 5.4, 0.35, { fontSize: 13.5, bold: true });
    addText(slide, b, MARGIN_X + 0.25, 2.55 + i * 1.5, 5.4, 0.7, { fontSize: 12 });
  });
  right.forEach(([t, b], i) => {
    addCard(slide, MARGIN_X + 6.2, 2.05 + i * 1.5, 5.93, 1.3, { fill: C.goodTint });
    addText(slide, t, MARGIN_X + 6.45, 2.15 + i * 1.5, 5.4, 0.35, { fontSize: 13.5, bold: true });
    addText(slide, b, MARGIN_X + 6.45, 2.55 + i * 1.5, 5.4, 0.7, { fontSize: 12 });
  });
}

// ====================================================================== 22. まとめ
{
  const slide = pres.addSlide();
  pageNumber += 1;
  slide.background = { color: C.night };
  addText(slide, 'まとめ', MARGIN_X + 0.2, 0.6, 6, 0.6, { fontSize: 30, bold: true, color: C.white });
  const items = [
    ['制約を守る', '象限・半径領域・scan方向を整数の上下限にしてD/I最適に組み込み、全設計で制約違反0'],
    ['残差を減らす', `Human比${Math.round(Math.min(...humanImp))}〜${Math.round(Math.max(...humanImp))}%、Poisson比${Math.round(Math.min(...poissonImp))}〜${Math.round(Math.max(...poissonImp))}%小さい補正残差`],
    ['shotを減らす', `Humanと同じ残差を${Math.min(...redPctAll)}〜${Math.max(...redPctAll)}%少ないshotで達成`],
    ['代償を知る', `制約なしD最適比で4次${pct0(doptImp[1])}・5次${pct0(doptImp[2])}。外周shotの不足が主因で、内側だけなら提案法が有利`],
    ['強制shotは拡張計画', `固定shotの情報量を考慮して選ぶと、追加shotが少ないときNaiveより最大${Math.round(augMaxImp)}%小さく、rank不足も防げる`],
  ];
  items.forEach(([t, b], i) => {
    const y = 1.55 + i * 1.02;
    addCard(slide, MARGIN_X + 0.2, y, CONTENT_W - 0.4, 0.86, { fill: C.nightCard });
    addNode(slide, MARGIN_X + 0.62, y + 0.43, 0.46, C.accent, String(i + 1), { fontSize: 14 });
    addText(slide, t, MARGIN_X + 1.05, y + 0.1, 2.6, 0.66, { fontSize: 16, bold: true, color: C.white, valign: 'middle' });
    addText(slide, b, MARGIN_X + 3.7, y + 0.1, 8.1, 0.66, { fontSize: 14, color: C.onDark, valign: 'middle' });
  });
  addText(slide, '詳細：report/technical_report.tex（41ページ）、結果の数値：results/csv/', MARGIN_X + 0.2, 6.75, 10, 0.35, { fontSize: 11.5, color: C.onDarkSub });
  slide.addNotes([
    'まとめです。提案法は実務制約を必ず満たし、従来の配置より補正残差が小さく、同じ残差に必要なshot数を3〜6割減らせました。',
    '一方で、制約なしのD最適と比べると、高次では外周の外挿が悪くなる代償があります。半径領域の目標を次数とshot数に応じて調整することを推奨します。',
    '強制計測shotがある場合は、固定shotの情報量を考慮する拡張計画で残りを選んでください。',
    '数値は模擬データによる試算です。実データでの確認が次の段階です。',
  ].join('\n'));
}

// ====================================================================== 23. 付録：用語と指標
{
  const slide = newContentSlide('付録　用語と指標', '資料で使った用語と指標の定義', [
    '資料と報告書で使った用語と評価指標の定義です。詳しくは報告書の3章・7章を参照してください。',
  ]);
  const rows = [
    [headCell('用語・指標'), headCell('意味')],
    [bodyCell('HOWA型モデル'), bodyCell('正規化座標 u = x/150 mm、v = y/150 mm の総次数m以下の2変数多項式（ASML HOWAの再現ではない）')],
    [bodyCell('D最適 / I最適'), bodyCell('情報行列の行列式を最大化 / wafer全面の平均予測分散を最小化する計測点の選び方')],
    [bodyCell('拡張計画（Augmentation）'), bodyCell('既に固定された計測点（強制shot）の情報量を含めたまま、追加の点を最適化する方法')],
    [bodyCell('Residual RMS'), bodyCell('補正後の残差（真の変形 − 補正値）の二乗平均平方根。X・Yをまとめたvector RMS')],
    [bodyCell('D-efficiency / I-efficiency'), bodyCell('同じ次数・shot数の制約なしD最適 / I最適を1とした相対値（1に近いほど最適に近い）')],
    [bodyCell('B_{Q} / B_{R} / B_{S}'), bodyCell('象限ごと・半径領域ごとのshot数の最大−最小 / |Up − Down|')],
    [bodyCell('改善率'), bodyCell('(RMS_{比較} − RMS_{提案}) / RMS_{比較} × 100。正なら提案法が良い')],
    [bodyCell('partial shot'), bodyCell('wafer外周で欠けるshot。markが測れないので候補から除くが、補正は外挿で適用される')],
  ];
  addTableBox(slide, rows, MARGIN_X, 1.65, CONTENT_W, [3.2, 8.93], { rowH: 0.56, fontSize: 12 });
}

// ====================================================================== 24. 付録：参考文献
{
  const slide = newContentSlide('付録　参考文献（抜粋）', '主な参考文献（全38件は報告書の参考文献と references/references.json）', [
    '報告書で引用した文献から、本資料に関係の深いものを抜粋しました。全38件の書誌・入手状況は references/references.json と references/参考文献リンク.md にあります。',
  ]);
  addBullets(slide, [
    'J. S. Wildenberg, E. C. Mos（ASML）, "Method of determining a measurement subset of metrology points on a substrate…," US20160334717A1 (2016).',
    'E. C. Mos ほか（ASML）, "Method and apparatus for inspection and metrology," US20160299438A1 (2016).',
    'A. Wong ほか, "Optimization of sample plan for overlay," US7197722B2 (2007).',
    'N. M. Felix ほか（IBM）, "Overlay improvement roadmap: Strategies for scanner control and product disposition for 5-nm overlay," Proc. SPIE (2011).',
    'S. C. T. Van Der Sanden ほか, "Method of applying a pattern to a substrate…," US9291916B2 (2016).（HOWAの説明）',
    'R. D. Cook, C. J. Nachtsheim, "A comparison of algorithms for constructing exact D-optimal designs," Technometrics 22(3), 315–324 (1980).',
    'O. Dykstra, "The augmentation of experimental data to maximize |X\'X|," Technometrics 13(3), 682–688 (1971).',
    'B. Jones, P. Goos, "I-optimal versus D-optimal split-plot response surface designs," J. Quality Technology 44(2), 85–101 (2012).',
    'J. C. Wyant, K. Creath, "Basic wavefront aberration theory for optical metrology," Applied Optics and Optical Engineering XI (1992).',
  ], MARGIN_X, 1.7, CONTENT_W, 5.1, { fontSize: 12.5, space: 12 });
}

pres.writeFile({ fileName: OUTPUT_PATH }).then((file) => {
  console.log(`書き出し: ${file}（${pageNumber} 枚）`);
});
