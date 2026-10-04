function draw_map_grid(results, idx, methods, scenario, titleText, filePath, dpi, background)
%DRAW_MAP_GRID 複数手法の sampling map を同じレイアウト（タイル）で並べて保存する。
%   idx(k) = 0 の手法は「設計なし」と表示する。最後のタイルに記号の説明を描く。
designs = results.designs;
layout = results.layout;
mandatory = zeros(1, 0);
if strcmp(scenario, 'mandatory')
    mandatory = results.mandatory;
end
nPanels = numel(methods) + 1;
nCols = 4;
if nPanels > 8
    nCols = 5;
end
nRows = ceil(nPanels / nCols);
fig = new_figure(4.2 * nCols, 4.6 * nRows + 0.8);
tl = tiledlayout(fig, nRows, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, titleText, 'FontSize', 10);
q = results.qualities;
for k = 1:numel(methods)
    ax = nexttile(tl);
    info = method_info(methods{k});
    if idx(k) == 0
        plot_wafer_frame(ax, layout);
        title(ax, {info.label, 'no feasible design'}, 'FontWeight', 'normal');
        continue
    end
    rec = designs(idx(k));
    subtitleText = '';
    if ~isempty(q{idx(k)})
        qq = q{idx(k)};
        subtitleText = sprintf('B_Q=%d  B_R=%d  B_S=%d', qq.balanceQ, qq.balanceR, qq.balanceS);
        if ~qq.fullRank
            subtitleText = [subtitleText '  (rank-deficient)'];
        end
    end
    plot_sampling_map(ax, layout, rec.design, mandatory, methods{k}, {info.label, subtitleText}, background);
end
ax = nexttile(tl);
draw_legend_panel(ax, layout, ~isempty(mandatory));
save_figure(fig, filePath, dpi);
end

function draw_legend_panel(ax, layout, withMandatory)
hold(ax, 'on');
axis(ax, [0 1 0 1]);
set(ax, 'XColor', 'none', 'YColor', 'none');
y = 0.92;
step = 0.12;
patch(ax, [0.05 0.17 0.17 0.05], y + [-0.04 -0.04 0.04 0.04], [0.6 0.6 0.6], 'FaceAlpha', 0.65, 'EdgeColor', [0.4 0.4 0.4]);
text(ax, 0.22, y, 'selected shot (method color)');
y = y - step;
plot(ax, [0.05 0.17 0.17 0.05 0.05], y + [-0.04 -0.04 0.04 0.04 -0.04], '-', 'Color', [0.7 0.7 0.7]);
text(ax, 0.22, y, 'candidate shot / partial (light)');
y = y - step;
plot(ax, 0.11, y, '^', 'MarkerFaceColor', 'k', 'Color', 'k', 'MarkerSize', 4);
plot(ax, 0.15, y, 'v', 'MarkerFaceColor', 'k', 'Color', 'k', 'MarkerSize', 4);
text(ax, 0.22, y, 'scan direction Up / Down');
y = y - step;
plot(ax, [0.05 0.17], [y y], '-', 'Color', [0.2 0.2 0.2]);
text(ax, 0.22, y, 'quadrant boundary');
y = y - step;
plot(ax, [0.05 0.17], [y y], '--', 'Color', [0.15 0.45 0.15]);
text(ax, 0.22, y, sprintf('radial boundary r = %s', strjoin(compose('%.2f', layout.radialBoundaries), ', ')));
y = y - step;
if withMandatory
    plot(ax, 0.11, y, 'p', 'MarkerSize', 7, 'MarkerFaceColor', 'y', 'MarkerEdgeColor', 'k');
    text(ax, 0.22, y, 'mandatory shot F (thick frame)');
    y = y - step;
end
text(ax, 0.05, y, 'B_Q, B_R: max-min count over quadrants / regions;  B_S = |N_{up} - N_{down}|', 'FontSize', 6.5);
end
