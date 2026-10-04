function fig_optimization_time(results, figDir, dpi)
%FIG_OPTIMIZATION_TIME 設計の計算時間（multi-start 全体、秒）の計測shot数依存性。
cfg = results.cfg;
D = results.designMetrics;
methods = {'dopt', 'iopt', 'cdopt', 'ciopt', 'cdopt_aug', 'ciopt_aug', 'poisson'};
scenarios = {'base', 'base', 'base', 'base', 'mandatory', 'mandatory', 'base'};
nO = numel(cfg.howa.orders);
fig = new_figure(18, 7.5);
tl = tiledlayout(fig, 1, nO, 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:nO
    order = cfg.howa.orders(k);
    ax = nexttile(tl);
    hold(ax, 'on');
    for m = 1:numel(methods)
        rows = strcmp(D.scenario, scenarios{m}) & strcmp(D.method, methods{m}) & D.howa_order == order;
        [N, i] = sort(D.n_shots(rows));
        t = D.optimization_time_s(rows);
        plot_method_line(ax, N, t(i), methods{m});
    end
    set(ax, 'YScale', 'log');
    style_axes(ax);
    xlabel(ax, 'Number of measured shots N');
    if k == 1
        ylabel(ax, 'Design computation time [s]');
    end
    title(ax, sprintf('HOWA %d', order), 'FontWeight', 'normal');
end
lg = legend(nexttile(tl, 1), 'NumColumns', 7, 'Box', 'off');
lg.Layout.Tile = 'south';
title(tl, sprintf('Optimization time (%d random starts + 1 cross start, single thread MATLAB)', cfg.optimizer.n_starts), 'FontSize', 10);
save_figure(fig, fullfile(figDir, 'fig13_optimization_time.png'), dpi);
end
