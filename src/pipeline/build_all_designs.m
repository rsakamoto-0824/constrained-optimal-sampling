function [designs, randomSets, nminTable, sweeps] = build_all_designs(cfg, layout, models, mandatory, logFile)
%BUILD_ALL_DESIGNS 全HOWA次数・全計測shot数・全手法のsampling設計を作る。
%   設計はwaferの真値に依存しないので、ここで一度だけ作り、1000 waferの評価で再利用する。
%   designs    : 決定的に1つに決まる設計（Poisson・Human・各最適化）の一覧（struct配列）
%   randomSets : Randomの抽選結果（n_draws 回分）の一覧
%   nminTable  : HOWA次数ごとの N_min
%   sweeps     : HOWA次数ごとの計測shot数のスイープ値（cell）

K = layout.nMarksPerShot;
nCand = layout.nCand;
seed = cfg.study.master_seed;
rankTol = cfg.optimizer.rank_tolerance;
optOpts = struct('nStarts', cfg.optimizer.n_starts, 'maxPasses', cfg.optimizer.max_passes, ...
    'tolerance', cfg.optimizer.convergence_tolerance, 'ridge', cfg.optimizer.ridge_epsilon);
constraintMode = cfg.constraints.mode;
if strcmp(constraintMode, 'none')
    error('build_all_designs:noConstraint', ...
        '制約付き手法を評価するため constraints.mode は hard か soft にしてください。');
end

% --- N_min（full rank の設計が存在する最小shot数）とスイープ範囲
% 1e-6 は 1/3 を 0.3333333333 と書いたときに floor(57/3)=19 が 18 にならないための余裕
nMax = floor(nCand * cfg.sweep.max_fraction_of_candidates + 1e-6);
nminRows = cell(numel(models), 7);
sweeps = cell(1, numel(models));
for k = 1:numel(models)
    info = determine_nmin(models(k), nCand, K, optOpts, rankTol, ...
        make_stream(seed, sprintf('nmin|order%d', models(k).order)));
    sweeps{k} = build_sweep(info.nMin, nMax, cfg.sweep);
    nminRows(k, :) = {models(k).order, models(k).p, info.lowerBound, info.nMin, info.svRatio, nMax, numel(sweeps{k})};
    log_message(logFile, 'HOWA %d次: 項数 p = %d、4N >= p の下限 N = %d、full rank の最小 N_min = %d、スイープ %d〜%d（%d点）', ...
        models(k).order, models(k).p, info.lowerBound, info.nMin, info.nMin, nMax, numel(sweeps{k}));
end
nminTable = cell2table(nminRows, 'VariableNames', {'howa_order', 'n_terms', 'n_lower_bound', ...
    'n_min', 'sv_ratio_at_n_min', 'n_max', 'n_sweep_values'});

% --- 外部CSVの人手配置（あれば）
humanPlans = containers.Map('KeyType', 'double', 'ValueType', 'any');
if ~isempty(cfg.human.csv_path)
    humanPlans = load_human_design_csv(cfg.human.csv_path, layout);
end

designs = empty_design_record();
randomSets = struct('scenario', {}, 'method', {}, 'order', {}, 'nShots', {}, 'draws', {}, 'nRejected', {});
poissonCache = containers.Map();
humanCache = containers.Map();
xy = [layout.cand.x_mm, layout.cand.y_mm];
nF = numel(mandatory);
noMandatory = zeros(1, 0);

