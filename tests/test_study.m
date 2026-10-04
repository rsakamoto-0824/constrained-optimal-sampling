function tests = test_study
%TEST_STUDY 必須の品質確認（仕様書 30章の10項目）と主要な部品の単体テスト。
%   実行: run_tests（リポジトリ直下）または runtests('tests')
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
% runtests は作業フォルダを変えることがあるので、リポジトリ直下を明示的にパスへ追加する
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(rootDir);
setup_paths();
testCase.TestData.rootDir = rootDir;
testCase.TestData.configPath = fullfile(rootDir, 'tests', 'test_config.json');
testCase.TestData.results = run_study(testCase.TestData.configPath, 'MakeFigures', false);
end

% ====================================================================== 必須10項目
function test01_partial_shots_excluded(testCase)
% 1. partial shot が候補に含まれていない（4隅とmarkが usable 領域内、除外されたshotは条件を満たさない）
R = testCase.TestData.results;
layout = R.layout;
halfW = layout.shotWidth / 2;
halfH = layout.shotHeight / 2;
corners = [-halfW -halfH; halfW -halfH; halfW halfH; -halfW halfH; layout.markOffsets];
for k = 1:height(layout.shots)
    x = layout.shots.x_mm(k) + corners(:, 1);
    y = layout.shots.y_mm(k) + corners(:, 2);
    inside = all(hypot(x, y) < layout.usableRadius);
    verifyEqual(testCase, layout.shots.is_candidate(k), inside, sprintf('shot %d', layout.shots.shot_id(k)));
end
verifyGreaterThan(testCase, sum(~layout.shots.is_candidate), 0, 'partial shot が1つもない');
allSelected = [R.designs.design];
verifyTrue(testCase, all(ismember(allSelected, 1:layout.nCand)));
end

function test02_selected_shot_count(testCase)
% 2. 選ばれたshot数が指定値と一致（重複なし）
R = testCase.TestData.results;
for r = 1:numel(R.designs)
    rec = R.designs(r);
    if ~rec.feasible
        continue
    end
    verifyEqual(testCase, numel(rec.design), rec.nShots, sprintf('%s N=%d', rec.method, rec.nShots));
    verifyEqual(testCase, numel(unique(rec.design)), rec.nShots);
end
for s = 1:numel(R.randomSets)
    set = R.randomSets(s);
    verifyEqual(testCase, size(set.draws, 2), set.nShots);
end
end

function test03_mandatory_shots_included(testCase)
% 3. 強制計測shotあり条件の全設計に強制計測shotが必ず含まれる
R = testCase.TestData.results;
verifyNotEmpty(testCase, R.mandatory);
n = 0;
for r = 1:numel(R.designs)
    rec = R.designs(r);
    if strcmp(rec.scenario, 'mandatory') && rec.feasible
        verifyTrue(testCase, all(ismember(R.mandatory, rec.design)), sprintf('%s N=%d', rec.method, rec.nShots));
        n = n + 1;
    end
end
verifyGreaterThan(testCase, n, 0);
for s = 1:numel(R.randomSets)
    if strcmp(R.randomSets(s).scenario, 'mandatory')
        verifyTrue(testCase, all(all(ismember(R.mandatory, R.randomSets(s).draws(1, :)))));
    end
end
end

function test04_quadrant_constraint(testCase)
% 4. 制約付き手法（提案法・素朴な方法）が象限制約を満たす
verify_constraint(testCase, 'violation_quadrant');
end

function test05_radial_constraint(testCase)
% 5. 制約付き手法が半径領域制約を満たす
verify_constraint(testCase, 'violation_radial');
end

function test06_scan_constraint(testCase)
% 6. 制約付き手法が scan 方向制約を満たす（|N_up - N_down| <= δ も直接確認）
verify_constraint(testCase, 'violation_scan');
R = testCase.TestData.results;
T = R.designMetrics;
constrained = ismember(T.method, constrained_methods()) & T.feasible == 1;
delta = R.cfg.constraints.scan.max_abs_difference;
verifyTrue(testCase, all(abs(T.n_up(constrained) - T.n_down(constrained)) <= delta));
end

function test07_full_rank(testCase)
% 7. 最適化による設計（D/I・制約付き・拡張計画）はすべて full rank。
%    rank不足の設計（素朴な方法などで起こりうる）は無効として残差を計算しない（NaN）。
R = testCase.TestData.results;
T = R.designMetrics;
optimized = ismember(T.method, {'dopt', 'iopt', 'cdopt', 'ciopt', 'dopt_aug', 'iopt_aug', 'cdopt_aug', 'ciopt_aug'}) ...
    & T.feasible == 1;
verifyTrue(testCase, all(T.full_rank(optimized) == 1));
verifyTrue(testCase, all(R.ev.fitHealth.full_rank(T.full_rank == 1)));
deficient = find(T.feasible == 1 & T.full_rank == 0);
for k = deficient'
    verifyTrue(testCase, all(isnan(R.ev.rmsVec{1}(:, k))), sprintf('rank不足の設計 %d が評価されている', k));
    verifyEqual(testCase, T.valid(k), 0);
end
end

