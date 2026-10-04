function result = optimize_design(problem, opts, stream)
%OPTIMIZE_DESIGN shot単位の modified Fedorov 交換法（multi-start）でD/I最適設計を求める。
%
%   problem の項目
%     info        : 候補shotごとの情報行列（p x p x Ncand）
%     criterion   : 'D' または 'I'
%     nFree       : 交換で選ぶshot数（= 最終shot数 - 固定shot数）
%     fixed       : 必ず含め、評価値にも数える候補番号（強制計測shotの拡張計画）
%     pool        : 交換で選んでよい候補（Ncand x 1 の論理値）
%     groups      : 象限・半径領域・scan方向の区分と上下限（build_constraint_groups）
%     countOffset : 評価値には数えないが制約の数には入れるshot数（区分ごと、cell）
%     mode        : 'hard'（制約を満たす交換だけ）/ 'soft'（はみ出しに罰則）/ 'none'
%     softWeight  : soft のときの罰則の重み（はみ出し1 shotあたり）
%   opts の項目: nStarts, maxPasses, tolerance, ridge
%                initialFree（省略可）: 指定した初期解（cell）だけから探索する（nStarts は使わない）
%
%   アルゴリズム（Cook & Nachtsheim の modified Fedorov 交換）
%     1. 初期解を作る（hard なら上下限を満たす解）
%     2. 設計内の各shot i（固定shotは除く）について、設計外の候補 j と入れ替えたときの評価値を
%        すべて計算し、最も良くなる j と入れ替える（改善しなければそのまま）
%     3. 1巡しても改善がなければ終了。これを nStarts 回の初期解で繰り返し、最良の解を返す
%   評価値は探索中だけ ridge を足した情報行列で計算する（rank不足の初期解からでも探索できるように）。

t0 = tic;
p = size(problem.info, 1);
if isempty(problem.fixed)
    baseM = zeros(p);
else
    baseM = sum(problem.info(:, :, problem.fixed), 3);
end

givenStarts = isfield(opts, 'initialFree') && ~isempty(opts.initialFree);
if givenStarts
    nStarts = numel(opts.initialFree);
else
    nStarts = opts.nStarts;
end
bestScore = -Inf;
bestFree = [];
scores = -Inf(1, nStarts);
passesUsed = zeros(1, nStarts);
for s = 1:nStarts
    if givenStarts
        free = opts.initialFree{s};
    else
        free = initial_design(problem, stream);
    end
    if isempty(free) && problem.nFree > 0
        continue
    end
    [free, score, nPass] = exchange(problem, free, baseM, opts, stream);
    scores(s) = score;
    passesUsed(s) = nPass;
    if score > bestScore
        bestScore = score;
        bestFree = free;
    end
end

result.feasible = ~isempty(bestFree) || problem.nFree == 0;
result.free = sort(bestFree);
result.design = sort([problem.fixed(:)', result.free(:)']);
result.score = bestScore;
result.startScores = scores;
result.passesUsed = passesUsed;
% 局所解依存性の目安: 最良値とほぼ同じ値に到達した初期解の割合
result.fractionStartsAtBest = mean(abs(scores - bestScore) <= 1e-6 * max(1, abs(bestScore)));
result.timeSeconds = toc(t0);
end

% ======================================================================
function [free, cur, nPass] = exchange(problem, free, baseM, opts, stream)
info = problem.info;
nCand = size(info, 3);
groups = problem.groups;
isHard = strcmp(problem.mode, 'hard');
isSoft = strcmp(problem.mode, 'soft');

inDesign = false(nCand, 1);
inDesign(problem.fixed) = true;
inDesign(free) = true;
M = baseM + sum(info(:, :, free), 3);
counts = count_levels([problem.fixed(:)', free(:)'], groups, problem.countOffset);
cur = criterion_score(M, problem.criterion, opts.ridge) - soft_penalty(isSoft, problem, counts);

nFree = numel(free);
nPass = 0;
for pass = 1:opts.maxPasses
    nPass = pass;
    improved = false;
    for pos = randperm(stream, nFree)
        i = free(pos);
        Mi = M - info(:, :, i);
        js = find(problem.pool & ~inDesign);
        if isHard
            js = js(swap_feasible(i, js, counts, groups));
        end
        if isempty(js)
            continue
        end
        penalties = zeros(numel(js), 1);
        if isSoft
            penalties = problem.softWeight * swap_violation(i, js, counts, groups);
        end
        bestScore = cur;
        bestJ = 0;
        threshold = opts.tolerance * max(1, abs(cur));
        for t = 1:numel(js)
            j = js(t);
            score = criterion_score(Mi + info(:, :, j), problem.criterion, opts.ridge) - penalties(t);
            if score > bestScore + threshold
                bestScore = score;
                bestJ = j;
            end
        end
        if bestJ > 0
            free(pos) = bestJ;
            inDesign(i) = false;
            inDesign(bestJ) = true;
            M = Mi + info(:, :, bestJ);
            counts = move_counts(counts, groups, i, bestJ);
            cur = bestScore;
            improved = true;
        end
    end
    if ~improved
        break
    end
end
end

function penalty = soft_penalty(isSoft, problem, counts)
penalty = 0;
if isSoft
    penalty = problem.softWeight * constraint_violation(counts, problem.groups);
end
end

function counts = move_counts(counts, groups, removed, added)
for g = 1:numel(groups)
    counts{g}(groups(g).labels(removed)) = counts{g}(groups(g).labels(removed)) - 1;
    counts{g}(groups(g).labels(added)) = counts{g}(groups(g).labels(added)) + 1;
end
end

function ok = swap_feasible(i, js, counts, groups)
% i を外して j を入れた後も、有効な区分すべてで上下限を満たすか（js ごとの論理値）
ok = true(numel(js), 1);
for g = 1:numel(groups)
    if ~groups(g).enabled
        continue
    end
    labels = groups(g).labels;
    c = counts{g};
    li = labels(i);
    c(li) = c(li) - 1;
    lj = labels(js);
    ok = ok & (c(lj) + 1 <= groups(g).upper(lj));
    ok = ok & (c(li) + (lj == li) >= groups(g).lower(li));
end
end

function violation = swap_violation(i, js, counts, groups)
% i を外して j を入れた後のはみ出しshot数（js ごと）
violation = zeros(numel(js), 1);
for g = 1:numel(groups)
    if ~groups(g).enabled
        continue
    end
    labels = groups(g).labels;
    lower = groups(g).lower;
    upper = groups(g).upper;
    c = counts{g};
    c(labels(i)) = c(labels(i)) - 1;
    base = max(0, lower - c) + max(0, c - upper);
    lj = labels(js);
    % j の区分だけ数が1増える
    before = base(lj);
    after = max(0, lower(lj) - (c(lj) + 1)) + max(0, (c(lj) + 1) - upper(lj));
    violation = violation + sum(base) - before + after;
end
end