for k = 1:numel(models)
    model = models(k);
    m = model.order;
    isValid = @(d) design_full_rank(d, model, K, rankTol);
    tOrder = tic;
    for N = sweeps{k}
        groups = build_constraint_groups(N, layout, cfg.constraints);

        % ================= 強制計測shotなし（手法1〜7）
        randomSets(end + 1) = make_random_set('base', 'random', m, N, cfg, nCand, noMandatory, isValid); %#ok<AGROW>
        designs(end + 1) = cached_poisson('base', 'poisson', m, N, noMandatory, cfg, xy, poissonCache); %#ok<AGROW>
        designs(end + 1) = cached_human('base', 'human', m, N, noMandatory, cfg, layout, humanPlans, humanCache); %#ok<AGROW>
        designs = [designs, run_optimizer_pair('base', {'dopt', 'iopt'}, model, N, groups, ...
            noMandatory, true(nCand, 1), [], 'none', cfg, optOpts, sprintf('opt|base|none|order%d|N%d', m, N))]; %#ok<AGROW>
        designs = [designs, run_optimizer_pair('base', {'cdopt', 'ciopt'}, model, N, groups, ...
            noMandatory, true(nCand, 1), [], constraintMode, cfg, optOpts, sprintf('opt|base|constrained|order%d|N%d', m, N))]; %#ok<AGROW>

        % ================= 強制計測shotあり（手法8・9と比較対象）
        if nF == 0 || N <= nF
            continue
        end
        randomSets(end + 1) = make_random_set('mandatory', 'random_f', m, N, cfg, nCand, mandatory, isValid); %#ok<AGROW>
        designs(end + 1) = cached_poisson('mandatory', 'poisson_f', m, N, mandatory, cfg, xy, poissonCache); %#ok<AGROW>
        designs(end + 1) = cached_human('mandatory', 'human_f', m, N, mandatory, cfg, layout, humanPlans, humanCache); %#ok<AGROW>
        % 制約なしの拡張計画（強制shotの情報量を考慮、制約なし）
        designs = [designs, run_optimizer_pair('mandatory', {'dopt_aug', 'iopt_aug'}, model, N, groups, ...
            mandatory, true(nCand, 1), [], 'none', cfg, optOpts, sprintf('opt|mand|aug_none|order%d|N%d', m, N))]; %#ok<AGROW>
        % 素朴な方法: 強制shotの情報量を無視して残りだけを最適化し、あとで強制shotを足す
        %            （制約は最終設計全体で満たすよう、強制shotの数を countOffset で数える）
        pool = true(nCand, 1);
        pool(mandatory) = false;
        designs = [designs, run_optimizer_pair('mandatory', {'cdopt_naive', 'ciopt_naive'}, model, N, groups, ...
            noMandatory, pool, count_levels(mandatory, groups), constraintMode, cfg, optOpts, ...
            sprintf('opt|mand|naive|order%d|N%d', m, N), mandatory)]; %#ok<AGROW>
        % 提案法: 制約付き拡張実験計画（強制shotを固定し、その情報量を含めて追加shotを最適化）
        designs = [designs, run_optimizer_pair('mandatory', {'cdopt_aug', 'ciopt_aug'}, model, N, groups, ...
            mandatory, true(nCand, 1), [], constraintMode, cfg, optOpts, sprintf('opt|mand|aug|order%d|N%d', m, N))]; %#ok<AGROW>
    end
    log_message(logFile, 'HOWA %d次の設計を作成（%.1f 秒）', m, toc(tOrder));
end
for k = 1:numel(designs)
    designs(k).id = k;
end
end

% ======================================================================
function record = empty_design_record()
record = struct('id', {}, 'scenario', {}, 'method', {}, 'order', {}, 'nShots', {}, 'design', {}, ...
    'drawIndex', {}, 'feasible', {}, 'timeSeconds', {}, 'fractionStartsAtBest', {}, ...
    'nStartsFeasible', {}, 'poissonMinDistance', {}, 'criterionScore', {});
end

function record = new_record(scenario, method, order, N, design)
record = struct('id', 0, 'scenario', scenario, 'method', method, 'order', order, 'nShots', N, ...
    'design', design, 'drawIndex', NaN, 'feasible', ~isempty(design), 'timeSeconds', NaN, ...
    'fractionStartsAtBest', NaN, 'nStartsFeasible', NaN, 'poissonMinDistance', NaN, 'criterionScore', NaN);
end

