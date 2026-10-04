function T = run_soft_constraint_study(cfg, layout, models, ws, logFile)
%RUN_SOFT_CONSTRAINT_STUDY soft 制約（罰則つき）の重みを変えたときの、最適性・制約違反・補正残差の関係。
%   主評価は hard 制約だが、soft 制約では「はみ出し1 shotあたりの罰則 λ」で最適性と制約の
%   どちらを優先するかを連続的に調整できる。λ = 0 は制約なし、λ が大きいほど hard 制約に近づく。
%   対象: soft_constraint_study.howa_orders × n_shots × weights、D/I 両方（強制計測shotなし）
%   結果: 平均RMS（主評価条件）、D/I-efficiency（λ = 0 の D最適 / I最適が基準）、制約違反（shot数）
sc = cfg.soft_constraint_study;
K = layout.nMarksPerShot;
nCand = layout.nCand;
orders = [models.order];
rankTol = cfg.optimizer.rank_tolerance;
optOpts = struct('nStarts', cfg.optimizer.n_starts, 'maxPasses', cfg.optimizer.max_passes, ...
    'tolerance', cfg.optimizer.convergence_tolerance, 'ridge', cfg.optimizer.ridge_epsilon);
sigma = cfg.mark_noise.levels.(cfg.conditions(1).mark_noise_level);
scale = cfg.conditions(1).scan_scale;
criteria = {'D', 'I'};
weights = reshape(sc.weights, 1, []);
rows = {};
for order = reshape(sc.howa_orders, 1, [])
    model = models(orders == order);
    for N = reshape(sc.n_shots, 1, [])
        groups = build_constraint_groups(N, layout, cfg.constraints);
        qualities = cell(2, numel(weights));
        metrics = cell(2, numel(weights));
        times = zeros(2, numel(weights));
        for c = 1:2
            for k = 1:numel(weights)
                mode = 'soft';
                if weights(k) == 0
                    mode = 'none';
                end
                problem = struct('info', model.info, 'criterion', criteria{c}, 'nFree', N, ...
                    'fixed', zeros(1, 0), 'pool', true(nCand, 1), 'groups', groups, 'countOffset', {{}}, ...
                    'mode', mode, 'softWeight', weights(k));
                % D と I・全重みで同じ初期解を使う
                stream = make_stream(cfg.study.master_seed, sprintf('soft|order%d|N%d', order, N));
                result = optimize_design(problem, optOpts, stream);
                qualities{c, k} = design_quality(result.design, model, groups, zeros(1, 0), rankTol, K);
                metrics{c, k} = evaluate_design(result.design, model, layout, ws, sigma, scale, ...
                    cfg.evaluation.include_scan_in_truth, false);
                times(c, k) = result.timeSeconds;
            end
        end
        refD = qualities{1, weights == 0};
        refI = qualities{2, weights == 0};
        for c = 1:2
            for k = 1:numel(weights)
                q = qualities{c, k};
                met = metrics{c, k};
                rows(end + 1, :) = {order, N, criteria{c}, weights(k), q.violationQuadrant, q.violationRadial, ...
                    q.violationScan, q.violationQuadrant + q.violationRadial + q.violationScan, ...
                    q.balanceQ, q.balanceR, q.balanceS, exp((q.logdet - refD.logdet) / model.p), ...
                    refI.icrit / q.icrit, mean(met(:, 3)), percentile_linear(met(:, 3), 95), ...
                    mean(met(:, 7)), times(c, k)}; %#ok<AGROW>
            end
        end
    end
end
T = cell2table(rows, 'VariableNames', {'howa_order', 'n_shots', 'criterion', 'soft_weight', ...
    'violation_quadrant', 'violation_radial', 'violation_scan', 'violation_total', 'balance_quadrant', ...
    'balance_radial', 'balance_scan', 'd_efficiency', 'i_efficiency', 'rms_vec_mean_nm', ...
    'rms_vec_p95_nm', 'rms_vec_interior_mean_nm', 'optimization_time_s'});
log_message(logFile, 'soft 制約の重みスイープ: %d 設計', height(T));
end
