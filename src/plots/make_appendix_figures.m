function make_appendix_figures(results)
%MAKE_APPENDIX_FIGURES Appendix 用の代表 wafer 3例の図を作る（results/figures/appendix/）。
%   Sample ごとに
%     A1: 真の wafer 面内傾向（X・Y 成分の色マップ、ベクトル場＋大きさ、shot格子、scan方向）
%     A2: 全手法の sampling map（同じレイアウト、背景にその wafer の真値の大きさ）
%     A3: HOWA 補正後の残差ベクトル場（背景に残差の大きさ、全手法で色とベクトルの尺度を統一、
%         各図に評価点での RMS・P95・Max を表示）
%   強制計測shotありの設計がある場合は A2・A3 を mandatory シナリオでも作る。
if ischar(results) || isstring(results)
    results = load(fullfile(char(results), 'study_results.mat'));
end
cfg = results.cfg;
figDir = fullfile(results.outDir, 'figures', 'appendix');
ensure_folder(figDir);
dpi = cfg.figures.dpi;
order = cfg.appendix.howa_order;
N = cfg.appendix.n_shots;
waferIds = results.appendixSamples.waferIds;
grid = regular_grid(results.layout, 3.0);
for s = 1:numel(waferIds)
    w = waferIds(s);
    truth = truth_on_grid(results, w, grid);
    sampleName = sprintf('Sample %d (wafer %d)', s, w);
    plot_truth(results, truth, grid, sampleName, w, fullfile(figDir, sprintf('A1_sample%d_truth.png', s)), dpi);
    for scenario = {'base', 'mandatory'}
        methods = scenario_methods(scenario{1});
        idx = design_indices(results.designs, scenario{1}, methods, order, N);
        if all(idx == 0)
            continue
        end
        background = struct('x', grid.xv, 'y', grid.yv, 'value', truth.mag, ...
            'clim', [0, percentile_linear(truth.mag(~isnan(truth.mag)), 99)], 'colormap', sequential_map());
        draw_map_grid(results, idx, methods, scenario{1}, ...
            sprintf('%s: sampling maps (%s, HOWA %d, N = %d), background = true |distortion|', ...
            sampleName, scenario{1}, order, N), ...
            fullfile(figDir, sprintf('A2_sample%d_sampling_%s.png', s, scenario{1})), dpi, background);
        plot_residuals(results, w, idx, methods, scenario{1}, order, N, grid, truth, sampleName, ...
            fullfile(figDir, sprintf('A3_sample%d_residual_%s.png', s, scenario{1})), dpi);
    end
end
end

% ======================================================================
function idx = design_indices(designs, scenario, methods, order, N)
idx = zeros(1, numel(methods));
for k = 1:numel(methods)
    hit = find(strcmp({designs.scenario}, scenario) & strcmp({designs.method}, methods{k}) ...
        & [designs.order] == order & [designs.nShots] == N & [designs.feasible], 1);
    if ~isempty(hit)
        idx(k) = hit;
    end
end
end

function grid = regular_grid(layout, spacing)
n = floor(layout.usableRadius / spacing);
grid.xv = (-n:n) * spacing;
grid.yv = (-n:n) * spacing;
[grid.X, grid.Y] = meshgrid(grid.xv, grid.yv);
grid.inside = hypot(grid.X, grid.Y) < layout.usableRadius;
end

function truth = truth_on_grid(results, w, grid)
Z = zernike_basis(grid.X(grid.inside), grid.Y(grid.inside), results.layout.waferRadius, results.ws.terms);
truth.x = NaN(size(grid.X));
truth.y = NaN(size(grid.X));
truth.x(grid.inside) = Z * results.ws.coefX(:, w);
truth.y(grid.inside) = Z * results.ws.coefY(:, w);
truth.mag = hypot(truth.x, truth.y);
end

