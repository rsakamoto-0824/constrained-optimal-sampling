function fig_tail_vs_shots(results, scenario, figDir, dpi)
%FIG_TAIL_VS_SHOTS tail 指標の shot 数依存性。
%   上段: waferごとの RMS の P95（1000 wafer 中の悪い側 5%）
%   下段: wafer内の最大残差（Max residual magnitude）の平均
cfg = results.cfg;
T = results.st.aggregated;
condition = cfg.conditions(1).name;
methods = scenario_methods(scenario);
rowsDef = {'rms_vec_nm_p95', 'P95 over wafers of RMS [nm]'; 'max_mag_nm_mean', 'Mean of max |residual| [nm]'};
fig = new_figure(18, 12);
nO = numel(cfg.howa.orders);
tl = tiledlayout(fig, 2, nO, 'TileSpacing', 'compact', 'Padding', 'compact');
for r = 1:2
    for k = 1:nO
        order = cfg.howa.orders(k);
        ax = nexttile(tl);
        hold(ax, 'on');
        for m = 1:numel(methods)
            [N, y] = metric_curve(T, condition, scenario, methods{m}, order, rowsDef{r, 1});
            if ~isempty(N)
                plot_method_line(ax, N, y, methods{m});
            end
        end
        set(ax, 'YScale', 'log');
        style_axes(ax);
        if r == 2
            xlabel(ax, 'Number of measured shots N');
        end
        if k == 1
            ylabel(ax, rowsDef{r, 2});
        end
        title(ax, sprintf('HOWA %d', order), 'FontWeight', 'normal');
    end
end
lg = legend(nexttile(tl, 1), 'NumColumns', 5, 'Box', 'off');
lg.Layout.Tile = 'south';
title(tl, sprintf('Tail residuals vs measured shots (%s scenario)', scenario), 'FontSize', 10);
save_figure(fig, fullfile(figDir, sprintf('fig04_tail_vs_shots_%s.png', scenario)), dpi);
end
