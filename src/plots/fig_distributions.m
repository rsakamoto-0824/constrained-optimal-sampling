function fig_distributions(results, scenario, figDir, dpi)
%FIG_DISTRIBUTIONS 基準shot数での 1000 wafer の RMS 分布（箱ひげ図と ECDF）を HOWA 次数ごとに描く。
cfg = results.cfg;
N = cfg.figures.reference_n_shots;
designs = results.designs;
methods = scenario_methods(scenario);
rms = results.ev.rmsVec{1};
nO = numel(cfg.howa.orders);
fig = new_figure(18, 12.5);
tl = tiledlayout(fig, 2, nO, 'TileSpacing', 'compact', 'Padding', 'compact');
handles = gobjects(0);
for k = 1:nO
    order = cfg.howa.orders(k);
    axBox = nexttile(tl, k);
    axCdf = nexttile(tl, nO + k);
    hold(axBox, 'on');
    hold(axCdf, 'on');
    present = {};
    for m = 1:numel(methods)
        r = find(strcmp({designs.scenario}, scenario) & strcmp({designs.method}, methods{m}) ...
            & [designs.order] == order & [designs.nShots] == N, 1);
        if isempty(r) || all(isnan(rms(:, r)))
            continue
        end
        info = method_info(methods{m});
        present{end + 1} = info.label; %#ok<AGROW>
        x = numel(present);
        b = boxchart(axBox, x * ones(size(rms(:, r))), rms(:, r), 'BoxFaceColor', info.color, ...
            'MarkerColor', info.color, 'MarkerSize', 2, 'BoxWidth', 0.6, 'LineWidth', 0.8);
        b.BoxFaceAlpha = 0.25 + 0.35 * info.filled;
        values = sort(rms(:, r));
        h = plot(axCdf, values, (1:numel(values))' / numel(values), 'LineStyle', info.lineStyle, ...
            'Color', info.color, 'LineWidth', 1.1, 'DisplayName', info.label);
        if k == 1
            handles(end + 1) = h; %#ok<AGROW>
        end
    end
    set(axBox, 'XTick', 1:numel(present), 'XTickLabel', present, 'XTickLabelRotation', 35, 'YScale', 'log');
    style_axes(axBox);
    title(axBox, sprintf('HOWA %d, N = %d', order, N), 'FontWeight', 'normal');
    set(axCdf, 'XScale', 'log');
    style_axes(axCdf);
    xlabel(axCdf, 'Residual RMS per wafer [nm]');
    if k == 1
        ylabel(axBox, 'Residual RMS per wafer [nm]');
        ylabel(axCdf, 'ECDF over wafers');
    end
end
lg = legend(handles, 'NumColumns', 5, 'Box', 'off');
lg.Layout.Tile = 'south';
title(tl, sprintf('Monte Carlo distribution of residual RMS (%s scenario, %d wafers)', scenario, results.ws.nWafers), 'FontSize', 10);
save_figure(fig, fullfile(figDir, sprintf('fig05_distribution_%s_N%d.png', scenario, N)), dpi);
end
