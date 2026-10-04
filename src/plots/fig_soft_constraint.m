function fig_soft_constraint(results, figDir, dpi)
%FIG_SOFT_CONSTRAINT soft 制約の罰則の重み λ に対する、制約違反（上段）と平均RMS（下段）。
%   λ = 0 は制約なし（D-opt / I-opt）。横軸は λ の値を等間隔に並べた目盛り（0 を含むため）。
if ~isfield(results, 'softStudy') || isempty(results.softStudy)
    return
end
S = results.softStudy;
orders = unique(S.howa_order)';
weights = unique(S.soft_weight)';
Ns = unique(S.n_shots)';
fig = new_figure(18, 12);
tl = tiledlayout(fig, 2, numel(orders), 'TileSpacing', 'compact', 'Padding', 'compact');
colors = struct('D', [0.165 0.471 0.839], 'I', [0.290 0.227 0.655]);
markers = {'o', 's', '^', 'd', 'v'};
cols = {'violation_total', 'rms_vec_mean_nm'};
names = {'Constraint violation [shots]', 'Mean residual RMS [nm]'};
for r = 1:2
    for k = 1:numel(orders)
        ax = nexttile(tl);
        hold(ax, 'on');
        for n = 1:numel(Ns)
            for crit = {'D', 'I'}
                rows = S.howa_order == orders(k) & S.n_shots == Ns(n) & strcmp(S.criterion, crit{1});
                [~, pos] = ismember(S.soft_weight(rows), weights);
                y = S.(cols{r})(rows);
                [pos, i] = sort(pos);
                lineStyle = '-';
                if strcmp(crit{1}, 'I')
                    lineStyle = '--';
                end
                plot(ax, pos, y(i), 'LineStyle', lineStyle, 'Color', colors.(crit{1}), 'LineWidth', 1.0, ...
                    'Marker', markers{1 + mod(n - 1, numel(markers))}, 'MarkerSize', 4, ...
                    'MarkerFaceColor', 'w', 'DisplayName', sprintf('%s-opt, N = %d', crit{1}, Ns(n)));
            end
        end
        set(ax, 'XTick', 1:numel(weights), 'XTickLabel', compose('%g', weights));
        xlim(ax, [0.5, numel(weights) + 0.5]);
        values = S.(cols{r})(S.howa_order == orders(k));
        span = max(values) - min(values);
        ylim(ax, [min(values) - 0.08 * span - (r == 1) * 0.5, max(values) + 0.08 * span + (r == 1) * 0.5]);
        if r == 2
            set(ax, 'YScale', 'log');
            xlabel(ax, 'Soft-constraint weight \lambda (per violating shot)');
        end
        style_axes(ax);
        if k == 1
            ylabel(ax, names{r});
        end
        title(ax, sprintf('HOWA %d', orders(k)), 'FontWeight', 'normal');
    end
end
lg = legend(nexttile(tl, 1), 'NumColumns', 6, 'Box', 'off');
lg.Layout.Tile = 'south';
title(tl, 'Soft constraints: penalty weight vs violation and residual (\lambda = 0: unconstrained)', 'FontSize', 10);
save_figure(fig, fullfile(figDir, 'fig14_soft_constraint.png'), dpi);
end
