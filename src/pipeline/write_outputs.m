function files = write_outputs(outDir, cfg, layout, mandatory, designs, randomSets, nminTable, ...
    designMetrics, randomDesignSummary, ws, ev, st, logFile)
%WRITE_OUTPUTS 評価結果をCSV（Spotfire入力を想定した縦長・横長の表）に書き出す。
csvDir = fullfile(outDir, 'csv');
ensure_folder(csvDir);
files = {};

% --- 1. shot候補（全shot、partial shotの区別つき）
shots = layout.shots;
shots.is_mandatory = false(height(shots), 1);
shots.is_mandatory(ismember(shots.shot_id, layout.cand.shot_id(mandatory))) = true;
shots.radial_region_name = strings(height(shots), 1);
shots.radial_region_name(:) = string(layout.radialNames(shots.radial_region));
shots.is_partial = ~shots.is_candidate;
files{end + 1} = write_table(shots, csvDir, 'shot_candidates.csv');

% --- 2. 評価点（全有効mark）
files{end + 1} = write_table(layout.evalPoints, csvDir, 'evaluation_points.csv');

% --- 3. N_min と制約の上下限
files{end + 1} = write_table(nminTable, csvDir, 'nmin.csv');
boundRows = {};
for N = unique([designs.nShots])
    groups = build_constraint_groups(N, layout, cfg.constraints);
    for g = 1:numel(groups)
        for lv = 1:groups(g).nLevels
            boundRows(end + 1, :) = {N, groups(g).name, groups(g).levelNames{lv}, ...
                sum(groups(g).labels == lv), groups(g).lower(lv), groups(g).upper(lv), groups(g).enabled}; %#ok<AGROW>
        end
    end
end
files{end + 1} = write_table(cell2table(boundRows, 'VariableNames', {'n_shots', 'constraint', 'level', ...
    'n_candidates', 'lower', 'upper', 'enabled'}), csvDir, 'constraint_bounds.csv');

% --- 4. 選ばれたshot（手法・次数・shot数ごと、縦長）
selRows = {};
for r = 1:numel(designs)
    rec = designs(r);
    for c = rec.design(:)'
        selRows(end + 1, :) = {rec.id, rec.scenario, rec.method, rec.order, rec.nShots, rec.drawIndex, ...
            layout.cand.shot_id(c), c, layout.cand.x_mm(c), layout.cand.y_mm(c), layout.cand.quadrant(c), ...
            layout.radialNames{layout.cand.radial_region(c)}, char(layout.cand.scan_direction(c)), ...
            any(mandatory == c) && strcmp(rec.scenario, 'mandatory')}; %#ok<AGROW>
    end
end
files{end + 1} = write_table(cell2table(selRows, 'VariableNames', {'design_id', 'scenario', 'method', ...
    'howa_order', 'n_shots', 'random_draw_index', 'shot_id', 'cand_index', 'x_mm', 'y_mm', 'quadrant', ...
    'radial_region', 'scan_direction', 'is_mandatory'}), csvDir, 'selected_shots.csv');

% --- 5. 設計の指標（D/I efficiency・coverage・制約違反・計算時間）
health = ev.fitHealth;
designMetrics.cond_estimate = health.cond_estimate;
designMetrics.max_abs_coef_nm = health.max_abs_coef_nm;
files{end + 1} = write_table(designMetrics, csvDir, 'design_metrics.csv');
files{end + 1} = write_table(randomDesignSummary, csvDir, 'random_draw_design_summary.csv');
files{end + 1} = write_table(ev.randomSummary, csvDir, 'random_draw_residual_summary.csv');

% --- 6. waferごとの結果（条件・シナリオ・HOWA次数ごとにファイルを分ける）
metricNames = ev.metricNames;
for c = 1:numel(ev.conditionNames)
    if isempty(ev.full{c}) || ~any(strcmp(ev.conditionNames{c}, cfg.output.wafer_csv_conditions))
        continue
    end
    for sc = {'base', 'mandatory'}
        for order = cfg.howa.orders
            idx = find(strcmp({designs.scenario}, sc{1}) & [designs.order] == order & [designs.feasible]);
            if isempty(idx)
                continue
            end
            nW = ws.nWafers;
            nRows = nW * numel(idx);
            methodCol = strings(nRows, 1);
            nShotsCol = zeros(nRows, 1);
            designCol = zeros(nRows, 1);
            waferCol = zeros(nRows, 1);
            values = zeros(nRows, numel(metricNames));
            for k = 1:numel(idx)
                rows = (k - 1) * nW + (1:nW);
                methodCol(rows) = designs(idx(k)).method;
                nShotsCol(rows) = designs(idx(k)).nShots;
                designCol(rows) = designs(idx(k)).id;
                waferCol(rows) = (1:nW)';
                values(rows, :) = ev.full{c}(:, :, idx(k));
            end
            T = table(repmat(string(ev.conditionNames{c}), nRows, 1), repmat(string(sc{1}), nRows, 1), ...
                methodCol, repmat(order, nRows, 1), nShotsCol, designCol, waferCol, ...
                'VariableNames', {'condition', 'scenario', 'method', 'howa_order', 'n_shots', 'design_id', 'wafer_id'});
            T = [T, array2table(round(values, 5), 'VariableNames', metricNames)]; %#ok<AGROW>
            name = sprintf('wafer_results_%s_%s_howa%d.csv', ev.conditionNames{c}, sc{1}, order);
            files{end + 1} = write_table(T, csvDir, name); %#ok<AGROW>
        end
    end
end

% --- 7. 統計量・paired comparison・shot削減
files{end + 1} = write_table(st.aggregated, csvDir, 'aggregated_metrics.csv');
files{end + 1} = write_table(st.paired, csvDir, 'paired_comparison.csv');
files{end + 1} = write_table(st.reduction, csvDir, 'shot_reduction.csv');

% --- 8. wafer生成の情報
files{end + 1} = write_table(ws.summary, csvDir, 'wafer_truth_summary.csv');
files{end + 1} = write_table(ws.terms, csvDir, 'zernike_terms.csv');
coefRows = {};
for w = 1:ws.nWafers
    for comp = {'x', 'y'}
        coef = ws.(['coef' upper(comp{1})])(:, w);
        for t = find(coef ~= 0)'
            coefRows(end + 1, :) = {w, comp{1}, ws.terms.fringe(t), ws.terms.n(t), ws.terms.m(t), coef(t)}; %#ok<AGROW>
        end
    end
end
files{end + 1} = write_table(cell2table(coefRows, 'VariableNames', {'wafer_id', 'component', ...
    'fringe_index', 'n', 'm', 'coefficient_nm'}), csvDir, 'zernike_coefficients.csv');
log_message(logFile, 'CSV を %d 個書き出しました（%s）', numel(files), csvDir);
end

function path = write_table(T, folder, name)
path = fullfile(folder, name);
writetable(T, path);
end
