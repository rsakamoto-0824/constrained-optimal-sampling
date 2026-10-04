function s = paired_difference_stats(rmsComparator, rmsProposed, bootIdx, confidenceLevel, withMedianBoot)
%PAIRED_DIFFERENCE_STATS waferごとの対応のある差 ΔRMS = RMS_比較法 - RMS_提案法 の統計。
%   ΔRMS > 0 なら提案法の方が残差が小さい（良い）。
%   s.meanDelta, s.medianDelta, s.stdDelta : ΔRMS の平均・中央値・標準偏差 [nm]
%   s.ciLow/ciHigh         : 平均 ΔRMS の t 信頼区間
%   s.bootMeanLow/High     : 平均 ΔRMS の bootstrap 百分位信頼区間（waferを復元抽出）
%   s.bootMedianLow/High   : 中央値 ΔRMS の bootstrap 百分位信頼区間（withMedianBoot のときだけ）
%   s.winRate              : 提案法の方が小さいwaferの割合
%   s.meanImprovementPct   : waferごとの改善率 (RMS_比較 - RMS_提案)/RMS_比較×100 の平均
%   s.medianImprovementPct : 同じく中央値
%   s.improvementOfMeansPct: 平均RMSどうしの改善率
%   s.bootImprovementLow/High: waferごとの改善率の平均の bootstrap 百分位信頼区間
d = rmsComparator(:) - rmsProposed(:);
n = numel(d);
s.n = n;
if any(isnan(d))
    s = nan_result(n);
    return
end
s.meanDelta = mean(d);
s.medianDelta = percentile_linear(d, 50);
s.stdDelta = std(d);
halfWidth = t_critical(confidenceLevel, n - 1) * s.stdDelta / sqrt(n);
s.ciLow = s.meanDelta - halfWidth;
s.ciHigh = s.meanDelta + halfWidth;
tailPct = 100 * [(1 - confidenceLevel) / 2, 1 - (1 - confidenceLevel) / 2];
bootMeans = mean(d(bootIdx), 1);
q = percentile_linear(bootMeans', tailPct);
s.bootMeanLow = q(1);
s.bootMeanHigh = q(2);
s.bootMedianLow = NaN;
s.bootMedianHigh = NaN;
if withMedianBoot
    bootMedians = percentile_linear(d(bootIdx), 50);
    q = percentile_linear(bootMedians', tailPct);
    s.bootMedianLow = q(1);
    s.bootMedianHigh = q(2);
end
s.winRate = mean(d > 0);
improvement = 100 * d ./ rmsComparator(:);
s.meanImprovementPct = mean(improvement);
q = percentile_linear(mean(improvement(bootIdx), 1)', tailPct);
s.bootImprovementLow = q(1);
s.bootImprovementHigh = q(2);
s.medianImprovementPct = percentile_linear(improvement, 50);
s.improvementOfMeansPct = 100 * (mean(rmsComparator) - mean(rmsProposed)) / mean(rmsComparator);
end

function s = nan_result(n)
s.n = n;
names = {'meanDelta', 'medianDelta', 'stdDelta', 'ciLow', 'ciHigh', 'bootMeanLow', 'bootMeanHigh', ...
    'bootMedianLow', 'bootMedianHigh', 'winRate', 'meanImprovementPct', 'medianImprovementPct', 'improvementOfMeansPct', ...
    'bootImprovementLow', 'bootImprovementHigh'};
for k = 1:numel(names)
    s.(names{k}) = NaN;
end
end
