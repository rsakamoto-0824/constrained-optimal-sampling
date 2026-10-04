function X = howa_design_matrix(u, v, order)
%HOWA_DESIGN_MATRIX 正規化座標 (u, v) でのHOWA型多項式の説明変数行列（n行p列）を返す。
exponents = howa_exponents(order);
u = u(:);
v = v(:);
X = zeros(numel(u), size(exponents, 1));
for k = 1:size(exponents, 1)
    X(:, k) = u .^ exponents(k, 1) .* v .^ exponents(k, 2);
end
end
