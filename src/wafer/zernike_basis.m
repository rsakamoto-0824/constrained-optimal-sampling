function Z = zernike_basis(x, y, normRadius, terms)
%ZERNIKE_BASIS 点 (x, y) [mm] での Fringe Zernike 多項式（非正規化、端で最大1）の値を返す。
%   ρ = r / normRadius、θ = atan2(y, x)。Z は 点数 x 項数。
rho = hypot(x(:), y(:)) / normRadius;
theta = atan2(y(:), x(:));
Z = zeros(numel(rho), height(terms));
for k = 1:height(terms)
    n = terms.n(k);
    m = terms.m(k);
    radial = zernike_radial(n, abs(m), rho);
    if m > 0
        Z(:, k) = radial .* cos(m * theta);
    elseif m < 0
        Z(:, k) = radial .* sin(-m * theta);
    else
        Z(:, k) = radial;
    end
end
end

function R = zernike_radial(n, m, rho)
R = zeros(size(rho));
for s = 0:(n - m) / 2
    c = (-1)^s * factorial(n - s) / (factorial(s) * factorial((n + m) / 2 - s) * factorial((n - m) / 2 - s));
    R = R + c * rho .^ (n - 2 * s);
end
end
