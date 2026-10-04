function fig_rms_vs_shots(results, scenario, figDir, dpi)
%FIG_RMS_VS_SHOTS 計測shot数に対する平均 Residual RMS（vector）を HOWA 次数ごとに描く。
%   Random は代表抽選（中央値）の線に加え、全抽選の平均RMSの最良〜P95を灰色の帯で示す。
%   破線の水平線は、計測誤差なし・全評価点を使った場合の残差（モデル不一致の下限）。
cfg = results.cfg;
T = results.st.aggregated;
condition = cfg.conditions(1).name;
methods = scenario_methods(scenario);
columns = {'rms_vec_nm_mean', 'rms_vec_interior_nm_mean'};
labels = {'Mean residual RMS (all valid marks) [nm]', 'Mean residual RMS (candidate-shot marks only) [nm]'};
suffix = {'', '_interior'};
for v = 1:2
    fig = new_figure(18, 7.5);
    tl = tiledlayout(fig, 1, numel(cfg.howa.orders), 'TileSpacing', 'compact', 'Padding', 'compact');
    for k = 1:numel(cfg.howa.orders)
        order = cfg.howa.orders(k);
        ax = nexttile(tl);
        hold(ax, 'on');
        draw_random_band(ax, results, scenario, order, condition, v == 1);
        for m = 1:numel(methods)
            [N, y] = metric_curve(T, condition, scenario, methods{m}, order, columns{v});
            if ~isempty(N)
                plot_method_line(ax, N, y, methods{m});
            end
        end
        if v == 1
            floorValue = mean(results.floorTable.(sprintf('floor_rms_vec_howa%d_nm', order)));
            yline(ax, floorValue, ':', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.0, 'HandleVisibility', 'off');
            text(ax, max(xlim(ax)), floorValue, sprintf('model floor %.2f', floorValue), ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', 'FontSize', 6.5, 'Color', [0.3 0.3 0.3]);
        end
        set(ax, 'YScale', 'log');
        floorValue = NaN;
        if v == 1
            floorValue = mean(results.floorTable.(sprintf('floor_rms_vec_howa%d_nm', order)));
        end
        limit_rms_axis(ax, T, condition, scenario, order, columns{v}, floorValue);
        style_axes(ax);
        xlabel(ax, 'Number of measured shots N');
        if k == 1
            ylabel(ax, labels{v});
        end
        title(ax, sprintf('HOWA %d (p = %d)', order, results.models(k).p), 'FontWeight', 'normal');
    end
    lg = legend(nexttile(tl, 1), 'NumColumns', min(5, numel(methods)), 'Box', 'off');
    lg.Layout.Tile = 'south';
    title(tl, sprintf('Residual RMS vs measured shots (%s scenario, condition %s, %d wafers)', ...
        scenario, condition, results.ws.nWafers), 'FontSize', 10);
    save_figure(fig, fullfile(figDir, sprintf('fig03_rms_vs_shots_%s%s.png', scenario, suffix{v})), dpi);
end
end

function limit_rms_axis(ax, T, condition, scenario, order, column, floorValue)
% N_min 付近の桁違いに大きい値で全体がつぶれないよう、上限を最適化手法の最大値の3倍に切る
% （それより大きい点は図の外。値は csv/aggregated_metrics.csv にある）
keys = {'dopt', 'iopt', 'cdopt', 'ciopt', 'dopt_aug', 'iopt_aug', 'cdopt_aug', 'ciopt_aug'};
values = [];
for k = 1:numel(keys)
    [~, y] = metric_curve(T, condition, scenario, keys{k}, order, column);
    values = [values; y(isfinite(y))]; %#ok<AGROW>
end
if isempty(values)
    return
end
lower = 0.7 * min(values);
if isfinite(floorValue)
    lower = min(lower, 0.85 * floorValue);   % モデル不一致の下限の線が見えるように
end
ylim(ax, [lower, 3 * max(values)]);
end

function draw_random_band(ax, results, scenario, order, condition, enabled)
if ~enabled
    return
end
R = results.ev.randomSummary;
rows = strcmp(R.condition, condition) & strcmp(R.scenario, scenario) & R.howa_order == order;
if ~any(rows)
    return
end
N = R.n_shots(rows);
[N, i] = sort(N);
lo = R.mean_rms_best_draw(rows);
hi = R.mean_rms_p95_over_draws(rows);
fill(ax, [N; flipud(N)], [lo(i); flipud(hi(i))], [0.42 0.42 0.40], 'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
    'DisplayName', 'Random draws (best - P95)');
end
