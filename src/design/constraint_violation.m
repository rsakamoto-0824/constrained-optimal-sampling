function [total, perGroup] = constraint_violation(counts, groups, onlyEnabled)
%CONSTRAINT_VIOLATION 区分ごとの上下限からのはみ出し（shot数）を合計する。
%   はみ出し = Σ max(0, L - n) + max(0, n - U)。0 なら制約を満たしている。
if nargin < 3
    onlyEnabled = true;
end
perGroup = zeros(1, numel(groups));
for g = 1:numel(groups)
    if onlyEnabled && ~groups(g).enabled
        continue
    end
    n = counts{g};
    perGroup(g) = sum(max(0, groups(g).lower - n)) + sum(max(0, n - groups(g).upper));
end
total = sum(perGroup);
end