function plot_truth(results, truth, grid, sampleName, w, filePath, dpi)
layout = results.layout;
fig = new_figure(18, 6.8);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
limit = percentile_linear(abs([truth.x(grid.inside); truth.y(grid.inside)]), 99);
comps = {truth.x, 'X displacement [nm]'; truth.y, 'Y displacement [nm]'};
for c = 1:2
    ax = nexttile(tl);
    h = imagesc(ax, grid.xv, grid.yv, comps{c, 1});
    set(h, 'AlphaData', ~isnan(comps{c, 1}));
    set(ax, 'YDir', 'normal');
    colormap(ax, diverging_map());
    caxis(ax, [-limit limit]);
    plot_wafer_frame(ax, layout, struct('showScan', false, 'showRegions', false));
    cb = colorbar(ax, 'southoutside');
    cb.Label.String = comps{c, 2};
    title(ax, comps{c, 2}, 'FontWeight', 'normal');
end
ax = nexttile(tl);
h = imagesc(ax, grid.xv, grid.yv, truth.mag);
set(h, 'AlphaData', ~isnan(truth.mag));
set(ax, 'YDir', 'normal');
colormap(ax, sequential_map());
caxis(ax, [0, percentile_linear(truth.mag(grid.inside), 99)]);
plot_wafer_frame(ax, layout, struct('showScan', true, 'showRegions', false));
step = 4;   % 12 mm 間隔で矢印を描く
sub = false(size(grid.X));
sub(1:step:end, 1:step:end) = true;
sub = sub & grid.inside;
scale = 12 / max(percentile_linear(truth.mag(grid.inside), 95), eps);
quiver(ax, grid.X(sub), grid.Y(sub), truth.x(sub) * scale, truth.y(sub) * scale, 0, 'k', 'LineWidth', 0.5, 'MaxHeadSize', 0.4);
cb = colorbar(ax, 'southoutside');
cb.Label.String = '|distortion| [nm]';
title(ax, 'Vector field and magnitude (arrows: common scale)', 'FontWeight', 'normal');
title(tl, sprintf('%s: true wafer distortion (Fringe Zernike, %d/%d terms in X/Y)', sampleName, ...
    nnz(results.ws.coefX(:, w)), nnz(results.ws.coefY(:, w))), 'FontSize', 10);
save_figure(fig, filePath, dpi);
end

