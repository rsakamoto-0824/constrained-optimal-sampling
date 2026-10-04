function [ev, designs] = evaluate_all(designs, randomSets, cfg, layout, models, ws, logFile)
%EVALUATE_ALL 全設計 × 全評価条件について、1000 wafer の HOWA 補正残差を計算する。
%   全手法が同じ ws（真値・scan成分・mark誤差）を使う paired comparison。
%   1. Random の各抽選を評価し（RMSのみ）、主評価条件で平均RMSが中央値の抽選を代表として
%      手法 'random' / 'random_f' の設計に加える
%   2. 全設計を全条件で評価し、waferごとの指標と Monte Carlo 統計量を求める
%
%   ev.rmsVec{c}        : 条件 c の waferごとの vector RMS（N_wafer x 設計数）
%   ev.full{c}          : waferごとの全指標（N_wafer x 7 x 設計数）。output.wafer_csv_conditions と主評価のみ
%   ev.stats            : 統計量（設計数 x 条件数 x 指標7 x 統計量7）
%   ev.randomSummary    : Random 抽選ごとの結果のまとめ（表）
%   ev.fitHealth        : 主評価条件での推定の健全性（条件数の目安・係数の最大絶対値）

conditions = cfg.conditions;
nC = numel(conditions);
nW = ws.nWafers;
orders = [models.order];
inc = cfg.evaluation.include_scan_in_truth;
nWorkers = 0;
if cfg.parallel.enabled && license('test', 'Distrib_Computing_Toolbox')
    nWorkers = cfg.parallel.max_workers;
end

% ---------------------------------------------------------------- 1. Random
tRandom = tic;
fastCaches = cell(1, numel(models));
for k = 1:numel(models)
    fastCaches{k} = build_fast_rms_cache(models(k), ws);
end
summaryRows = {};
for r = 1:numel(randomSets)
    set = randomSets(r);
    model = models(orders == set.order);
    fastCache = fastCaches{orders == set.order};
    nDraws = size(set.draws, 1);
    meanByCondition = zeros(nDraws, nC);
    p95ByCondition = zeros(nDraws, nC);
    for c = 1:nC
        [sigma, scale] = condition_values(cfg, conditions(c));
        for d = 1:nDraws
            met = evaluate_design(set.draws(d, :), model, layout, ws, sigma, scale, inc, true, fastCache);
            meanByCondition(d, c) = mean(met(:, 3));
            p95ByCondition(d, c) = percentile_linear(met(:, 3), 95);
        end
    end
    % 代表抽選: 主評価条件で平均RMSが中央値（偶数個なら下側の中央）の抽選
    [~, orderIdx] = sort(meanByCondition(:, 1));
    rep = orderIdx(ceil(nDraws / 2));
    record = designs(1);
    record.id = numel(designs) + 1;
    record.scenario = set.scenario;
    record.method = set.method;
    record.order = set.order;
    record.nShots = set.nShots;
    record.design = set.draws(rep, :);
    record.drawIndex = rep;
    record.feasible = true;
    record.timeSeconds = NaN;
    record.fractionStartsAtBest = NaN;
    record.nStartsFeasible = NaN;
    record.poissonMinDistance = NaN;
    record.criterionScore = NaN;
    designs(end + 1) = record; %#ok<AGROW>
    for c = 1:nC
        meanRms = meanByCondition(:, c);
        q = percentile_linear(meanRms, [50, 95]);
        q95 = percentile_linear(p95ByCondition(:, c), [50, 95]);
        summaryRows(end + 1, :) = {conditions(c).name, set.scenario, set.method, set.order, set.nShots, ...
            nDraws, set.nRejected, rep, q(1), mean(meanRms), q(2), min(meanRms), max(meanRms), ...
            meanRms(rep), q95(1), mean(p95ByCondition(:, c)), q95(2), min(p95ByCondition(:, c)), ...
            max(p95ByCondition(:, c))}; %#ok<AGROW>
    end
