function region = assign_radial_region(rNorm, boundaries)
%ASSIGN_RADIAL_REGION 正規化半径から半径方向の領域番号（1 = 最も内側）を返す。
%   boundaries = [b1 b2 ...] のとき r < b1 → 1、b1 <= r < b2 → 2、…
region = ones(size(rNorm));
for k = 1:numel(boundaries)
    region(rNorm >= boundaries(k)) = k + 1;
end
end