function plot_residuals(results, w, idx, methods, scenario, order, N, grid, truth, sampleName, filePath, dpi)
layout = results.layout;
cfg = results.cfg;
model = results.models([results.models.order] == order);
K = layout.nMarksPerShot;
sigma = cfg.mark_noise.levels.(cfg.conditions(1).mark_noise_level);
scale = cfg.conditions(1).scan_scale;
ws = results.ws;
Fgrid = howa_design_matrix(grid.X(grid.inside) / layout.normRadius, grid.Y(grid.inside) / layout.normRadius, order);
ep = layout.evalPoints;
fields = cell(1, numel(methods));
for k = 1:numel(methods)
    if idx(k) == 0
        continue
    end
    design = results.designs(idx(k)).design;
    candRows = reshape((design - 1) * K + (1:K)', [], 1);
    evalRows = reshape(layout.candMarkRows(design, :)', [], 1);
    X = model.Fcand(candRows, :);
    measX = ws.truthX(evalRows, w) + scale * ws.scanX(evalRows, w) + sigma(1) * ws.noiseX(evalRows, w);
    measY = ws.truthY(evalRows, w) + scale * ws.scanY(evalRows, w) + sigma(2) * ws.noiseY(evalRows, w);
    coef = X \ [measX, measY];
    resX = NaN(size(grid.X));
    resY = NaN(size(grid.X));
    resX(grid.inside) = truth.x(grid.inside) - Fgrid * coef(:, 1);
    resY(grid.inside) = truth.y(grid.inside) - Fgrid * coef(:, 2);
    predEval = model.Feval * coef;
    fields{k} = struct('mag', hypot(resX, resY), 'ex', ws.truthX(:, w) - predEval(:, 1), ...
        'ey', ws.truthY(:, w) - predEval(:, 2), 'metrics', results.ev.full{1}(w, :, idx(k)));
end
present = find(idx > 0);
p99 = zeros(1, numel(present));
p95 = zeros(1, numel(present));
for j = 1:numel(present)
    f = fields{present(j)};
    p99(j) = percentile_linear(f.mag(grid.inside), 99);
    p95(j) = percentile_linear(hypot(f.ex, f.ey), 95);
end
% 全手法で共通の尺度。最大値に合わせると残差の大きい1手法（Random など）で他が見えなくなるため、
% 手法間の中央値で決め、それを超える色は飽和、矢印は ARROW_CLIP_MM で切る
ARROW_REF_MM = 10;
ARROW_CLIP_MM = 20;
clim = [0, percentile_linear(p99(:), 50)];
vecScale = ARROW_REF_MM / max(percentile_linear(p95(:), 50), eps);
nPanels = numel(methods);
nCols = 4;
if nPanels > 8
    nCols = 5;
end
nRows = ceil(nPanels / nCols);
fig = new_figure(4.2 * nCols, 4.7 * nRows + 1.6);
tl = tiledlayout(fig, nRows, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');
mandatory = zeros(1, 0);
if strcmp(scenario, 'mandatory')
    mandatory = results.mandatory;
end
for k = 1:numel(methods)
    ax = nexttile(tl);
    info = method_info(methods{k});
    if idx(k) == 0
        plot_wafer_frame(ax, layout);
        title(ax, {info.label, 'no feasible design'}, 'FontWeight', 'normal');
        continue
    end
    f = fields{k};
    h = imagesc(ax, grid.xv, grid.yv, f.mag);
    set(h, 'AlphaData', ~isnan(f.mag));
    set(ax, 'YDir', 'normal');
    colormap(ax, sequential_map());
    caxis(ax, clim);
    plot_wafer_frame(ax, layout, struct('showScan', false));
    design = results.designs(idx(k)).design;
    plot(ax, layout.cand.x_mm(design), layout.cand.y_mm(design), 's', 'MarkerSize', 3.5, ...
        'MarkerEdgeColor', info.color, 'MarkerFaceColor', 'w', 'LineWidth', 0.8);
    if ~isempty(mandatory)
        plot(ax, layout.cand.x_mm(mandatory), layout.cand.y_mm(mandatory), 'p', 'MarkerSize', 5, ...
            'MarkerFaceColor', 'y', 'MarkerEdgeColor', 'k');
    end
    lengthMm = hypot(f.ex, f.ey) * vecScale;
    shrink = min(1, ARROW_CLIP_MM ./ max(lengthMm, eps));
    quiver(ax, ep.x_mm, ep.y_mm, f.ex * vecScale .* shrink, f.ey * vecScale .* shrink, 0, 'k', ...
        'LineWidth', 0.4, 'MaxHeadSize', 0.5);
    m = f.metrics;
    title(ax, {info.label, sprintf('RMS %.3f  P95 %.3f  Max %.3f nm', m(3), m(4), m(6))}, 'FontWeight', 'normal');
end
cb = colorbar(nexttile(tl, 1), 'Orientation', 'horizontal');
cb.Layout.Tile = 'south';
cb.Label.String = sprintf(['|residual| [nm] (common to all panels, saturates above %.2f nm); ', ...
    'arrows: %.2f nm = %d mm, clipped at %d mm'], clim(2), ARROW_REF_MM / vecScale, ARROW_REF_MM, ARROW_CLIP_MM);
title(tl, sprintf('%s: residual after HOWA %d correction (%s, N = %d, condition %s)', sampleName, order, ...
    scenario, N, cfg.conditions(1).name), 'FontSize', 10);
save_figure(fig, filePath, dpi);
end

function map = sequential_map()
% 1色相の明→暗（白に近い青 → 濃い青）
light = [0.97 0.98 1.00];
dark = [0.03 0.19 0.42];
t = linspace(0, 1, 256)';
map = light + t .* (dark - light);
end

function map = diverging_map()
% 青 - 灰色（中央）- 赤 の2色相＋中立の灰色
blue = [0.13 0.40 0.67];
mid = [0.95 0.95 0.95];
red = [0.70 0.09 0.17];
t = linspace(0, 1, 128)';
map = [blue + t .* (mid - blue); mid + t .* (red - mid)];
end
