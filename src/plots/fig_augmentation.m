function fig_augmentation(results, figDir, dpi)
%FIG_AUGMENTATION 強制計測shotがある場合の拡張実験計画（augmentation）の効果。
%   上段: 平均RMS（拡張計画・素朴な方法・制約なし拡張計画・Random+F と、強制shotなしの制約付き設計）
%   下段: 素朴な方法に対する拡張計画の平均RMSの比（1より小さければ拡張計画が良い）
cfg = results.cfg;
T = results.st.aggregated;
condition = cfg.conditions(1).name;
methods = {'random_f', 'human_f', 'dopt_aug', 'iopt_aug', 'cdopt_naive', 'ciopt_naive', 'cdopt_aug', 'ciopt_aug'};
nO = numel(cfg.howa.orders);
fig = new_figure(18, 12);
tl = tiledlayout(fig, 2, nO, 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:nO
    order = cfg.howa.orders(k);
    ax = nexttile(tl, k);
    hold(ax, 'on');
    for m = 1:numel(methods)
        [N, y] = metric_curve(T, condition, 'mandatory', methods{m}, order, 'rms_vec_nm_mean');
        plot_method_line(ax, N, y, methods{m});
    end
    for base = {'cdopt', 'ciopt'}
        [N, y] = metric_curve(T, condition, 'base', base{1}, order, 'rms_vec_nm_mean');
        info = method_info(base{1});
        plot(ax, N, y, '-', 'Color', [info.color 0.35], 'LineWidth', 2.2, ...
            'DisplayName', [info.label ' (no F)']);
    end
    set(ax, 'YScale', 'log');
    style_axes(ax);
    if k == 1
        ylabel(ax, 'Mean residual RMS [nm]');
    end
    title(ax, sprintf('HOWA %d', order), 'FontWeight', 'normal');
    [Nm, ~] = metric_curve(T, condition, 'mandatory', 'random_f', order, 'rms_vec_nm_mean');
    xRange = [min(Nm) - 0.5, max(Nm) + 0.5];
    xlim(ax, xRange);
    yl = ylim(ax);
    [~, yAug] = metric_curve(T, condition, 'mandatory', 'cdopt_aug', order, 'rms_vec_nm_mean');
    ylim(ax, [yl(1), min(yl(2), 5 * max(yAug(isfinite(yAug))))]);

    ax = nexttile(tl, nO + k);
    hold(ax, 'on');
    pairs = {'cdopt_aug', 'cdopt_naive'; 'ciopt_aug', 'ciopt_naive'};
    for p = 1:2
        [Na, ya] = metric_curve(T, condition, 'mandatory', pairs{p, 1}, order, 'rms_vec_nm_mean');
        [Nn, yn] = metric_curve(T, condition, 'mandatory', pairs{p, 2}, order, 'rms_vec_nm_mean');
        [Nc, ia, ib] = intersect(Na, Nn);
        h = plot_method_line(ax, Nc, ya(ia) ./ yn(ib), pairs{p, 1});
        h.DisplayName = sprintf('%s / naive', h.DisplayName);
    end
    yline(ax, 1, '-', 'Color', [0.4 0.4 0.4], 'HandleVisibility', 'off');
    set(ax, 'YScale', 'log');
    xlim(ax, xRange);
    style_axes(ax);
    xlabel(ax, 'Number of measured shots N (incl. mandatory)');
    if k == 1
        ylabel(ax, 'RMS ratio: augmentation / naive');
    end
    legend(ax, 'Location', 'best', 'Box', 'off', 'FontSize', 6);
end
lg = legend(nexttile(tl, 1), 'NumColumns', 5, 'Box', 'off');
lg.Layout.Tile = 'north';
title(tl, sprintf('Mandatory shots (F = %d): optimal augmentation vs naive optimization', numel(results.mandatory)), 'FontSize', 10);
save_figure(fig, fullfile(figDir, 'fig12_augmentation.png'), dpi);
end
