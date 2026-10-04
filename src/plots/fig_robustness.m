function fig_robustness(results, scenario, figDir, dpi)
%FIG_ROBUSTNESS 基準shot数での平均 RMS の、mark計測誤差（上段）と scan方向成分の倍率（下段）に対する変化。
cfg = results.cfg;
T = results.st.aggregated;
N = cfg.figures.reference_n_shots;
methods = scenario_methods(scenario);
conds = cfg.conditions;
nominalLevel = conds(1).mark_noise_level;
nominalScale = conds(1).scan_scale;
noiseConds = conds(arrayfun(@(c) c.scan_scale == nominalScale, conds));
scanConds = conds(arrayfun(@(c) strcmp(c.mark_noise_level, nominalLevel), conds));
noiseX = arrayfun(@(c) cfg.mark_noise.levels.(c.mark_noise_level)(1), noiseConds);
scanX = [scanConds.scan_scale];
[noiseX, i1] = sort(noiseX);
noiseConds = noiseConds(i1);
[scanX, i2] = sort(scanX);
scanConds = scanConds(i2);
nO = numel(cfg.howa.orders);
fig = new_figure(18, 12);
tl = tiledlayout(fig, 2, nO, 'TileSpacing', 'compact', 'Padding', 'compact');
rowsDef = {noiseConds, noiseX, '\sigma_{mark} (X) [nm]'; scanConds, scanX, 'scan-direction component scale'};
for r = 1:2
    cs = rowsDef{r, 1};
    xs = rowsDef{r, 2};
    for k = 1:nO
        order = cfg.howa.orders(k);
        ax = nexttile(tl);
        hold(ax, 'on');
        for m = 1:numel(methods)
            y = NaN(size(xs));
            for c = 1:numel(cs)
                rows = strcmp(T.condition, cs(c).name) & strcmp(T.scenario, scenario) ...
                    & strcmp(T.method, methods{m}) & T.howa_order == order & T.n_shots == N;
                if any(rows)
                    y(c) = T.rms_vec_nm_mean(find(rows, 1));
                end
            end
            if any(isfinite(y))
                plot_method_line(ax, xs, y, methods{m});
            end
        end
        set(ax, 'YScale', 'log');
        style_axes(ax);
        xlabel(ax, rowsDef{r, 3});
        if k == 1
            ylabel(ax, 'Mean residual RMS [nm]');
        end
        title(ax, sprintf('HOWA %d, N = %d', order, N), 'FontWeight', 'normal');
    end
end
lg = legend(nexttile(tl, 1), 'NumColumns', 5, 'Box', 'off');
lg.Layout.Tile = 'south';
title(tl, sprintf('Robustness to mark noise and scan-direction component (%s scenario)', scenario), 'FontSize', 10);
save_figure(fig, fullfile(figDir, sprintf('fig09_robustness_%s_N%d.png', scenario, N)), dpi);
end
