function st = compute_statistics(designs, ev, cfg, logFile)
%COMPUTE_STATISTICS Monte Carlo 統計量の表、提案法と比較法の paired comparison、shot削減効果を求める。
%   st.aggregated : 設計 x 条件ごとの残差指標の統計量（平均・中央値・標準偏差・P90・P95・P99・最悪値）
%   st.paired     : 同じwaferでの差 ΔRMS = RMS_比較 - RMS_提案 の統計（t信頼区間・bootstrap信頼区間・勝率）
%   st.reduction  : 基準手法と同等の平均RMS（またはP95）を達成する最小shot数と削減率

conditions = ev.conditionNames;
nC = numel(conditions);
nRec = numel(designs);

% ------------------------------------------------------------ 1. 統計量の表
rows = cell(nRec * nC, 0);
row = 0;
for c = 1:nC
    for r = 1:nRec
        rec = designs(r);
        info = method_info(rec.method);
        values = reshape(squeeze(ev.stats(r, c, :, :))', 1, []);   % 指標ごとに統計量7つ
        row = row + 1;
        rowData = [{conditions{c}, rec.scenario, rec.method, info.label, rec.order, rec.nShots, rec.id}, num2cell(values)];
        rows(row, 1:numel(rowData)) = rowData;
    end
end
statColumns = {};
for m = 1:numel(ev.metricNames)
    for s = 1:numel(ev.statNames)
        statColumns{end + 1} = sprintf('%s_%s', ev.metricNames{m}, ev.statNames{s}); %#ok<AGROW>
    end
end
st.aggregated = cell2table(rows, 'VariableNames', [{'condition', 'scenario', 'method', 'method_label', ...
    'howa_order', 'n_shots', 'design_id'}, statColumns]);

% ------------------------------------------------------------ 2. paired comparison
tPaired = tic;
nW = size(ev.rmsVec{1}, 1);
bootStream = make_stream(cfg.study.master_seed, 'bootstrap');
bootIdx = randi(bootStream, nW, nW, cfg.statistics.bootstrap_samples);
keys = design_keys(designs);
pairRows = {};
scenarios = {'base', 'mandatory'};
for c = 1:nC
    withMedian = any(strcmp(conditions{c}, cfg.statistics.bootstrap_median_conditions));
    for sc = 1:2
        proposed = cfg.statistics.proposed_methods.(scenarios{sc});
        inScenario = strcmp({designs.scenario}, scenarios{sc});
        methodsHere = unique({designs(inScenario).method}, 'stable');
        combos = unique([[designs(inScenario).order]', [designs(inScenario).nShots]'], 'rows');
        for k = 1:size(combos, 1)
            order = combos(k, 1);
            N = combos(k, 2);
            for p = 1:numel(proposed)
                rp = lookup(keys, scenarios{sc}, proposed{p}, order, N);
                if rp == 0
                    continue
                end
                for q = 1:numel(methodsHere)
                    if strcmp(methodsHere{q}, proposed{p})
                        continue
                    end
                    rq = lookup(keys, scenarios{sc}, methodsHere{q}, order, N);
                    if rq == 0
                        continue
                    end
                    s = paired_difference_stats(ev.rmsVec{c}(:, rq), ev.rmsVec{c}(:, rp), bootIdx, ...
                        cfg.statistics.confidence_level, withMedian);
                    pairRows(end + 1, :) = {conditions{c}, scenarios{sc}, order, N, proposed{p}, methodsHere{q}, ...
                        mean(ev.rmsVec{c}(:, rp)), mean(ev.rmsVec{c}(:, rq)), s.meanDelta, s.medianDelta, ...
                        s.stdDelta, s.ciLow, s.ciHigh, s.bootMeanLow, s.bootMeanHigh, s.bootMedianLow, ...
                        s.bootMedianHigh, s.winRate, s.meanImprovementPct, s.bootImprovementLow, ...
                        s.bootImprovementHigh, s.medianImprovementPct, s.improvementOfMeansPct}; %#ok<AGROW>
                end
            end
        end
    end
end
st.paired = cell2table(pairRows, 'VariableNames', {'condition', 'scenario', 'howa_order', 'n_shots', ...
    'proposed_method', 'comparator_method', 'mean_rms_proposed_nm', 'mean_rms_comparator_nm', ...
    'mean_delta_nm', 'median_delta_nm', 'std_delta_nm', 'ci_low_nm', 'ci_high_nm', ...
    'boot_mean_ci_low_nm', 'boot_mean_ci_high_nm', 'boot_median_ci_low_nm', 'boot_median_ci_high_nm', ...
    'win_rate', 'mean_improvement_pct', 'boot_improvement_ci_low_pct', 'boot_improvement_ci_high_pct', ...
    'median_improvement_pct', 'improvement_of_means_pct'});
log_message(logFile, 'paired comparison: %d 組（%.1f 秒）', height(st.paired), toc(tPaired));

% ------------------------------------------------------------ 3. shot削減効果（主評価条件）
st.reduction = shot_reduction(designs, ev, keys, cfg);
end

% ======================================================================
function keys = design_keys(designs)
keys = containers.Map();
for r = 1:numel(designs)
    rec = designs(r);
    if rec.feasible
        keys(sprintf('%s|%s|%d|%d', rec.scenario, rec.method, rec.order, rec.nShots)) = r;
    end
end
end

function r = lookup(keys, scenario, method, order, N)
key = sprintf('%s|%s|%d|%d', scenario, method, order, N);
r = 0;
if isKey(keys, key)
    r = keys(key);
end
end

function T = shot_reduction(designs, ev, keys, cfg)
% 基準手法の shot数 N_ref での平均RMS（または waferごとRMSのP95）を目標とし、
% 各手法がその目標以下になる最小shot数 N* を探す。削減率 = (N_ref - N*) / N_ref × 100。
rmsVec = ev.rmsVec{1};
targets = {'mean', 'p95'};
rows = {};
scenarios = {'base', 'mandatory'};
for sc = 1:2
    inScenario = strcmp({designs.scenario}, scenarios{sc});
    methodsHere = unique({designs(inScenario).method}, 'stable');
    refMethods = cfg.statistics.reduction_reference_methods;
    if strcmp(scenarios{sc}, 'mandatory')
        refMethods = strcat(refMethods, '_f');
    end
    for order = unique([designs(inScenario).order])
        Ns = unique([designs(inScenario & [designs.order] == order).nShots]);
        for rm = 1:numel(refMethods)
            for Nref = Ns
                rr = lookup(keys, scenarios{sc}, refMethods{rm}, order, Nref);
                if rr == 0
                    continue
                end
                for t = 1:2
                    target = metric_value(rmsVec(:, rr), targets{t});
                    for q = 1:numel(methodsHere)
                        nStar = NaN;
                        achieved = NaN;
                        for N = Ns
                            rq = lookup(keys, scenarios{sc}, methodsHere{q}, order, N);
                            if rq == 0
                                continue
                            end
                            value = metric_value(rmsVec(:, rq), targets{t});
                            if value <= target
                                nStar = N;
                                achieved = value;
                                break
                            end
                        end
                        rows(end + 1, :) = {ev.conditionNames{1}, scenarios{sc}, order, refMethods{rm}, Nref, ...
                            targets{t}, target, methodsHere{q}, nStar, achieved, 100 * (Nref - nStar) / Nref}; %#ok<AGROW>
                    end
                end
            end
        end
    end
end
T = cell2table(rows, 'VariableNames', {'condition', 'scenario', 'howa_order', 'reference_method', ...
    'reference_n_shots', 'target_statistic', 'target_rms_nm', 'method', 'required_n_shots', ...
    'achieved_rms_nm', 'measurement_reduction_pct'});
end

function value = metric_value(x, name)
if any(isnan(x))
    value = NaN;
elseif strcmp(name, 'mean')
    value = mean(x);
else
    value = percentile_linear(x, 95);
end
end
