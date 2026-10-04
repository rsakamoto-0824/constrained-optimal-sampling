function layout = build_shot_layout(cfg)
%BUILD_SHOT_LAYOUT ウェーハ上のshot配置・候補shot・mark位置・評価点をまとめて作る。
%   layout.shots      : ウェーハに少しでも掛かる全shotの表（partial shotを含む）
%   layout.cand       : 候補shot（partial shotを除いたshot）の表。行番号が「候補番号」
%   layout.evalPoints : 評価点（全shotのmarkのうち usable 領域内にあるもの）の表
%   layout.candMarkRows : 候補shot k の mark j が evalPoints の何行目か（Ncand行 K列）
%   layout.denseGrid  : usable 領域を覆う格子点（I最適の評価点・図の背景に使う）

waferRadius = cfg.wafer.diameter_mm / 2;
usableRadius = waferRadius - cfg.wafer.edge_exclusion_mm;
normRadius = cfg.howa.normalization_radius_mm;
markOffsets = cfg.marks.offsets_mm;
nMarks = size(markOffsets, 1);
px = cfg.shot.pitch_x_mm;
py = cfg.shot.pitch_y_mm;
x0 = cfg.shot.grid_origin_mm(1);
y0 = cfg.shot.grid_origin_mm(2);
halfW = cfg.shot.width_mm / 2;
halfH = cfg.shot.height_mm / 2;

% --- ウェーハに掛かる可能性のある格子をすべて作り、円と交わるshotだけを残す
colRange = floor((-waferRadius - halfW - x0) / px) - 1 : ceil((waferRadius + halfW - x0) / px) + 1;
rowRange = floor((-waferRadius - halfH - y0) / py) - 1 : ceil((waferRadius + halfH - y0) / py) + 1;
[colGrid, rowGrid] = meshgrid(colRange, rowRange);
colGrid = colGrid(:);
rowGrid = rowGrid(:);
xc = x0 + colGrid * px;
yc = y0 + rowGrid * py;
% 矩形のうちウェーハ中心に最も近い点がウェーハ内なら、そのshotはウェーハに掛かる
nearestX = min(max(0, xc - halfW), xc + halfW);
nearestY = min(max(0, yc - halfH), yc + halfH);
onWafer = hypot(nearestX, nearestY) < waferRadius;
colGrid = colGrid(onWafer);
rowGrid = rowGrid(onWafer);
xc = xc(onWafer);
yc = yc(onWafer);

% shot番号: 上の行から順に、同じ行では左から（ID = 1, 2, ...）
[~, order] = sortrows([-yc, xc]);
colGrid = colGrid(order);
rowGrid = rowGrid(order);
xc = xc(order);
yc = yc(order);
nShots = numel(xc);
shotId = (1:nShots)';

isCandidate = is_full_shot(xc, yc, cfg.shot.width_mm, cfg.shot.height_mm, markOffsets, usableRadius);
u = xc / normRadius;
v = yc / normRadius;
rNorm = hypot(u, v);
quadrant = assign_quadrant(xc, yc);
radialRegion = assign_radial_region(rNorm, cfg.constraints.radial.boundaries_norm);
scanSign = assign_scan_direction(colGrid, rowGrid, shotId, cfg.scan);
scanLabel = repmat("Up", nShots, 1);
scanLabel(scanSign < 0) = "Down";

% --- 評価点: 全shotのmarkのうち usable 領域内のもの
markX = xc + markOffsets(:, 1)';     % nShots x K
markY = yc + markOffsets(:, 2)';
markValid = hypot(markX, markY) < usableRadius;
nValidMarks = sum(markValid, 2);
[shotIdx, markIdx] = find(markValid);
[~, order] = sortrows([shotIdx, markIdx]);
shotIdx = shotIdx(order);
markIdx = markIdx(order);
linearIdx = sub2ind(size(markX), shotIdx, markIdx);
evalX = markX(linearIdx);
evalY = markY(linearIdx);

candShotIds = shotId(isCandidate);
nCand = numel(candShotIds);
candIndexOfShot = zeros(nShots, 1);
candIndexOfShot(isCandidate) = 1:nCand;

shots = table(shotId, colGrid, rowGrid, xc, yc, u, v, rNorm, quadrant, radialRegion, ...
    scanSign, scanLabel, isCandidate, candIndexOfShot, nValidMarks, ...
    'VariableNames', {'shot_id', 'col', 'row', 'x_mm', 'y_mm', 'u', 'v', 'r_norm', ...
    'quadrant', 'radial_region', 'scan_sign', 'scan_direction', 'is_candidate', ...
    'cand_index', 'n_valid_marks'});

evalPoints = table(shotId(shotIdx), markIdx, evalX, evalY, evalX / normRadius, evalY / normRadius, ...
    isCandidate(shotIdx), candIndexOfShot(shotIdx), scanSign(shotIdx), ...
    'VariableNames', {'shot_id', 'mark_index', 'x_mm', 'y_mm', 'u', 'v', ...
    'is_candidate_mark', 'cand_index', 'scan_sign'});

% 候補shot k の mark j の評価点行番号
candMarkRows = zeros(nCand, nMarks);
for row = 1:height(evalPoints)
    k = evalPoints.cand_index(row);
    if k > 0
        candMarkRows(k, evalPoints.mark_index(row)) = row;
    end
end
if any(candMarkRows(:) == 0)
    error('build_shot_layout:missingCandidateMark', '候補shotのmarkが評価点に含まれていません（判定条件を確認してください）。');
end

layout.waferRadius = waferRadius;
layout.usableRadius = usableRadius;
layout.normRadius = normRadius;
layout.shotWidth = cfg.shot.width_mm;
layout.shotHeight = cfg.shot.height_mm;
layout.markOffsets = markOffsets;
layout.nMarksPerShot = nMarks;
layout.shots = shots;
layout.cand = shots(isCandidate, :);
layout.nCand = nCand;
layout.evalPoints = evalPoints;
layout.candMarkRows = candMarkRows;
layout.radialNames = cfg.constraints.radial.names;
layout.radialBoundaries = cfg.constraints.radial.boundaries_norm;
layout.denseGrid = build_dense_grid(usableRadius, cfg.optimizer.i_eval_grid_spacing_mm, normRadius);
end

function grid = build_dense_grid(usableRadius, spacing, normRadius)
% ウェーハ中心を通る正方格子のうち usable 領域内の点
n = floor(usableRadius / spacing);
values = (-n:n) * spacing;
[gx, gy] = meshgrid(values, values);
inside = hypot(gx, gy) < usableRadius;
grid.x_mm = gx(inside);
grid.y_mm = gy(inside);
grid.u = grid.x_mm / normRadius;
grid.v = grid.y_mm / normRadius;
grid.spacing_mm = spacing;
end
