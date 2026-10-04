function exponents = howa_exponents(order)
%HOWA_EXPONENTS 総次数 order 以下の2変数単項式 u^i v^j の指数 [i j] を返す（p行2列）。
%   並び: 1; u, v; u^2, uv, v^2; u^3, u^2 v, u v^2, v^3; ...
%   項数 p = (order+1)(order+2)/2（3次: 10、4次: 15、5次: 21）。
if ~isscalar(order) || order < 0 || order ~= round(order)
    error('howa_exponents:invalidOrder', 'HOWA次数は0以上の整数で指定してください。');
end
p = (order + 1) * (order + 2) / 2;
exponents = zeros(p, 2);
k = 0;
for degree = 0:order
    for i = degree:-1:0
        k = k + 1;
        exponents(k, :) = [i, degree - i];
    end
end
end
