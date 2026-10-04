function fig_coverage(results, scenario, figDir, dpi)
%FIG_COVERAGE coverage 指標（B_Q, B_R, B_S）と制約違反を計測shot数ごとに描く。
%   上段: 各指標（HOWA次数を平均せず、基準次数 appendix.howa_order の設計で描く）
%   下段: 制約違反（象限・半径・scan のはみ出しshot数の合計）。Random は違反した抽選の割合（右の数値）
cfg = results.cfg;
D = results.designMetrics;
RS = results.randomDesignSummary;
methods = scenario_methods(scenario);
order = cfg.appendix.howa_order;
cols = {'balance_quadrant', 'balance_radial', 'balance_scan'};
names = {'B_Q = max-min over quadrants', 'B_R = max-min over radial regions', 'B_S = |N_{up} - N_{down}|'};
rsCols = {'balance_quadrant_mean', 'balance_radial_mean', 'balance_scan_mean'};
fig = new_figure(18, 12);
tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
for c = 1:3
    ax = nexttile(tl);
    hold(ax, 'on');
    for m = 1:numel(methods)
        if startsWith(methods{m}, 'random')
            rows = strcmp(RS.scenario, scenario) & RS.howa_order == order;
            [N, i] = sort(RS.n_shots(rows));
            y = RS.(rsCols{c})(rows);
            plot_method_line(ax, N, y(i), methods{m});
        else
            [N, y] = design_curve(D, scenario, methods{m}, order, cols{c});
            plot_method_line(ax, N, y, methods{m});
        end
    end
    style_axes(ax);
    xlabel(ax, 'Number of measured shots N');
    title(ax, names{c}, 'FontWeight', 'normal');
end
violationNames = {'violation_quadrant', 'violation_radial', 'violation_scan'};
rateNames = {'violation_rate_quadrant', 'violation_rate_radial', 'violation_rate_scan'};
groupTitles = {'Quadrant violation [shots]', 'Radial violation [shots]', 'Scan violation [shots]'};
for c = 1:3
    ax = nexttile(tl);
    hold(ax, 'on');
    for m = 1:numel(methods)
        if startsWith(methods{m}, 'random')
            continue
        end
        [N, y] = design_curve(D, scenario, methods{m}, order, violationNames{c});
        plot_method_line(ax, N, y, methods{m});
    end
    rows = strcmp(RS.scenario, scenario) & RS.howa_order == order;
    rate = mean(RS.(rateNames{c})(rows));
    style_axes(ax);
    xlabel(ax, 'Number of measured shots N');
    title(ax, {groupTitles{c}, sprintf('(Random: %.0f%% of draws violate)', 100 * rate)}, 'FontWeight', 'normal');
end
lg = legend(nexttile(tl, 1), 'NumColumns', 5, 'Box', 'off');
lg.Layout.Tile = 'south';
title(tl, sprintf('Coverage and constraint violation (%s scenario, HOWA %d designs)', scenario, order), 'FontSize', 10);
save_figure(fig, fullfile(figDir, sprintf('fig07_coverage_%s.png', scenario)), dpi);
end

function [N, y] = design_curve(D, scenario, method, order, column)
rows = strcmp(D.scenario, scenario) & strcmp(D.method, method) & D.howa_order == order & D.feasible == 1;
[N, i] = sort(D.n_shots(rows));
y = D.(column)(rows);
y = y(i);
end
