function samples = select_appendix_samples(designs, ev, cfg)
%SELECT_APPENDIX_SAMPLES Appendix に載せる代表 wafer 3例を、決めたルールで機械的に選ぶ。
%   対象: 主評価条件、appendix.scenario・howa_order・n_shots の設計（全手法）
%   Sample 1（典型例）  : 全手法の平均 RMS が、全 wafer の中央値（typical_quantile）に最も近い wafer
%   Sample 2（改善大）  : 比較手法に対する提案法の改善率 (RMS_比較 - RMS_提案)/RMS_比較 の平均が
%                         improvement_quantile 分位点に最も近い wafer（最大値は外れ値になりやすいので分位点）
%   Sample 3（難しい例）: 全手法の中で最も小さい RMS が最大の wafer（どの手法でも残差が大きい）
%   3例が重複したときは、次に条件に近い wafer を選ぶ。
ac = cfg.appendix;
sel = find(strcmp({designs.scenario}, ac.scenario) & [designs.order] == ac.howa_order ...
    & [designs.nShots] == ac.n_shots & [designs.feasible]);
if isempty(sel)
    error('select_appendix_samples:noDesign', ...
        'Appendix の条件（%s、HOWA %d次、%d shot）の設計がありません。設定 appendix を確認してください。', ...
        ac.scenario, ac.howa_order, ac.n_shots);
end
methods = {designs(sel).method};
rms = ev.rmsVec{1}(:, sel);
proposedCol = find(strcmp(methods, ac.proposed_method), 1);
comparatorCols = find(ismember(methods, ac.comparator_methods));
if isempty(proposedCol) || isempty(comparatorCols)
    error('select_appendix_samples:methods', 'appendix.proposed_method / comparator_methods が設計にありません。');
end

meanAll = mean(rms, 2);
improvement = mean(100 * (rms(:, comparatorCols) - rms(:, proposedCol)) ./ rms(:, comparatorCols), 2);
hardness = min(rms, [], 2);

[~, rank1] = sort(abs(meanAll - percentile_linear(meanAll, 100 * ac.typical_quantile)));
[~, rank2] = sort(abs(improvement - percentile_linear(improvement, 100 * ac.improvement_quantile)));
[~, rank3] = sort(hardness, 'descend');
waferIds = zeros(1, 3);
waferIds(1) = rank1(1);
waferIds(2) = first_unused(rank2, waferIds(1));
waferIds(3) = first_unused(rank3, waferIds(1:2));

names = {'Sample 1 (typical)'; 'Sample 2 (large improvement)'; 'Sample 3 (difficult)'};
rules = {sprintf('mean RMS over methods closest to its %g-quantile', ac.typical_quantile); ...
    sprintf('mean improvement of %s over comparators closest to its %g-quantile', ac.proposed_method, ac.improvement_quantile); ...
    'largest minimum RMS over all methods'};
samples.waferIds = waferIds;
samples.designIds = [designs(sel).id];
samples.methods = methods;
samples.table = table(names, waferIds', rules, meanAll(waferIds), improvement(waferIds), hardness(waferIds), ...
    repmat({ac.scenario}, 3, 1), repmat(ac.howa_order, 3, 1), repmat(ac.n_shots, 3, 1), ...
    'VariableNames', {'sample', 'wafer_id', 'rule', 'mean_rms_over_methods_nm', ...
    'mean_improvement_pct', 'min_rms_over_methods_nm', 'scenario', 'howa_order', 'n_shots'});
end

function id = first_unused(ranking, used)
for k = 1:numel(ranking)
    if ~any(used == ranking(k))
        id = ranking(k);
        return
    end
end
error('select_appendix_samples:notEnough', '代表waferを3枚選べません（wafer数が少なすぎます）。');
end
