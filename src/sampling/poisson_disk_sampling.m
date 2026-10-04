function [design, info] = poisson_disk_sampling(nShots, xy, fixed, nStarts, stream)
%POISSON_DISK_SAMPLING 候補shot中心に対する離散Poisson disk samplingで nShots 個を選ぶ。
%   1. 乱数で候補の並び順を決め、その順に「選んだ点すべてから距離 d 以上なら採用」を繰り返す
%      （強制計測shot fixed は最初に無条件で採用する）
%   2. 採用数が nShots 以上となる最大の d を二分探索で求める（距離の候補はshot間距離の値）
%   3. 採用数が nShots を超えたら、最近接距離が最も小さい点（fixed以外）から外して nShots にそろえる
%   4. これを nStarts 個の乱数初期値で行い、選んだ点どうしの最小距離が最大の解を代表解にする
%   info.minDistance : 代表解の最小点間距離 [mm]、info.startMinDistance : 各初期値の値
fixed = fixed(:)';
nCand = size(xy, 1);
if nShots > nCand || nShots < numel(fixed)
    error('poisson_disk_sampling:badCount', '計測shot数が候補数または強制計測shot数と合いません。');
end
D = hypot(xy(:, 1) - xy(:, 1)', xy(:, 2) - xy(:, 2)');
distances = unique(D(triu(true(nCand), 1)));
distances = [0; distances(:)];

bestMin = -Inf;
design = [];
startMin = zeros(1, nStarts);
for s = 1:nStarts
    rest = setdiff(1:nCand, fixed);
    order = [fixed, rest(randperm(stream, numel(rest)))];
    % 採用数は d について単調ではないので、条件を満たす最大の d を二分探索で近似的に求める
    lo = 1;
    hi = numel(distances);
    while lo < hi
        mid = ceil((lo + hi) / 2);
        if numel(dart_throw(order, D, distances(mid), numel(fixed))) >= nShots
            lo = mid;
        else
            hi = mid - 1;
        end
    end
    accepted = dart_throw(order, D, distances(lo), numel(fixed));
    if numel(accepted) < nShots
        accepted = order(1:nShots);   % d = 0 相当（全点採用）からの打ち切り
    end
    accepted = trim_to_count(accepted, D, fixed, nShots);
    sub = D(accepted, accepted);
    sub(logical(eye(numel(accepted)))) = Inf;
    startMin(s) = min(sub(:));
    if startMin(s) > bestMin
        bestMin = startMin(s);
        design = sort(accepted);
    end
end
info.minDistance = bestMin;
info.startMinDistance = startMin;
end

function accepted = dart_throw(order, D, minDist, nFixed)
accepted = order(1:nFixed);
for k = nFixed + 1:numel(order)
    c = order(k);
    if isempty(accepted) || all(D(c, accepted) >= minDist)
        accepted(end + 1) = c; %#ok<AGROW>
    end
end
end

function accepted = trim_to_count(accepted, D, fixed, nShots)
while numel(accepted) > nShots
    sub = D(accepted, accepted);
    sub(logical(eye(numel(accepted)))) = Inf;
    nearest = min(sub, [], 2);
    nearest(ismember(accepted, fixed)) = Inf;
    [~, worst] = min(nearest);
    accepted(worst) = [];
end
end
