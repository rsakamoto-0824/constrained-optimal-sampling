function q = design_quality(design, model, groups, mandatory, rankTolerance, K)
%DESIGN_QUALITY 1つの設計（候補番号の集合）の最適性・coverage・制約違反をまとめて返す。
%   q.logdet      : log det(M)（正規直交化した基底。rank不足なら -Inf）
%   q.icrit       : 平均予測分散 trace(M^-1)（σ^2単位。rank不足なら Inf）
%   q.fullRank    : 説明変数行列が full rank か（最小/最大特異値 > rankTolerance）
%   q.svRatio     : 最小/最大特異値
%   q.counts      : 区分ごとのshot数（象限・半径領域・scan方向）
%   q.balanceQ/R/S: B_Q = max-min（象限）、B_R = max-min（半径領域）、B_S = |N_up - N_down|
%   q.violation*  : 各制約の上下限からのはみ出し（shot数）。mandatory は含まれていない強制shot数
design = design(:)';
rows = reshape((design - 1) * K + (1:K)', [], 1);
Xs = model.Xt(rows, :);
p = model.p;
s = svd(Xs);
if numel(s) < p || s(1) == 0
    q.svRatio = 0;
else
    q.svRatio = s(p) / s(1);
end
q.fullRank = q.svRatio > rankTolerance;
M = Xs' * Xs;
[R, flag] = chol(M);
if flag == 0 && q.fullRank
    q.logdet = 2 * sum(log(diag(R)));
    Rinv = R \ eye(p);
    q.icrit = sum(Rinv(:) .^ 2);
else
    q.logdet = -Inf;
    q.icrit = Inf;
end
q.counts = count_levels(design, groups);
q.balanceQ = max(q.counts{1}) - min(q.counts{1});
q.balanceR = max(q.counts{2}) - min(q.counts{2});
q.balanceS = abs(q.counts{3}(1) - q.counts{3}(2));
[~, perGroup] = constraint_violation(q.counts, groups, false);
q.violationQuadrant = perGroup(1);
q.violationRadial = perGroup(2);
q.violationScan = perGroup(3);
q.violationMandatory = sum(~ismember(mandatory, design));
q.nShots = numel(design);
end
