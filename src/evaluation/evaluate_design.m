function [metrics, fit] = evaluate_design(design, model, layout, ws, sigmaXY, scanScale, includeScanInTruth, rmsOnly, fastCache)
%EVALUATE_DESIGN 1つのsampling設計を全waferに適用し、HOWA補正後の残差指標をwaferごとに返す。
%   手順: 選んだshotの全markの計測値（真値＋scan成分＋mark誤差）でHOWA多項式をOLS推定し、
%         全評価点に補正を展開して、真の面内傾向（noise-free）との差を残差とする。
%   metrics : N_wafer 行 7 列（residual_metric_names の順）。rmsOnly = true なら rms_vec 以外は NaN
%   fit     : 推定の健全性（説明変数行列の条件数、係数の最大絶対値、rank判定）
%   fastCache（省略可、rmsOnly のときだけ使う）: build_fast_rms_cache の結果。
%     残差の2乗和を Σ(t - Fc)^2 = t't - 2c'F't + c'F'Fc で求め、評価点ごとの残差を作らずに済ませる
%     （Random の大量の抽選を評価するときの高速化。結果は通常の計算と丸め誤差の範囲で一致する）
if nargin < 8
    rmsOnly = false;
end
if nargin < 9
    fastCache = [];
end
K = layout.nMarksPerShot;
design = design(:)';
candRows = reshape((design - 1) * K + (1:K)', [], 1);
evalRows = reshape(layout.candMarkRows(design, :)', [], 1);
X = model.Fcand(candRows, :);
nW = ws.nWafers;
measX = ws.truthX(evalRows, :) + scanScale * ws.scanX(evalRows, :) + sigmaXY(1) * ws.noiseX(evalRows, :);
measY = ws.truthY(evalRows, :) + scanScale * ws.scanY(evalRows, :) + sigmaXY(2) * ws.noiseY(evalRows, :);

[Q, R] = qr(X, 0);
diagR = abs(diag(R));
fit.condEstimate = max(diagR) / max(min(diagR), realmin);
fit.fullRank = size(X, 1) >= size(X, 2) && min(diagR) > 1e-12 * max(diagR);
if ~fit.fullRank
    metrics = NaN(nW, 7);
    fit.maxAbsCoef = NaN;
    return
end
coef = R \ (Q' * [measX, measY]);
fit.maxAbsCoef = max(abs(coef(:)));
if rmsOnly && ~isempty(fastCache) && ~includeScanInTruth
    cX = coef(:, 1:nW);
    cY = coef(:, nW + 1:end);
    sumSq = fastCache.ttX - 2 * sum(cX .* fastCache.FtX, 1) + sum(cX .* (fastCache.G * cX), 1) ...
          + fastCache.ttY - 2 * sum(cY .* fastCache.FtY, 1) + sum(cY .* (fastCache.G * cY), 1);
    metrics = NaN(nW, 7);
    metrics(:, 3) = sqrt(max(sumSq, 0) / fastCache.nEval)';
    return
end
pred = model.Feval * coef;
truthX = ws.truthX;
truthY = ws.truthY;
if includeScanInTruth
    truthX = truthX + scanScale * ws.scanX;
    truthY = truthY + scanScale * ws.scanY;
end
ex = truthX - pred(:, 1:nW);
ey = truthY - pred(:, nW + 1:end);
sq = ex .^ 2 + ey .^ 2;
metrics = NaN(nW, 7);
metrics(:, 3) = sqrt(mean(sq, 1))';
if rmsOnly
    return
end
metrics(:, 1) = sqrt(mean(ex .^ 2, 1))';
metrics(:, 2) = sqrt(mean(ey .^ 2, 1))';
magSorted = sort(sqrt(sq), 1);
tail = percentile_linear(magSorted, [95, 99], true);
metrics(:, 4) = tail(1, :)';
metrics(:, 5) = tail(2, :)';
metrics(:, 6) = magSorted(end, :)';
interior = layout.evalPoints.is_candidate_mark;
metrics(:, 7) = sqrt(mean(sq(interior, :), 1))';
end
