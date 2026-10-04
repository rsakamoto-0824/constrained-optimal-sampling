function results = run_study(configPath, varargin)
%RUN_STUDY 実務制約付き最適サンプリングの評価を最初から最後まで実行する。
%   run_study('config/default_config.json')  : 本計算（1000 wafer）
%   run_study('config/smoke_config.json')    : 小規模な動作確認
%   run_study(..., 'MakeFigures', false)     : 図を作らない（CSVと結果ファイルだけ）
%
%   流れ
%     1. shot配置・partial shot除外・評価点        → csv/shot_candidates.csv ほか
%     2. HOWA次数ごとの行列と N_min                 → csv/nmin.csv
%     3. 全手法の sampling 設計（waferに依存しないので1回だけ）
%     4. 1000 wafer の真値・scan成分・mark誤差（全手法で共通）
%     5. Monte Carlo 評価（全設計 × 全条件）
%     6. 統計量・paired comparison・shot削減効果 → csv/*.csv
%     7. 図（figures/）と Appendix の代表wafer 3例（figures/appendix/）
%   乱数seed・MATLABの版・実行日時・設定内容・計算時間は run_info.json と logs/ に残す。

parser = inputParser;
parser.addParameter('MakeFigures', true, @(x) islogical(x) || isnumeric(x));
parser.parse(varargin{:});
makeFigures = logical(parser.Results.MakeFigures);

rootDir = setup_paths();
if nargin < 1 || isempty(configPath)
    configPath = fullfile(rootDir, 'config', 'default_config.json');
end
if ~isfile(configPath) && isfile(fullfile(rootDir, configPath))
    configPath = fullfile(rootDir, configPath);
end
cfg = load_config(configPath);
outDir = cfg.study.output_dir;
if ~is_absolute(outDir)
    outDir = fullfile(rootDir, outDir);
end
ensure_folder(outDir);
ensure_folder(fullfile(outDir, 'logs'));
logFile = fullfile(outDir, 'logs', 'run_log.txt');
if isfile(logFile)
    delete(logFile);
end
startTime = datetime('now');
timing = {};
totalTimer = tic;
log_message(logFile, '開始: %s（設定 %s）', cfg.study.name, cfg.source_path);

%% 1. shot配置
t = tic;
layout = build_shot_layout(cfg);
mandatory = resolve_mandatory_shots(layout, cfg.mandatory);
log_message(logFile, '全shot %d（うち候補 %d、partial shot %d）、評価点（有効mark）%d、強制計測shot ID = %s', ...
    height(layout.shots), layout.nCand, height(layout.shots) - layout.nCand, height(layout.evalPoints), ...
    mat2str(layout.cand.shot_id(mandatory)'));
timing(end + 1, :) = {'1_layout', toc(t)};

%% 2. HOWA次数ごとの行列
t = tic;
models = build_model_context(layout, cfg);
timing(end + 1, :) = {'2_model', toc(t)};

%% 3. sampling 設計
t = tic;
[designs, randomSets, nminTable, sweeps] = build_all_designs(cfg, layout, models, mandatory, logFile);
log_message(logFile, '設計 %d 件、Random 抽選 %d 組を作成', numel(designs), numel(randomSets));
timing(end + 1, :) = {'3_designs', toc(t)};

%% 4. wafer 真値・scan成分・mark誤差
t = tic;
ws = generate_wafer_set(cfg, layout);
log_message(logFile, 'wafer %d 枚を生成（Zernike %d 項から各 %d〜%d 項）', ws.nWafers, height(ws.terms), ...
    cfg.zernike.min_terms, cfg.zernike.max_terms);
floorTable = model_mismatch_floor(models, ws);
for k = 1:numel(models)
    log_message(logFile, 'HOWA %d次のモデル不一致の下限（全評価点・誤差なし）: 平均 %.3f nm', models(k).order, ...
        mean(floorTable{:, k + 1}));
end
timing(end + 1, :) = {'4_wafers', toc(t)};

%% 5. Monte Carlo 評価
t = tic;
[ev, designs] = evaluate_all(designs, randomSets, cfg, layout, models, ws, logFile);
timing(end + 1, :) = {'5_evaluation', toc(t)};

%% 6. 統計量
t = tic;
[designMetrics, randomDesignSummary, qualities] = compute_design_metrics(designs, randomSets, models, layout, cfg, mandatory);
st = compute_statistics(designs, ev, cfg, logFile);
appendixSamples = select_appendix_samples(designs, ev, cfg);
timing(end + 1, :) = {'6_statistics', toc(t)};

t = tic;
softStudy = table();
if cfg.soft_constraint_study.enabled
    softStudy = run_soft_constraint_study(cfg, layout, models, ws, logFile);
end
timing(end + 1, :) = {'6_soft_constraint_study', toc(t)};

t = tic;
files = write_outputs(outDir, cfg, layout, mandatory, designs, randomSets, nminTable, ...
    designMetrics, randomDesignSummary, ws, ev, st, logFile);
writetable(appendixSamples.table, fullfile(outDir, 'csv', 'appendix_samples.csv'));
writetable(floorTable, fullfile(outDir, 'csv', 'model_mismatch_floor.csv'));
if ~isempty(softStudy)
    writetable(softStudy, fullfile(outDir, 'csv', 'soft_constraint_study.csv'));
end
timing(end + 1, :) = {'6_write_csv', toc(t)};

results = struct('cfg', cfg, 'layout', layout, 'mandatory', mandatory, 'models', models, ...
    'designs', designs, 'randomSets', randomSets, 'nminTable', nminTable, 'sweeps', {sweeps}, ...
    'ws', ws, 'ev', ev, 'st', st, 'designMetrics', designMetrics, ...
    'randomDesignSummary', randomDesignSummary, 'qualities', {qualities}, ...
    'appendixSamples', appendixSamples, 'floorTable', floorTable, 'softStudy', softStudy, 'outDir', outDir);

%% 7. 図
if makeFigures
    t = tic;
    make_figures(results);
    make_appendix_figures(results);
    timing(end + 1, :) = {'7_figures', toc(t)};
end

%% 実行情報
timing(end + 1, :) = {'total', toc(totalTimer)};
timingTable = cell2table(timing, 'VariableNames', {'stage', 'seconds'});
writetable(timingTable, fullfile(outDir, 'logs', 'timing_log.csv'));
runInfo = struct();
runInfo.study_name = cfg.study.name;
runInfo.started_at = char(startTime, 'yyyy/MM/dd HH:mm:ss');
runInfo.finished_at = char(datetime('now'), 'yyyy/MM/dd HH:mm:ss');
runInfo.matlab_version = version;
runInfo.computer = computer;
runInfo.git_commit = git_commit_hash(rootDir);
runInfo.config_path = cfg.source_path;
runInfo.master_seed = cfg.study.master_seed;
runInfo.n_wafers = ws.nWafers;
runInfo.n_candidates = layout.nCand;
runInfo.mandatory_shot_ids = layout.cand.shot_id(mandatory)';
runInfo.wafer_fingerprint = ws.fingerprint;
runInfo.all_methods_used_same_wafers = numel(unique(ev.wsFingerprintUsed(~isnan(ev.wsFingerprintUsed)))) == 1;
runInfo.timing_seconds = cell2struct(timing(:, 2), regexprep(timing(:, 1), '^(\d)', 'stage_$1'), 1);
runInfo.config = cfg;
write_json(runInfo, fullfile(outDir, 'run_info.json'));
copyfile(cfg.source_path, fullfile(outDir, 'config_used.json'));
write_json(cfg, fullfile(outDir, 'config_resolved.json'));
save(fullfile(outDir, 'study_results.mat'), '-struct', 'results', '-v7.3');
log_message(logFile, '完了: 合計 %.1f 秒。結果は %s', toc(totalTimer), outDir);
end

function tf = is_absolute(p)
tf = startsWith(p, '/') || startsWith(p, '\') || (numel(p) >= 2 && p(2) == ':');
end
