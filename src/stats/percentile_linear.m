function q = percentile_linear(x, pct, isSorted)
%PERCENTILE_LINEAR 列ごとの百分位点（線形補間、Excel の PERCENTILE.INC と同じ定義）。
%   x : n 行 m 列（列ごとに計算）、pct : 0〜100（スカラーまたはベクトル）
%   isSorted = true なら x が列ごとに昇順済みとして並べ替えを省く。
%   Statistics Toolbox の prctile を使わないための自前実装（定義の違いに注意: prctile は既定で別方式）。
if nargin < 3 || ~isSorted
    x = sort(x, 1);
end
n = size(x, 1);
pct = pct(:);
q = zeros(numel(pct), size(x, 2));
for k = 1:numel(pct)
    h = (n - 1) * pct(k) / 100 + 1;
    lo = floor(h);
    hi = min(lo + 1, n);
    frac = h - lo;
    q(k, :) = x(lo, :) + frac * (x(hi, :) - x(lo, :));
end
end
