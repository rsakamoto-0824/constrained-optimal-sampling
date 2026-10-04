function fig_paired_differences(results, scenario, figDir, dpi)
%FIG_PAIRED_DIFFERENCES 提案法と比較法の waferごとの改善率
%   (RMS_比較 - RMS_提案) / RMS_比較 × 100 の平均と bootstrap 95% 信頼区間を計測shot数ごとに描く。
%   0より上なら提案法の方が残差が小さい。ΔRMS [nm] の値は csv/paired_comparison.csv にある。
%   （N_min 付近では比較法の残差が桁違いに大きく、nm の差では全体が読めないため改善率で示す）
cfg = results.cfg;
P = results.st.paired;
condition = cfg.conditions(1).name;
proposed = cfg.statistics.proposed_methods.(scenario);
nO = numel(cfg.howa.orders);
fig = new_figure(18, 12.5);
tl = tiledlayout(fig, numel(proposed), nO, 'TileSpacing', 'compact', 'Padding', 'compact');
handles = gobjects(0);
names = {};
for p = 1:numel(proposed)
    comparators = setdiff(scenario_methods(scenario), proposed(p), 'stable');
    proposedInfo = method_info(proposed{p});
    for k = 1:nO
        order = cfg.howa.orders(k);
        ax = nexttile(tl);
        hold(ax, 'on');
        yline(ax, 0, '-', 'Color', [0.3 0.3 0.3], 'HandleVisibility', 'off');
        for c = 1:numel(comparators)
            rows = strcmp(P.condition, condition) & strcmp(P.scenario, scenario) & P.howa_order == order ...
                & strcmp(P.proposed_method, proposed{p}) & strcmp(P.comparator_method, comparators{c});
            if ~any(rows)
                continue
            end
            [N, i] = sort(P.n_shots(rows));
            d = P.mean_improvement_pct(rows);
            lo = P.boot_improvement_ci_low_pct(rows);
            hi = P.boot_improvement_ci_high_pct(rows);
            d = d(i);
            lo = lo(i);
            hi = hi(i);
            info = method_info(comparators{c});
            h = plot_method_line(ax, N, d, comparators{c}, 3);
            h.DisplayName = ['vs ' info.label];
            if k == 1 && ~any(strcmp(names, h.DisplayName))
                handles(end + 1) = h; %#ok<AGROW>
                names{end + 1} = h.DisplayName; %#ok<AGROW>
            end
            errorbar(ax, N, d, d - lo, hi - d, 'LineStyle', 'none', 'Color', info.color, ...
                'CapSize', 2, 'HandleVisibility', 'off');
        end
        ylim(ax, [-60 100]);
        style_axes(ax);
        if p == numel(proposed)
            xlabel(ax, 'Number of measured shots N');
        end
        if k == 1
            ylabel(ax, {proposedInfo.label, 'Mean improvement per wafer [%]'});
        end
        title(ax, sprintf('HOWA %d', order), 'FontWeight', 'normal');
    end
end
lg = legend(handles, 'NumColumns', 4, 'Box', 'off');
lg.Layout.Tile = 'south';
title(tl, sprintf(['Paired comparison over %d wafers: improvement of the proposed method ', ...
    '(mean, bootstrap 95%% CI; >0 = proposed better; axis clipped at -60%%)'], results.ws.nWafers), 'FontSize', 9);
save_figure(fig, fullfile(figDir, sprintf('fig08_paired_improvement_%s.png', scenario)), dpi);
end
