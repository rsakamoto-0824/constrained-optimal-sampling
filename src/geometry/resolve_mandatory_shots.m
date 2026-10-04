function candIdx = resolve_mandatory_shots(layout, mandatoryCfg)
%RESOLVE_MANDATORY_SHOTS 強制計測shotを候補番号（layout.cand の行番号）で返す。
%   shot_ids が指定されていればそれを使い、空なら positions_mm に最も近い候補shotを使う。
if ~isempty(mandatoryCfg.shot_ids)
    candIdx = zeros(1, numel(mandatoryCfg.shot_ids));
    for k = 1:numel(mandatoryCfg.shot_ids)
        hit = find(layout.cand.shot_id == mandatoryCfg.shot_ids(k), 1);
        if isempty(hit)
            error('resolve_mandatory_shots:notCandidate', ...
                '強制計測shot ID %d は候補shotではありません（partial shot または範囲外）。', mandatoryCfg.shot_ids(k));
        end
        candIdx(k) = hit;
    end
else
    positions = mandatoryCfg.positions_mm;
    candIdx = zeros(1, size(positions, 1));
    for k = 1:size(positions, 1)
        distance = hypot(layout.cand.x_mm - positions(k, 1), layout.cand.y_mm - positions(k, 2));
        [~, candIdx(k)] = min(distance);
    end
end
if numel(unique(candIdx)) ~= numel(candIdx)
    error('resolve_mandatory_shots:duplicate', '強制計測shotが重複しています。位置またはIDを見直してください。');
end
candIdx = sort(candIdx);
end
