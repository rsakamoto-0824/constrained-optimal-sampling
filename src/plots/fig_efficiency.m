function fig_efficiency(results, scenario, figDir, dpi)
%FIG_EFFICIENCY 計測shot数に対する D-efficiency（上段）と I-efficiency（下段）。
%   基準は同じ次数・同じshot数の制約なし D最適 / I最適。Random は全抽選の中央値。
cfg = results.cfg;
D = results.designMetrics;
RS = results.randomDesignSummary;
methods = scenario_methods(scenario);
nO = numel(cfg.howa.orders);
cols = {'d_efficiency', 'i_efficiency'};
rsCols = {'d_eff_median', 'i_eff_median'};
names = {'D-efficiency', 'I-efficiency'};
fig = new_figure(18, 12);
tl = tiledlayout(fig, 2, nO, 'TileSpacing', 'compact', 'Padding', 'compact');
for r = 1:2
    for k = 1:nO
        order = cfg.howa.orders(k);
        ax = nexttile(tl);
        hold(ax, 'on');
        for m = 1:numel(methods)
            if startsWith(methods{m}, 'random')
                rows = strcmp(RS.scenario, scenario) & RS.howa_order == order;
                [N, i] = sort(RS.n_shots(rows));
                y = RS.(rsCols{r})(rows);
                plot_method_line(ax, N, y(i), methods{m});
                continue
            end
            rows = strcmp(D.scenario, scenario) & strcmp(D.method, methods{m}) & D.howa_order == order & D.valid == 1;
            [N, i] = sort(D.n_shots(rows));
            y = D.(cols{r})(rows);
            if ~isempty(N)
                plot_method_line(ax, N, y(i), methods{m});
            end
        end
        ylim(ax, [0 1.1]);
        style_axes(ax);
        if r == 2
            xlabel(ax, 'Number of measured shots N');
        end
        if k == 1
            ylabel(ax, names{r});
        end
        title(ax, sprintf('HOWA %d', order), 'FontWeight', 'normal');
    end
end
lg = legend(nexttile(tl, 1), 'NumColumns', 5, 'Box', 'off');
lg.Layout.Tile = 'south';
title(tl, sprintf('Design efficiency relative to unconstrained D-/I-optimal design (%s scenario)', scenario), 'FontSize', 10);
save_figure(fig, fullfile(figDir, sprintf('fig06_efficiency_%s.png', scenario)), dpi);
end
