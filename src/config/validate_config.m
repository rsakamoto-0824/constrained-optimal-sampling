function cfg = validate_config(cfg)
%VALIDATE_CONFIG 設定値の存在・型・範囲を確認し、配列の向きなどを揃えて返す。
%   誤りがあれば、どの項目をどう直せばよいかが分かるメッセージでエラーにする。

require_fields(cfg, {'study', 'wafer', 'shot', 'marks', 'scan', 'howa', 'sweep', ...
    'constraints', 'mandatory', 'optimizer', 'random_sampling', 'poisson', 'human', ...
    'zernike', 'monte_carlo', 'scan_noise', 'mark_noise', 'conditions', 'evaluation', ...
    'statistics', 'appendix', 'figures', 'parallel', 'output'}, 'config');

% --- study
cfg.study.name = char(cfg.study.name);
cfg.study.output_dir = char(cfg.study.output_dir);
check_integer(cfg.study.master_seed, 0, 2^31, 'study.master_seed');

% --- wafer / shot / marks
check_positive(cfg.wafer.diameter_mm, 'wafer.diameter_mm');
check_range(cfg.wafer.edge_exclusion_mm, 0, cfg.wafer.diameter_mm / 2, 'wafer.edge_exclusion_mm');
check_positive(cfg.shot.width_mm, 'shot.width_mm');
check_positive(cfg.shot.height_mm, 'shot.height_mm');
check_positive(cfg.shot.pitch_x_mm, 'shot.pitch_x_mm');
check_positive(cfg.shot.pitch_y_mm, 'shot.pitch_y_mm');
cfg.shot.grid_origin_mm = reshape(cfg.shot.grid_origin_mm, 1, []);
if numel(cfg.shot.grid_origin_mm) ~= 2
    error('validate_config:gridOrigin', 'shot.grid_origin_mm は [x, y] の2要素で指定してください。');
end
cfg.marks.offsets_mm = as_n_by_2(cfg.marks.offsets_mm, 'marks.offsets_mm');

% --- scan direction assignment
validModes = {'alternate_column', 'alternate_row', 'checkerboard', 'all_up', 'csv'};
cfg.scan.assignment = check_choice(cfg.scan.assignment, validModes, 'scan.assignment');
cfg.scan.first_direction = check_choice(cfg.scan.first_direction, {'Up', 'Down'}, 'scan.first_direction');
cfg.scan.csv_path = char(cfg.scan.csv_path);
if strcmp(cfg.scan.assignment, 'csv') && isempty(cfg.scan.csv_path)
    error('validate_config:scanCsv', 'scan.assignment が csv のときは scan.csv_path を指定してください。');
end

% --- HOWA
cfg.howa.orders = reshape(cfg.howa.orders, 1, []);
for k = 1:numel(cfg.howa.orders)
    check_integer(cfg.howa.orders(k), 1, 10, 'howa.orders');
end
check_positive(cfg.howa.normalization_radius_mm, 'howa.normalization_radius_mm');

% --- sweep
cfg.sweep.mode = check_choice(cfg.sweep.mode, {'full', 'adaptive'}, 'sweep.mode');
check_integer(cfg.sweep.step, 1, 1000, 'sweep.step');
check_range(cfg.sweep.max_fraction_of_candidates, 0, 1, 'sweep.max_fraction_of_candidates');
check_integer(cfg.sweep.adaptive_fine_until, 1, 10000, 'sweep.adaptive_fine_until');
check_integer(cfg.sweep.adaptive_coarse_step, 1, 1000, 'sweep.adaptive_coarse_step');

% --- constraints
cfg.constraints.mode = check_choice(cfg.constraints.mode, {'hard', 'soft', 'none'}, 'constraints.mode');
check_range(cfg.constraints.soft_penalty_weight, 0, Inf, 'constraints.soft_penalty_weight');
cfg.constraints.quadrant = validate_group(cfg.constraints.quadrant, 4, 'constraints.quadrant');
nRadial = numel(cfg.constraints.radial.boundaries_norm) + 1;
cfg.constraints.radial.boundaries_norm = reshape(cfg.constraints.radial.boundaries_norm, 1, []);
if any(diff(cfg.constraints.radial.boundaries_norm) <= 0) || any(cfg.constraints.radial.boundaries_norm <= 0)
    error('validate_config:radialBoundaries', 'constraints.radial.boundaries_norm は正の昇順で指定してください。');