function test08_coefficient_estimation(testCase)
% 8. HOWA係数推定が数値的に破綻していない
%    (a) 誤差なしの多項式データから係数を正確に復元できる（全次数・N_min の設計）
%    (b) 評価した全設計で係数が有限、条件数の目安が極端でない
R = testCase.TestData.results;
K = R.layout.nMarksPerShot;
for k = 1:numel(R.models)
    model = R.models(k);
    nMin = R.nminTable.n_min(k);
    pick = find(strcmp({R.designs.method}, 'dopt') & [R.designs.order] == model.order ...
        & [R.designs.nShots] == nMin, 1);
    design = R.designs(pick).design;
    rows = reshape((design - 1) * K + (1:K)', [], 1);
    trueCoef = linspace(-2, 3, model.p)';
    z = model.Fcand(rows, :) * trueCoef;
    estimated = model.Fcand(rows, :) \ z;
    verifyLessThan(testCase, max(abs(estimated - trueCoef)), 1e-6, sprintf('HOWA %d次', model.order));
end
health = R.ev.fitHealth(R.designMetrics.valid == 1, :);
verifyTrue(testCase, all(isfinite(health.max_abs_coef_nm)));
verifyLessThan(testCase, max(health.cond_estimate), 1e8);
end

function test09_reproducible_with_same_seed(testCase)
% 9. 同じ seed なら同じ結果（設計と waferごとの残差が完全一致）
R1 = testCase.TestData.results;
R2 = run_study(testCase.TestData.configPath, 'MakeFigures', false);
verifyEqual(testCase, {R2.designs.design}, {R1.designs.design});
verifyEqual(testCase, R2.ws.fingerprint, R1.ws.fingerprint);
for c = 1:numel(R1.ev.rmsVec)
    verifyEqual(testCase, R2.ev.rmsVec{c}, R1.ev.rmsVec{c});
end
end

function test10_same_wafers_for_all_methods(testCase)
% 10. 全手法で同じ wafer realization を使っている（paired comparison）
R = testCase.TestData.results;
used = R.ev.wsFingerprintUsed(R.designMetrics.valid == 1, :);
verifyEqual(testCase, numel(unique(used(:))), 1);
verifyEqual(testCase, unique(used(:)), R.ws.fingerprint(1));
regenerated = generate_wafer_set(R.cfg, R.layout);
verifyEqual(testCase, regenerated.fingerprint, R.ws.fingerprint);
end

% ====================================================================== 部品の単体テスト
function test_howa_term_count(testCase)
verifyEqual(testCase, size(howa_exponents(3), 1), 10);
verifyEqual(testCase, size(howa_exponents(4), 1), 15);
verifyEqual(testCase, size(howa_exponents(5), 1), 21);
end

function test_fringe_numbering(testCase)
terms = fringe_zernike_terms(7, 'radial_degree');
verifyEqual(testCase, height(terms), 36);
% Z4 = 2ρ^2 - 1, Z9 = 6ρ^4 - 6ρ^2 + 1, Z8 = (3ρ^3 - 2ρ) sinθ
rho = 0.7; theta = 0.3;
Z = zernike_basis(rho * cos(theta), rho * sin(theta), 1, terms);
verifyEqual(testCase, Z(terms.fringe == 4), 2 * rho^2 - 1, 'AbsTol', 1e-12);
verifyEqual(testCase, Z(terms.fringe == 9), 6 * rho^4 - 6 * rho^2 + 1, 'AbsTol', 1e-12);
verifyEqual(testCase, Z(terms.fringe == 8), (3 * rho^3 - 2 * rho) * sin(theta), 'AbsTol', 1e-12);
verifyTrue(testCase, all(terms.n <= 7));
end

function test_percentile_and_t(testCase)
verifyEqual(testCase, percentile_linear((1:5)', 50), 3);
verifyEqual(testCase, percentile_linear((1:5)', 95), 4.8, 'AbsTol', 1e-12);
verifyEqual(testCase, t_critical(0.95, 1e6), 1.959964, 'AbsTol', 1e-4);
verifyEqual(testCase, t_critical(0.95, 10), 2.228139, 'AbsTol', 1e-5);
end

function test_optimizer_beats_random(testCase)
% D最適の log det は同じshot数のランダム抽選の最良値以上
R = testCase.TestData.results;
T = R.designMetrics;
for order = R.cfg.howa.orders
    for N = unique(T.n_shots(T.howa_order == order & strcmp(T.scenario, 'base')))'
        d = T.logdet(strcmp(T.method, 'dopt') & T.howa_order == order & T.n_shots == N);
        rnd = T.logdet(strcmp(T.method, 'random') & T.howa_order == order & T.n_shots == N);
        verifyGreaterThanOrEqual(testCase, d, rnd - 1e-9);
    end
end
end

function test_bounds_feasible(testCase)
% スイープ範囲のすべてのshot数で、上下限の合計が shot 数を挟む
% （候補数に近い N では Up/Down の候補数の差から scan 制約を満たせないことがあるので範囲外）
R = testCase.TestData.results;
for N = 3:max(R.nminTable.n_max)
    groups = build_constraint_groups(N, R.layout, R.cfg.constraints);
    for g = 1:numel(groups)
        verifyLessThanOrEqual(testCase, sum(groups(g).lower), N);
        verifyGreaterThanOrEqual(testCase, sum(groups(g).upper), N);
    end
end
end

% ======================================================================
function names = constrained_methods()
names = {'cdopt', 'ciopt', 'cdopt_aug', 'ciopt_aug', 'cdopt_naive', 'ciopt_naive'};
end

function verify_constraint(testCase, column)
R = testCase.TestData.results;
T = R.designMetrics;
constrained = ismember(T.method, constrained_methods()) & T.feasible == 1;
verifyGreaterThan(testCase, sum(constrained), 0);
verifyEqual(testCase, max(T.(column)(constrained)), 0, column);
verifyEqual(testCase, max(T.violation_mandatory(constrained)), 0, 'violation_mandatory');
end
