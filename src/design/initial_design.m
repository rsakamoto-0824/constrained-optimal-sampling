function free = initial_design(problem, stream)
%INITIAL_DESIGN 交換アルゴリズムの初期解（固定shot以外に選ぶ nFree 個の候補番号）を作る。
%   hard 制約のとき: 下限に足りない区分を優先しながら1つずつ選び、上下限を満たす初期解を作る。
%                    作れなかったときは [] を返す（その shot 数では制約を満たせない可能性が高い）。
%   none / soft のとき: 選べる候補から一様ランダムに選ぶ。

MAX_ATTEMPTS = 200;
nFree = problem.nFree;
if nFree == 0
    free = zeros(1, 0);
    return
end
poolIdx = find(problem.pool);
if numel(poolIdx) < nFree
    free = [];
    return
end
if ~strcmp(problem.mode, 'hard')
    free = poolIdx(randperm(stream, numel(poolIdx), nFree))';
    return
end

groups = problem.groups;
nGroups = numel(groups);
baseCounts = count_levels(problem.fixed, groups, problem.countOffset);
for attempt = 1:MAX_ATTEMPTS
    counts = baseCounts;
    available = problem.pool;
    free = zeros(1, nFree);
    failed = false;
    for t = 1:nFree
        slotsAfter = nFree - t;
        cand = find(available);
        ok = true(numel(cand), 1);
        priority = zeros(numel(cand), 1);
        for g = 1:nGroups
            if ~groups(g).enabled
                continue
            end
            lab = groups(g).labels(cand);
            c = counts{g};
            ok = ok & (c(lab) + 1 <= groups(g).upper(lab));
            deficit = max(0, groups(g).lower - c);
            reduces = deficit(lab) > 0;
            % 追加後に残る不足数が、残りの枠で埋められる範囲であること
            ok = ok & (sum(deficit) - reduces <= slotsAfter);
            priority = priority + reduces;
        end
        cand = cand(ok);
        priority = priority(ok);
        if isempty(cand)
            failed = true;
            break
        end
        best = cand(priority == max(priority));
        pick = best(randi(stream, numel(best)));
        free(t) = pick;
        available(pick) = false;
        for g = 1:nGroups
            lab = groups(g).labels(pick);
            counts{g}(lab) = counts{g}(lab) + 1;
        end
    end
    if ~failed && constraint_violation(counts, groups) == 0
        return
    end
end
free = [];
end