end
cfg.constraints.radial.names = cellstr(cfg.constraints.radial.names);
cfg.constraints.radial.names = reshape(cfg.constraints.radial.names, 1, []);
if numel(cfg.constraints.radial.names) ~= nRadial
    error('validate_config:radialNames', ...
        'constraints.radial.names の数（%d）を領域数（境界数+1 = %d）に合わせてください。', ...
        numel(cfg.constraints.radial.names), nRadial);
end
cfg.constraints.radial = validate_group(cfg.constraints.radial, nRadial, 'constraints.radial');
check_integer(cfg.constraints.scan.max_abs_difference, 0, 1000, 'constraints.scan.max_abs_difference');
cfg.constraints.scan.enabled = logical(cfg.constraints.scan.enabled);

% --- mandatory shots
cfg.mandatory.shot_ids = reshape(double(cfg.mandatory.shot_ids), 1, []);
if isempty(cfg.mandatory.positions_mm)
    cfg.mandatory.positions_mm = zeros(0, 2);
else
    cfg.mandatory.positions_mm = as_n_by_2(cfg.mandatory.positions_mm, 'mandatory.positions_mm');
end

% --- optimizer
cfg.optimizer.algorithm = check_choice(cfg.optimizer.algorithm, {'modified_fedorov'}, 'optimizer.algorithm');
check_integer(cfg.optimizer.n_starts, 1, 100000, 'optimizer.n_starts');
check_integer(cfg.optimizer.max_passes, 1, 100000, 'optimizer.max_passes');
check_range(cfg.optimizer.convergence_tolerance, 0, 1, 'optimizer.convergence_tolerance');
check_range(cfg.optimizer.ridge_epsilon, 0, 1, 'optimizer.ridge_epsilon');
check_range(cfg.optimizer.rank_tolerance, 0, 1, 'optimizer.rank_tolerance');
cfg.optimizer.i_eval_set = check_choice(cfg.optimizer.i_eval_set, ...
    {'dense_grid', 'all_valid_marks', 'candidate_marks'}, 'optimizer.i_eval_set');
check_positive(cfg.optimizer.i_eval_grid_spacing_mm, 'optimizer.i_eval_grid_spacing_mm');

% --- baselines
check_integer(cfg.random_sampling.n_draws, 1, 1e6, 'random_sampling.n_draws');
check_integer(cfg.random_sampling.max_redraws_per_draw, 1, 1e7, 'random_sampling.max_redraws_per_draw');
check_integer(cfg.poisson.n_starts, 1, 1e6, 'poisson.n_starts');
cfg.human.csv_path = char(cfg.human.csv_path);
cfg.human.include_center = logical(cfg.human.include_center);
cfg.human.ring_radii_norm = reshape(cfg.human.ring_radii_norm, 1, []);
cfg.human.ring_weight = check_choice(cfg.human.ring_weight, {'circumference', 'equal'}, 'human.ring_weight');

% --- Zernike
check_integer(cfg.zernike.max_radial_order, 0, 20, 'zernike.max_radial_order');
cfg.zernike.order_definition = check_choice(cfg.zernike.order_definition, ...
    {'radial_degree', 'fringe_group'}, 'zernike.order_definition');
check_integer(cfg.zernike.min_terms, 1, 1000, 'zernike.min_terms');
check_integer(cfg.zernike.max_terms, cfg.zernike.min_terms, 1000, 'zernike.max_terms');
cfg.zernike.coefficient_distribution = check_choice(cfg.zernike.coefficient_distribution, ...
    {'normal', 'uniform'}, 'zernike.coefficient_distribution');
check_range(cfg.zernike.sigma0_nm, 0, Inf, 'zernike.sigma0_nm');
check_range(cfg.zernike.alpha, 0, 10, 'zernike.alpha');
cfg.zernike.xy_mode = check_choice(cfg.zernike.xy_mode, {'independent', 'correlated'}, 'zernike.xy_mode');
check_range(cfg.zernike.xy_correlation, -1, 1, 'zernike.xy_correlation');
cfg.zernike.normalization.mode = check_choice(cfg.zernike.normalization.mode, ...
    {'none', 'target_rms', 'clip_range'}, 'zernike.normalization.mode');

