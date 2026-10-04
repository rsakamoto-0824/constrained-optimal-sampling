function score = criterion_score(M, criterion, ridge)
%CRITERION_SCORE 情報行列 M の最適性を「大きいほど良い」値で返す。
%   criterion = 'D' : log det(M)            （D最適: 最大化）
%   criterion = 'I' : -log(trace(M^-1))     （I最適: 平均予測分散 trace(M^-1) の最小化）
%   M は I最適の評価点で正規直交化した基底の情報行列なので、trace(M^-1) が平均予測分散（σ^2単位）。
%   行列式は直接計算せず Cholesky 分解 M = R'R から log det = 2 Σ log diag(R) で求める。
%   ridge > 0 なら M + ridge*I で計算する（探索中にrank不足の設計を比較できるようにするため）。
%   Cholesky分解できない（正定値でない）ときは -Inf。
p = size(M, 1);
if ridge > 0
    M = M + ridge * eye(p);
end
[R, flag] = chol(M);
if flag ~= 0
    score = -Inf;
    return
end
switch criterion
    case 'D'
        score = 2 * sum(log(diag(R)));
    case 'I'
        Rinv = R \ eye(p);
        score = -log(sum(Rinv(:) .^ 2));   % trace(M^-1) = ||R^-1||_F^2
    otherwise
        error('criterion_score:unknown', '未対応の基準です: %s（D または I）', criterion);
end
end
