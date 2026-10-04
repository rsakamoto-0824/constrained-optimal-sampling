function [designMetrics, randomDesignSummary, qualities] = compute_design_metrics(designs, randomSets, models, layout, cfg, mandatory)
%COMPUTE_DESIGN_METRICS 各設計の D/I 最適性・効率・coverage・制約違反を表にまとめる。
%   D-efficiency = exp((log det M - log det M_ref) / p)、M_ref は同じ次数・同じshot数の制約なしD最適
%   I-efficiency = trace(M_ref^-1) / trace(M^-1)、M_ref は同じ次数・同じshot数の制約なしI最適
%   （どちらも1が基準。最適化は発見的なので、制約付きなどで1をわずかに超えることもある）
%   feasible: 制約を満たす設計が作れたか、valid: feasible かつ full rank（残差を評価できる設計）

K = layout.nMarksPerShot;
rankTol = cfg.optimizer.rank_tolerance;
orders = [models.order];
nRec = numel(designs);
qualities = cell(nRec, 1);
for r = 1:nRec
    rec = designs(r);
    model = models(orders == rec.order);
    groups = build_constraint_groups(rec.nShots, layout, cfg.constraints);
    mand = zeros(1, 0);
    if strcmp(rec.scenario, 'mandatory')
        mand = mandatory;
    end
    if rec.feasible
        qualities{r} = design_quality(rec.design, model, groups, mand, rankTol, K);
    end
end

% 効率の基準（制約なしD最適・I最適）
refD = containers.Map();
refI = containers.Map();
for r = 1:nRec
    rec = designs(r);
    if ~strcmp(rec.scenario, 'base') || isempty(qualities{r})
        continue
    end
    key = sprintf('%d|%d', rec.order, rec.nShots);
    if strcmp(rec.method, 'dopt')
        refD(key) = qualities{r}.logdet;
    elseif strcmp(rec.method, 'iopt')
        refI(key) = qualities{r}.icrit;
    end
end

nQ = 4;
nR = numel(layout.radialNames);
rows = cell(nRec, 0);
for r = 1:nRec
    rec = designs(r);
    q = qualities{r};
    info = method_info(rec.method);
    key = sprintf('%d|%d', rec.order, rec.nShots);
    p = models(orders == rec.order).p;
    [dEff, iEff] = efficiencies(q, key, refD, refI, p);
    if isempty(q)
        countsQ = NaN(1, nQ); countsR = NaN(1, nR); countsS = NaN(1, 2);
        vals = NaN(1, 11);
    else
        countsQ = q.counts{1}'; countsR = q.counts{2}'; countsS = q.counts{3}';
        vals = [double(q.fullRank), q.svRatio, q.logdet, dEff, q.icrit, iEff, ...
            q.balanceQ, q.balanceR, q.balanceS, q.violationQuadrant + q.violationRadial + q.violationScan, ...
            q.violationMandatory];
    end
    isValid = rec.feasible && ~isempty(q) && q.fullRank;
    rowData = [{rec.id, rec.scenario, rec.method, info.label, info.family, rec.order, rec.nShots, ...
        rec.drawIndex, double(rec.feasible), double(isValid)}, num2cell(vals(1:9)), ...
        num2cell(violation_parts(q)), {vals(11)}, num2cell(countsQ), num2cell(countsR), num2cell(countsS), ...
        {rec.timeSeconds, rec.fractionStartsAtBest, rec.nStartsFeasible, rec.poissonMinDistance}];
    rows(r, 1:numel(rowData)) = rowData;
end
names = [{'design_id', 'scenario', 'method', 'method_label', 'family', 'howa_order', 'n_shots', ...
    'random_draw_index', 'feasible', 'valid', 'full_rank', 'sv_ratio', 'logdet', 'd_efficiency', ...
    'i_criterion', 'i_efficiency', 'balance_quadrant', 'balance_radial', 'balance_scan', ...
    'violation_quadrant', 'violation_radial', 'violation_scan', 'violation_mandatory'}, ...
    arrayfun(@(k) sprintf('n_q%d', k), 1:nQ, 'UniformOutput', false), ...
    cellfun(@(s) ['n_' lower(s)], layout.radialNames, 'UniformOutput', false), ...
    {'n_up', 'n_down', 'optimization_time_s', 'fraction_starts_at_best', 'n_starts_feasible', ...
    'poisson_min_distance_mm'}];
designMetrics = cell2table(rows, 'VariableNames', names);

% --- Random 抽選全体の設計指標（抽選ごとに計算して統計をとる）
sumRows = {};
for s = 1:numel(randomSets)
    set = randomSets(s);
    model = models(orders == set.order);
    groups = build_constraint_groups(set.nShots, layout, cfg.constraints);
    mand = zeros(1, 0);
    if strcmp(set.scenario, 'mandatory')
        mand = mandatory;
    end
    key = sprintf('%d|%d', set.order, set.nShots);
    nDraws = size(set.draws, 1);
    v = NaN(nDraws, 8);
    for d = 1:nDraws
        q = design_quality(set.draws(d, :), model, groups, mand, rankTol, K);
        [dEff, iEff] = efficiencies(q, key, refD, refI, model.p);
        v(d, :) = [dEff, iEff, q.balanceQ, q.balanceR, q.balanceS, ...
            q.violationQuadrant > 0, q.violationRadial > 0, q.violationScan > 0];
    end
    med = percentile_linear(v(:, 1:5), 50);
    sumRows(end + 1, :) = {set.scenario, set.method, set.order, set.nShots, nDraws, set.nRejected, ...
        med(1), mean(v(:, 1)), min(v(:, 1)), max(v(:, 1)), med(2), mean(v(:, 2)), min(v(:, 2)), max(v(:, 2)), ...
        mean(v(:, 3)), mean(v(:, 4)), mean(v(:, 5)), mean(v(:, 6)), mean(v(:, 7)), mean(v(:, 8)), ...
        mean(any(v(:, 6:8), 2))}; %#ok<AGROW>
end
randomDesignSummary = cell2table(sumRows, 'VariableNames', {'scenario', 'method', 'howa_order', ...
    'n_shots', 'n_draws', 'n_rejected_draws', 'd_eff_median', 'd_eff_mean', 'd_eff_min', 'd_eff_max', ...
    'i_eff_median', 'i_eff_mean', 'i_eff_min', 'i_eff_max', 'balance_quadrant_mean', ...
    'balance_radial_mean', 'balance_scan_mean', 'violation_rate_quadrant', 'violation_rate_radial', ...
    'violation_rate_scan', 'violation_rate_any'});
end

function [dEff, iEff] = efficiencies(q, key, refD, refI, p)
dEff = NaN;
iEff = NaN;
if isempty(q)
    return
end
if isKey(refD, key) && isfinite(refD(key))
    dEff = exp((q.logdet - refD(key)) / p);
end
if isKey(refI, key) && isfinite(refI(key))
    iEff = refI(key) / q.icrit;
end
end

function parts = violation_parts(q)
if isempty(q)
    parts = NaN(1, 3);
else
    parts = [q.violationQuadrant, q.violationRadial, q.violationScan];
end
end
