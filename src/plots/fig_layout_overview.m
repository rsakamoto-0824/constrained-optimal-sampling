function fig_layout_overview(results, figDir, dpi)
%FIG_LAYOUT_OVERVIEW shot配置・partial shot・評価点・象限・半径領域・scan方向・強制計測shotの概要図。
layout = results.layout;
fig = new_figure(16, 8.2);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

% 左: 候補shotと区分
ax = nexttile(tl);
plot_wafer_frame(ax, layout, struct('showScan', true));
cand = layout.cand;
halfW = layout.shotWidth / 2;
halfH = layout.shotHeight / 2;
regionColors = [0.85 0.92 1.00; 0.92 0.97 0.88; 1.00 0.93 0.85];
for k = 1:height(cand)
    x = cand.x_mm(k) + [-halfW, halfW, halfW, -halfW];
    y = cand.y_mm(k) + [-halfH, -halfH, halfH, halfH];
    patch(ax, x, y, regionColors(cand.radial_region(k), :), 'EdgeColor', [0.6 0.6 0.6], 'LineWidth', 0.4);
end
plot_wafer_frame(ax, layout, struct('showScan', true, 'showPartial', false));
for c = results.mandatory(:)'
    plot(ax, cand.x_mm(c), cand.y_mm(c) + 5, 'p', 'MarkerSize', 7, 'MarkerFaceColor', 'y', 'MarkerEdgeColor', 'k');
end
for q = 1:4
    angle = (q - 0.5) * pi / 2;
    text(ax, 1.0 * layout.waferRadius * cos(angle), 1.0 * layout.waferRadius * sin(angle), sprintf('Q%d', q), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', [0.2 0.2 0.2]);
end
counts = accumarray(cand.radial_region, 1)';
title(ax, sprintf('Candidates %d (Inner %d / Middle %d / Outer %d), F = %d shots (star)', ...
    layout.nCand, counts(1), counts(2), counts(3), numel(results.mandatory)), 'FontWeight', 'normal');

% 右: 評価点（全有効mark）と partial shot
ax = nexttile(tl);
plot_wafer_frame(ax, layout, struct('showScan', false));
ep = layout.evalPoints;
plot(ax, ep.x_mm(~ep.is_candidate_mark), ep.y_mm(~ep.is_candidate_mark), '.', 'Color', [0.92 0.41 0.20], 'MarkerSize', 6);
plot(ax, ep.x_mm(ep.is_candidate_mark), ep.y_mm(ep.is_candidate_mark), '.', 'Color', [0.17 0.47 0.84], 'MarkerSize', 6);
title(ax, sprintf('Evaluation points: %d valid marks (blue: candidate shots, orange: partial shots)', height(ep)), ...
    'FontWeight', 'normal');
save_figure(fig, fullfile(figDir, 'fig01_layout_overview.png'), dpi);
end
