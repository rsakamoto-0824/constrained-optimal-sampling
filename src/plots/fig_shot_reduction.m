function fig_shot_reduction(results, scenario, figDir, dpi)
%FIG_SHOT_REDUCTION 基準手法（Human）と同じ平均RMSを達成するのに必要な最小shot数。
%   横軸: 基準手法の shot 数、縦軸: 各手法の必要shot数（対角線より下なら計測shot数を削減できる）。
cfg = results.cfg;
S = results.st.reduction;
refMethod = 'human';
if strcmp(scenario, 'mandatory')
    refMethod = 'human_f';
end
methods = setdiff(scenario_methods(scenario), {refMethod}, 'stable');
refInfo = method_info(refMethod);
nO = numel(cfg.howa.orders);
fig = new_figure(18, 7.5);
tl = tiledlayout(fig, 1, nO, 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:nO
    order = cfg.howa.orders(k);
    ax = nexttile(tl);
    hold(ax, 'on');
    rowsRef = strcmp(S.scenario, scenario) & S.howa_order == order & strcmp(S.reference_method, refMethod) ...
        & strcmp(S.target_statistic, 'mean');
    Nref = unique(S.reference_n_shots(rowsRef));
    if isempty(Nref)
        continue
    end
    plot(ax, [min(Nref) max(Nref)], [min(Nref) max(Nref)], '-', 'Color', [0.6 0.6 0.6], 'HandleVisibility', 'off');
    for m = 1:numel(methods)
        rows = rowsRef & strcmp(S.method, methods{m});
        [x, i] = sort(S.reference_n_shots(rows));
        y = S.required_n_shots(rows);
        plot_method_line(ax, x, y(i), methods{m});
    end
    style_axes(ax);
    axis(ax, 'square');
    xlabel(ax, sprintf('Shots used by %s', refInfo.label));
    if k == 1
        ylabel(ax, 'Shots needed for the same mean RMS');
    end
    title(ax, sprintf('HOWA %d', order), 'FontWeight', 'normal');
end
lg = legend(nexttile(tl, 1), 'NumColumns', 4, 'Box', 'off');
lg.Layout.Tile = 'south';
title(tl, sprintf('Measured shots needed to match %s (%s scenario, below diagonal = reduction)', ...
    refInfo.label, scenario), 'FontSize', 10);
save_figure(fig, fullfile(figDir, sprintf('fig10_shot_reduction_%s.png', scenario)), dpi);
end
