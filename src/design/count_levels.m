function counts = count_levels(design, groups, countOffset)
%COUNT_LEVELS 設計（候補番号の集合）に含まれるshot数を区分ごとに数える。
%   counts{g} は groups(g) の区分ごとのshot数（nLevels x 1）。
%   countOffset{g} があれば加える（最適化の外で固定されたshotの分）。
counts = cell(1, numel(groups));
for g = 1:numel(groups)
    labels = groups(g).labels(design);
    counts{g} = accumarray(labels(:), 1, [groups(g).nLevels, 1]);
    if nargin >= 3 && ~isempty(countOffset)
        counts{g} = counts{g} + countOffset{g};
    end
end
end
