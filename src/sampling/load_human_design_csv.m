function plans = load_human_design_csv(csvPath, layout)
%LOAD_HUMAN_DESIGN_CSV 人手で決めたsampling配置をCSVから読み込む。
%   CSVの列: n_shots（その配置の計測shot数）, shot_id（選ぶshotのID）
%   返り値: containers.Map（キー = shot数、値 = 候補番号の行ベクトル）
if ~isfile(csvPath)
    error('load_human_design_csv:notFound', 'Human samplingのCSVが見つかりません: %s', csvPath);
end
T = readtable(csvPath);
if ~all(ismember({'n_shots', 'shot_id'}, T.Properties.VariableNames))
    error('load_human_design_csv:columns', 'Human samplingのCSVには列 n_shots, shot_id が必要です。');
end
plans = containers.Map('KeyType', 'double', 'ValueType', 'any');
for n = unique(T.n_shots)'
    ids = T.shot_id(T.n_shots == n);
    candIdx = zeros(1, numel(ids));
    for k = 1:numel(ids)
        hit = find(layout.cand.shot_id == ids(k), 1);
        if isempty(hit)
            error('load_human_design_csv:notCandidate', 'shot_id %d は候補shotではありません（n_shots = %d）。', ids(k), n);
        end
        candIdx(k) = hit;
    end
    if numel(unique(candIdx)) ~= n
        error('load_human_design_csv:count', 'n_shots = %d の行数（重複を除く）が %d と一致しません。', n, n);
    end
    plans(n) = sort(candIdx);
end
end
