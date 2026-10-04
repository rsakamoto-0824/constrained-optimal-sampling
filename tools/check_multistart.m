function T = check_multistart(configPath, startCounts)
%CHECK_MULTISTART 制約付き D/I 最適設計の multi-start 回数が足りているかを確かめる。
%   check_multistart('config/default_config.json')                % 20 / 100 / 200 / 400 回
%   check_multistart('config/default_config.json', [20 200 1000])
%   HOWA 3〜5 次・shot 数 8 / 12 / 19 について、各回数で得られた最良の評価値を、
%   最も多い回数の結果に対する効率（D: (det比)^(1/p)、I: 平均予測分散の比）で表にする。
%   結果は results/csv/multistart_check.csv に保存する。
if nargin < 2
    startCounts = [20 100 200 400];
end
rootDir = fileparts(fileparts(mfilename('fullpath')));
addpath(rootDir);
setup_paths();
if ~isfile(configPath)
    configPath = fullfile(rootDir, configPath);
end
cfg = load_config(configPath);
layout = build_shot_layout(cfg);
models = build_model_context(layout, cfg);
rows = {};
for order = cfg.howa.orders
    model = models([models.order] == order);
    for N = [8 12 19]
        groups = build_constraint_groups(N, layout, cfg.constraints);
        for crit = {'D', 'I'}
            problem = struct('info', model.info, 'criterion', crit{1}, 'nFree', N, 'fixed', zeros(1, 0), ...
                'pool', true(layout.nCand, 1), 'groups', groups, 'countOffset', {{}}, 'mode', 'hard', 'softWeight', 0);
            scores = zeros(1, numel(startCounts));
            for s = 1:numel(startCounts)
                opts = struct('nStarts', startCounts(s), 'maxPasses', cfg.optimizer.max_passes, ...
                    'tolerance', cfg.optimizer.convergence_tolerance, 'ridge', cfg.optimizer.ridge_epsilon);
                stream = make_stream(cfg.study.master_seed, sprintf('multistart_check|%d|%d|%s', order, N, crit{1}));
                result = optimize_design(problem, opts, stream);
                scores(s) = result.score;
            end
            if strcmp(crit{1}, 'D')
                efficiency = exp((scores - scores(end)) / model.p);
            else
                efficiency = exp(scores - scores(end));
            end
            for s = 1:numel(startCounts)
                rows(end + 1, :) = {order, N, crit{1}, startCounts(s), efficiency(s)}; %#ok<AGROW>
            end
        end
    end
end
T = cell2table(rows, 'VariableNames', {'howa_order', 'n_shots', 'criterion', 'n_starts', ...
    'efficiency_vs_max_starts'});
outDir = fullfile(rootDir, cfg.study.output_dir, 'csv');
ensure_folder(outDir);
writetable(T, fullfile(outDir, 'multistart_check.csv'));
disp(T);
end