% --- Monte Carlo, noise
check_integer(cfg.monte_carlo.n_wafers, 1, 1e7, 'monte_carlo.n_wafers');
cfg.scan_noise.model_a.amplitude_nm = as_xy(cfg.scan_noise.model_a.amplitude_nm, 'scan_noise.model_a.amplitude_nm');
cfg.scan_noise.model_b.amplitude_nm = as_xy(cfg.scan_noise.model_b.amplitude_nm, 'scan_noise.model_b.amplitude_nm');
cfg.scan_noise.model_b.terms = as_n_by_2(cfg.scan_noise.model_b.terms, 'scan_noise.model_b.terms');
cfg.scan_noise.model_c.sigma_up_nm = as_xy(cfg.scan_noise.model_c.sigma_up_nm, 'scan_noise.model_c.sigma_up_nm');
cfg.scan_noise.model_c.sigma_down_nm = as_xy(cfg.scan_noise.model_c.sigma_down_nm, 'scan_noise.model_c.sigma_down_nm');
levelNames = fieldnames(cfg.mark_noise.levels);
for k = 1:numel(levelNames)
    cfg.mark_noise.levels.(levelNames{k}) = as_xy(cfg.mark_noise.levels.(levelNames{k}), ...
        ['mark_noise.levels.' levelNames{k}]);
end

% --- conditions
if ~isstruct(cfg.conditions) || isempty(cfg.conditions)
    error('validate_config:conditions', 'conditions は1つ以上の {name, mark_noise_level, scan_scale} で指定してください。');
end
cfg.conditions = reshape(cfg.conditions, 1, []);
for k = 1:numel(cfg.conditions)
    cfg.conditions(k).name = char(cfg.conditions(k).name);
    cfg.conditions(k).mark_noise_level = char(cfg.conditions(k).mark_noise_level);
    if ~isfield(cfg.mark_noise.levels, cfg.conditions(k).mark_noise_level)
        error('validate_config:noiseLevel', 'conditions(%d).mark_noise_level "%s" が mark_noise.levels にありません。', ...
            k, cfg.conditions(k).mark_noise_level);
    end
    check_range(cfg.conditions(k).scan_scale, 0, Inf, 'conditions.scan_scale');
end
if numel(unique({cfg.conditions.name})) ~= numel(cfg.conditions)
    error('validate_config:conditionNames', 'conditions の name が重複しています。');
end

% --- soft 制約の補助評価（項目がなければ実行しない）
if ~isfield(cfg, 'soft_constraint_study')
    cfg.soft_constraint_study = struct('enabled', false, 'howa_orders', [], 'n_shots', [], 'weights', []);
end
cfg.soft_constraint_study.enabled = logical(cfg.soft_constraint_study.enabled);
cfg.soft_constraint_study.howa_orders = reshape(cfg.soft_constraint_study.howa_orders, 1, []);
cfg.soft_constraint_study.n_shots = reshape(cfg.soft_constraint_study.n_shots, 1, []);
cfg.soft_constraint_study.weights = reshape(cfg.soft_constraint_study.weights, 1, []);
if cfg.soft_constraint_study.enabled
    if ~all(ismember(cfg.soft_constraint_study.howa_orders, cfg.howa.orders))
        error('validate_config:softOrders', 'soft_constraint_study.howa_orders は howa.orders に含まれる次数にしてください。');
    end
    if ~any(cfg.soft_constraint_study.weights == 0) || any(cfg.soft_constraint_study.weights < 0)
        error('validate_config:softWeights', 'soft_constraint_study.weights は 0（基準）を含む非負の値にしてください。');
    end
end

