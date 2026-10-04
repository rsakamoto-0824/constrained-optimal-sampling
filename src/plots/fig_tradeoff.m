function fig_tradeoff(results, figDir, dpi)
%FIG_TRADEOFF 最適性（D/I-efficiency）と実際の補正残差の関係（強制計測shotなし）。
%   縦軸: 同じ次数・同じshot数の制約なし最適設計に対する平均RMSの比（1より小さければ残差が小さい）
%   上段: D-efficiency と「D-opt に対する RMS 比」、下段: I-efficiency と「I-opt に対する RMS 比」
%   点は計測shot数ごとの設計。制約による最適性の低下が残差にどう効くかを見る。
cfg = results.cfg;
D = results.designMetrics;
T = results.st.aggregated;
condition = cfg.conditions(1).name;
methods = {'random', 'poisson', 'human', 'dopt', 'iopt', 'cdopt', 'ciopt'};
refs = {'dopt', 'iopt'};
effCols = {'d_efficiency', 'i_efficiency'};
effLabels = {'D-efficiency', 'I-efficiency'};
nO = numel(cfg.howa.orders);
fig = new_figure(18, 12);
tl = tiledlayout(fig, 2, nO, 'TileSpacing', 'compact', 'Padding', 'compact');
for r = 1:2
    for k = 1:nO
        order = cfg.howa.orders(k);
        ax = nexttile(tl);
        hold(ax, 'on');
        [Nref, rmsRef] = metric_curve(T, condition, 'base', refs{r}, order, 'rms_vec_nm_mean');
        for m = 1:numel(methods)
            [N, rmsM] = metric_curve(T, condition, 'base', methods{m}, order, 'rms_vec_nm_mean');
            rows = strcmp(D.scenario, 'base') & strcmp(D.method, methods{m}) & D.howa_order == order;
            [Nd, i] = sort(D.n_shots(rows));
            eff = D.(effCols{r})(rows);
            eff = eff(i);
            [~, ia, ib] = intersect(N, Nref);
            [~, ja, jb] = intersect(N(ia), Nd);
            ratio = rmsM(ia(ja)) ./ rmsRef(ib(ja));
            info = method_info(methods{m});
            faceColor = 'w';
            if info.filled
                faceColor = info.color;
            end
            scatter(ax, eff(jb), ratio, 14, 'Marker', info.marker, 'MarkerEdgeColor', info.color, ...
                'MarkerFaceColor', faceColor, 'LineWidth', 0.8, 'DisplayName', info.label);
        end
        yline(ax, 1, '-', 'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off');
        set(ax, 'YScale', 'log');
        ylim(ax, [0.8 10]);     % 10倍を超える点（主に N_min 付近の Random・Human）は図の外
        xlim(ax, [0 1.05]);
        style_axes(ax);
        refInfo = method_info(refs{r});
        xlabel(ax, effLabels{r});
        if k == 1
            ylabel(ax, sprintf('Mean RMS / mean RMS of %s', refInfo.label));
        end
        title(ax, sprintf('HOWA %d (all N)', order), 'FontWeight', 'normal');
    end
end
lg = legend(nexttile(tl, 1), 'NumColumns', 7, 'Box', 'off');
lg.Layout.Tile = 'south';
title(tl, 'Optimality vs actual correction residual (no mandatory shots; points above 10x are clipped)', 'FontSize', 10);
save_figure(fig, fullfile(figDir, 'fig11_tradeoff_efficiency_vs_rms.png'), dpi);
end
