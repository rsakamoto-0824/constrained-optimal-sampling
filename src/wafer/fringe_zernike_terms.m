function terms = fringe_zernike_terms(maxOrder, definition)
%FRINGE_ZERNIKE_TERMS 対象とするFringe Zernike項の一覧（Fringe番号の昇順）を返す。
%   terms.fringe : Fringe番号 j = (1 + (n+|m|)/2)^2 - 2|m| + (m<0)
%   terms.n, terms.m : 動径次数 n と方位次数 m（m>0: cos、m<0: sin、m=0: 回転対称）
%   definition = 'radial_degree' : n <= maxOrder（7次なら36項）
%   definition = 'fringe_group'  : (n+|m|)/2 <= maxOrder
%   注: Z1〜Z36 は一般的な Fringe（University of Arizona）番号と一致する。Z37以降は
%       上の式をそのまま延長した番号で、37項版Fringeの Z37（n=12, m=0）とは異なる。
switch definition
    case 'radial_degree'
        nMax = maxOrder;
    case 'fringe_group'
        nMax = 2 * maxOrder;
    otherwise
        error('fringe_zernike_terms:definition', '未対応の order_definition です: %s', definition);
end
list = zeros(0, 3);
for n = 0:nMax
    for m = -n:2:n
        if strcmp(definition, 'fringe_group') && (n + abs(m)) / 2 > maxOrder
            continue
        end
        j = (1 + (n + abs(m)) / 2)^2 - 2 * abs(m) + (m < 0);
        list(end + 1, :) = [j, n, m]; %#ok<AGROW>
    end
end
list = sortrows(list, 1);
terms = table(list(:, 1), list(:, 2), list(:, 3), 'VariableNames', {'fringe', 'n', 'm'});
end