% --- statistics, appendix, figures, output
check_range(cfg.statistics.confidence_level, 0.5, 0.9999, 'statistics.confidence_level');
check_integer(cfg.statistics.bootstrap_samples, 10, 1e6, 'statistics.bootstrap_samples');
cfg.statistics.bootstrap_median_conditions = cellstr(cfg.statistics.bootstrap_median_conditions);
cfg.statistics.proposed_methods.base = cellstr(cfg.statistics.proposed_methods.base);
cfg.statistics.proposed_methods.mandatory = cellstr(cfg.statistics.proposed_methods.mandatory);
cfg.statistics.reduction_reference_methods = cellstr(cfg.statistics.reduction_reference_methods);
cfg.appendix.scenario = check_choice(cfg.appendix.scenario, {'base', 'mandatory'}, 'appendix.scenario');
cfg.appendix.comparator_methods = cellstr(cfg.appendix.comparator_methods);
cfg.appendix.proposed_method = char(cfg.appendix.proposed_method);
cfg.figures.map_n_shots = reshape(cfg.figures.map_n_shots, 1, []);
cfg.output.wafer_csv_conditions = cellstr(cfg.output.wafer_csv_conditions);
cfg.parallel.enabled = logical(cfg.parallel.enabled);
cfg.evaluation.include_scan_in_truth = logical(cfg.evaluation.include_scan_in_truth);
end

% ======================================================================
function group = validate_group(group, nLevels, name)
group.enabled = logical(group.enabled);
group.bound_mode = check_choice(group.bound_mode, {'fraction', 'explicit'}, [name '.bound_mode']);
if ischar(group.target_fraction) || isstring(group.target_fraction)
    group.target_fraction = check_choice(group.target_fraction, {'proportional', 'equal'}, [name '.target_fraction']);
else
    group.target_fraction = reshape(double(group.target_fraction), [], 1);
    if numel(group.target_fraction) ~= nLevels || any(group.target_fraction < 0)
        error('validate_config:targetFraction', '%s.target_fraction は %d 個の非負の値で指定してください。', name, nLevels);
    end
    group.target_fraction = group.target_fraction / sum(group.target_fraction);
end
check_range(group.tolerance_fraction, 0, 1, [name '.tolerance_fraction']);
check_range(group.min_slack_shots, 0, 1000, [name '.min_slack_shots']);
group.explicit_lower = reshape(double(group.explicit_lower), [], 1);
group.explicit_upper = reshape(double(group.explicit_upper), [], 1);
if strcmp(group.bound_mode, 'explicit') && ...
        (numel(group.explicit_lower) ~= nLevels || numel(group.explicit_upper) ~= nLevels)
    error('validate_config:explicitBounds', '%s.explicit_lower / explicit_upper は %d 個ずつ指定してください。', name, nLevels);
end
end

function require_fields(s, names, label)
for k = 1:numel(names)
    if ~isfield(s, names{k})
        error('validate_config:missingField', '%s に項目 "%s" がありません。', label, names{k});
    end
end
end

function value = check_choice(value, choices, name)
value = char(value);
if ~any(strcmp(value, choices))
    error('validate_config:invalidChoice', '%s は %s のいずれかで指定してください（現在: %s）。', ...
        name, strjoin(choices, ' / '), value);
end
end

function check_positive(value, name)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
    error('validate_config:notPositive', '%s は正の数で指定してください。', name);
end
end

function check_range(value, lo, hi, name)
if ~isnumeric(value) || ~isscalar(value) || isnan(value) || value < lo || value > hi
    error('validate_config:outOfRange', '%s は %g 以上 %g 以下で指定してください。', name, lo, hi);
end
end

function check_integer(value, lo, hi, name)
if ~isnumeric(value) || ~isscalar(value) || value ~= round(value) || value < lo || value > hi
    error('validate_config:notInteger', '%s は %g 以上 %g 以下の整数で指定してください。', name, lo, hi);
end
end

function m = as_n_by_2(value, name)
value = double(value);
if isvector(value) && numel(value) == 2
    value = reshape(value, 1, 2);
end
if size(value, 2) ~= 2 || isempty(value)
    error('validate_config:notNby2', '%s は [[x, y], ...] の形で指定してください。', name);
end
m = value;
end

function v = as_xy(value, name)
value = double(value);
if isscalar(value)
    value = [value, value];
end
if numel(value) ~= 2 || any(value < 0)
    error('validate_config:notXY', '%s は [X, Y] の非負の2要素で指定してください。', name);
end
v = reshape(value, 1, 2);
end
