function design = human_sampling(nShots, layout, fixed, humanCfg)
%HUMAN_SAMPLING 人手の配置を模擬したルールベースのsampling（最適化は使わない）。
%   ルール
%     1. 強制計測shot fixed を含める。include_center が true ならウェーハ中心に最も近いshotも含める
%     2. 残りを同心円 ring_radii_norm の上に配る。配分は円周長に比例（ring_weight = circumference）
%        または等分（equal）。外側の円から端数を割り当てる
%     3. 各円の上に等角度で目標点を置く（外側の円は angle_offset_deg から、内側の円は半ピッチずらす）
%        → 4象限に概ね均等、見た目も均等になる
%     4. 目標点ごとに、まだ選んでいない最寄りの候補shotを選ぶ
fixed = fixed(:)';
cand = layout.cand;
design = fixed;
if humanCfg.include_center && numel(design) < nShots
    [~, center] = min(hypot(cand.x_mm, cand.y_mm));
    design = unique([design, center], 'stable');
end
nRest = nShots - numel(design);
if nRest < 0
    error('human_sampling:tooManyFixed', '強制計測shot数が計測shot数を超えています。');
end
radii = humanCfg.ring_radii_norm * layout.normRadius;
nRings = numel(radii);
if strcmp(humanCfg.ring_weight, 'circumference')
    weights = radii / sum(radii);
else
    weights = ones(1, nRings) / nRings;
end
perRing = floor(nRest * weights);
remainder = nRest - sum(perRing);
for k = 0:remainder - 1
    ring = nRings - mod(k, nRings);          % 外側の円から端数を割り当てる
    perRing(ring) = perRing(ring) + 1;
end
used = false(height(cand), 1);
used(design) = true;
for ring = nRings:-1:1
    n = perRing(ring);
    if n == 0
        continue
    end
    offset = humanCfg.angle_offset_deg;
    if mod(nRings - ring, 2) == 1
        offset = offset + 180 / n;           % 内側の円は外側と互い違いにする
    end
    angles = deg2rad(offset + (0:n - 1) * 360 / n);
    for a = angles
        tx = radii(ring) * cos(a);
        ty = radii(ring) * sin(a);
        distance = hypot(cand.x_mm - tx, cand.y_mm - ty);
        distance(used) = Inf;
        [~, pick] = min(distance);
        design(end + 1) = pick; %#ok<AGROW>
        used(pick) = true;
    end
end
design = sort(design);
end
