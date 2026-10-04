function plot_wafer_frame(ax, layout, opts)
%PLOT_WAFER_FRAME ウェーハ外形・usable領域・shot格子・象限境界・半径領域境界を描く。
%   opts.showPartial（既定 true）: partial shot の枠を薄く描く
%   opts.showScan（既定 true）   : 候補shotの scan 方向を小さな ▲（Up）/ ▼（Down）で描く
%   opts.showRegions（既定 true）: 象限境界と半径領域境界を描く
if nargin < 3
    opts = struct();
end
showPartial = get_option(opts, 'showPartial', true);
showScan = get_option(opts, 'showScan', true);
showRegions = get_option(opts, 'showRegions', true);
hold(ax, 'on');
theta = linspace(0, 2 * pi, 361);
R = layout.waferRadius;
plot(ax, R * cos(theta), R * sin(theta), 'k-', 'LineWidth', 1.0);
plot(ax, layout.usableRadius * cos(theta), layout.usableRadius * sin(theta), ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 0.6);
halfW = layout.shotWidth / 2;
halfH = layout.shotHeight / 2;
shots = layout.shots;
for k = 1:height(shots)
    if ~shots.is_candidate(k) && ~showPartial
        continue
    end
    x = shots.x_mm(k) + [-halfW, halfW, halfW, -halfW, -halfW];
    y = shots.y_mm(k) + [-halfH, -halfH, halfH, halfH, -halfH];
    if shots.is_candidate(k)
        plot(ax, x, y, '-', 'Color', [0.70 0.70 0.70], 'LineWidth', 0.4);
    else
        plot(ax, x, y, '-', 'Color', [0.88 0.88 0.88], 'LineWidth', 0.3);
    end
end
if showRegions
    plot(ax, [-R R], [0 0], '-', 'Color', [0.2 0.2 0.2 0.5], 'LineWidth', 0.6);
    plot(ax, [0 0], [-R R], '-', 'Color', [0.2 0.2 0.2 0.5], 'LineWidth', 0.6);
    for b = layout.radialBoundaries
        r = b * layout.normRadius;
        plot(ax, r * cos(theta), r * sin(theta), '--', 'Color', [0.15 0.45 0.15 0.7], 'LineWidth', 0.6);
    end
end
if showScan
    cand = layout.cand;
    up = cand.scan_sign > 0;
    plot(ax, cand.x_mm(up), cand.y_mm(up) - 9, '^', 'MarkerSize', 2.2, 'Color', [0.55 0.55 0.55], 'MarkerFaceColor', [0.55 0.55 0.55]);
    plot(ax, cand.x_mm(~up), cand.y_mm(~up) - 9, 'v', 'MarkerSize', 2.2, 'Color', [0.55 0.55 0.55], 'MarkerFaceColor', [0.55 0.55 0.55]);
end
axis(ax, 'equal');
lim = R * 1.04;
xlim(ax, [-lim lim]);
ylim(ax, [-lim lim]);
set(ax, 'XTick', [], 'YTick', [], 'Box', 'off', 'XColor', 'none', 'YColor', 'none');
end

function value = get_option(opts, name, default)
value = default;
if isfield(opts, name)
    value = opts.(name);
end
end