function tf = design_full_rank(design, model, K, rankTol)
rows = reshape((design - 1) * K + (1:K)', [], 1);
s = svd(model.Xt(rows, :));
tf = numel(s) >= model.p && s(1) > 0 && s(model.p) / s(1) > rankTol;
end

function set = make_random_set(scenario, method, order, N, cfg, nCand, fixed, isValid)
stream = make_stream(cfg.study.master_seed, sprintf('random|%s|order%d|N%d', scenario, order, N));
[draws, nRejected] = random_sampling(N, nCand, fixed, cfg.random_sampling.n_draws, ...
    cfg.random_sampling.max_redraws_per_draw, stream, isValid);
set = struct('scenario', scenario, 'method', method, 'order', order, 'nShots', N, ...
    'draws', draws, 'nRejected', nRejected);
end

function record = cached_poisson(scenario, method, order, N, fixed, cfg, xy, cache)
% Poisson配置はHOWA次数によらないので、shot数ごとに一度だけ作る
key = sprintf('%s|%d', scenario, N);
if ~isKey(cache, key)
    stream = make_stream(cfg.study.master_seed, ['poisson|' key]);
    tStart = tic;
    [design, info] = poisson_disk_sampling(N, xy, fixed, cfg.poisson.n_starts, stream);
    cache(key) = struct('design', design, 'minDistance', info.minDistance, 'time', toc(tStart));
end
item = cache(key);
record = new_record(scenario, method, order, N, item.design);
record.poissonMinDistance = item.minDistance;
record.timeSeconds = item.time;
end

function record = cached_human(scenario, method, order, N, fixed, cfg, layout, humanPlans, cache)
key = sprintf('%s|%d', scenario, N);
if ~isKey(cache, key)
    if isKey(humanPlans, N)
        design = humanPlans(N);
        missing = setdiff(fixed, design);
        if ~isempty(missing)
            warning('build_all_designs:humanMissingMandatory', ...
                'CSVの人手配置（%d shot）に強制計測shotが含まれていません。', N);
        end
    else
        design = human_sampling(N, layout, fixed, cfg.human);
    end
    cache(key) = design;
end
record = new_record(scenario, method, order, N, cache(key));
end

function records = run_optimizer_pair(scenario, methods, model, N, groups, fixed, pool, countOffset, ...
    mode, cfg, optOpts, streamLabel, appendAfter)
%   methods = {D基準の手法キー, I基準の手法キー}。D と I は同じ乱数ラベル（= 同じ初期解）を使う。
%   appendAfter: 最適化の後で設計に足すshot（素朴な方法の強制shot）
if nargin < 13
    appendAfter = zeros(1, 0);
end
criteria = {'D', 'I'};
problems = cell(1, 2);
results = cell(1, 2);
for c = 1:2
    problems{c} = struct('info', model.info, 'criterion', criteria{c}, ...
        'nFree', N - numel(fixed) - numel(appendAfter), 'fixed', fixed, 'pool', pool, ...
        'groups', groups, 'countOffset', {countOffset}, 'mode', mode, ...
        'softWeight', cfg.constraints.soft_penalty_weight);
    results{c} = optimize_design(problems{c}, optOpts, make_stream(cfg.study.master_seed, streamLabel));
end
% 相互の初期解: D の最良解から I を、I の最良解から D をもう1回ずつ探索する。
% I基準は rank 不足に近い初期解から局所解に陥りやすいため。D と I で同じ回数（nStarts + 1）にそろう。
for c = 1:2
    other = results{3 - c};
    if ~other.feasible || problems{c}.nFree == 0
        continue
    end
    seeded = optOpts;
    seeded.initialFree = {other.free};
    extra = optimize_design(problems{c}, seeded, make_stream(cfg.study.master_seed, [streamLabel '|cross']));
    results{c} = merge_results(results{c}, extra);
end
records = new_record(scenario, methods{1}, model.order, N, []);
records(2) = new_record(scenario, methods{2}, model.order, N, []);
for c = 1:2
    result = results{c};
    design = [];
    if result.feasible
        design = sort([result.design, appendAfter]);
    end
    records(c) = new_record(scenario, methods{c}, model.order, N, design);
    records(c).timeSeconds = result.timeSeconds;
    records(c).fractionStartsAtBest = result.fractionStartsAtBest;
    records(c).nStartsFeasible = sum(isfinite(result.startScores));
    records(c).criterionScore = result.score;
end
end

function merged = merge_results(base, extra)
% 追加の探索結果を合わせ、良い方の解を残す（計算時間と初期解ごとの値は足し合わせる）
merged = base;
if extra.score > base.score
    merged.free = extra.free;
    merged.design = extra.design;
    merged.score = extra.score;
    merged.feasible = true;
end
merged.startScores = [base.startScores, extra.startScores];
merged.passesUsed = [base.passesUsed, extra.passesUsed];
merged.timeSeconds = base.timeSeconds + extra.timeSeconds;
merged.fractionStartsAtBest = mean(abs(merged.startScores - merged.score) <= 1e-6 * max(1, abs(merged.score)));
end