end
ev.randomSummary = cell2table(summaryRows, 'VariableNames', {'condition', 'scenario', 'method', ...
    'howa_order', 'n_shots', 'n_draws', 'n_rejected_draws', 'representative_draw', ...
    'mean_rms_median_over_draws', 'mean_rms_mean_over_draws', 'mean_rms_p95_over_draws', ...
    'mean_rms_best_draw', 'mean_rms_worst_draw', 'mean_rms_representative', ...
    'p95_rms_median_over_draws', 'p95_rms_mean_over_draws', 'p95_rms_p95_over_draws', ...
    'p95_rms_best_draw', 'p95_rms_worst_draw'});
log_message(logFile, 'Random 抽選の評価: %d 組 x %d 抽選 x %d 条件（%.1f 秒）', ...
    numel(randomSets), cfg.random_sampling.n_draws, nC, toc(tRandom));

% ---------------------------------------------------------------- 2. 全設計
nRec = numel(designs);
fullConditions = unique([{conditions(1).name}, cfg.output.wafer_csv_conditions], 'stable');
ev.conditionNames = {conditions.name};
ev.fullConditionNames = fullConditions;
ev.rmsVec = cell(1, nC);
ev.full = cell(1, nC);
ev.stats = NaN(nRec, nC, 7, 7);
ev.statNames = {'mean', 'median', 'std', 'p90', 'p95', 'p99', 'worst'};
ev.metricNames = residual_metric_names();
ev.wsFingerprintUsed = NaN(nRec, nC);
ev.fitHealth = table((1:nRec)', NaN(nRec, 1), NaN(nRec, 1), false(nRec, 1), ...
    'VariableNames', {'design_id', 'cond_estimate', 'max_abs_coef_nm', 'full_rank'});
for c = 1:nC
    tCond = tic;
    [sigma, scale] = condition_values(cfg, conditions(c));
    metricsAll = NaN(nW, 7, nRec);
    fingerprintUsed = NaN(nRec, 1);
    condEst = NaN(nRec, 1);
    maxCoef = NaN(nRec, 1);
    fullRank = false(nRec, 1);
    parfor (r = 1:nRec, nWorkers)
        rec = designs(r);
        if ~rec.feasible
            continue
        end
        model = models(orders == rec.order); %#ok<PFBNS>
        [met, fit] = evaluate_design(rec.design, model, layout, ws, sigma, scale, inc, false);
        metricsAll(:, :, r) = met;
        fingerprintUsed(r) = ws.fingerprint(1);
        condEst(r) = fit.condEstimate;
        maxCoef(r) = fit.maxAbsCoef;
        fullRank(r) = fit.fullRank;
    end
    ev.rmsVec{c} = squeeze(metricsAll(:, 3, :));
    if nRec == 1
        ev.rmsVec{c} = metricsAll(:, 3, 1);
    end
    if any(strcmp(conditions(c).name, fullConditions))
        ev.full{c} = metricsAll;
    end
    for r = 1:nRec
        s = summarize_distribution(metricsAll(:, :, r));
        for st = 1:7
            ev.stats(r, c, :, st) = s.(ev.statNames{st});
        end
    end
    ev.wsFingerprintUsed(:, c) = fingerprintUsed;
    if c == 1
        ev.fitHealth.cond_estimate = condEst;
        ev.fitHealth.max_abs_coef_nm = maxCoef;
        ev.fitHealth.full_rank = fullRank;
    end
    log_message(logFile, '条件 %s: %d 設計 x %d wafer を評価（%.1f 秒）', conditions(c).name, nRec, nW, toc(tCond));
end
end

function cache = build_fast_rms_cache(model, ws)
% 残差2乗和の高速計算に使う量（真値は条件によらないので次数ごとに1回だけ作る）
cache.G = model.Feval' * model.Feval;
cache.FtX = model.Feval' * ws.truthX;
cache.FtY = model.Feval' * ws.truthY;
cache.ttX = sum(ws.truthX .^ 2, 1);
cache.ttY = sum(ws.truthY .^ 2, 1);
cache.nEval = size(model.Feval, 1);
end

function [sigma, scale] = condition_values(cfg, condition)
sigma = cfg.mark_noise.levels.(condition.mark_noise_level);
scale = condition.scan_scale;
end
