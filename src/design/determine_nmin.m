function info = determine_nmin(model, nCand, K, opts, rankTolerance, stream)
%DETERMINE_NMIN full rank の設計が存在する最小shot数 N_min を、制約なしD最適で探して決める。
%   4 marks x N >= p（項数）が必要条件。N = ceil(p/K) から1つずつ増やし、
%   multi-start のD最適交換で full rank の設計が見つかった最初の N を N_min とする。
p = model.p;
lowerBound = ceil(p / K);
info.order = model.order;
info.p = p;
info.lowerBound = lowerBound;
info.nMin = NaN;
info.svRatio = NaN;
for n = lowerBound:nCand
    problem = struct('info', model.info, 'criterion', 'D', 'nFree', n, 'fixed', zeros(1, 0), ...
        'pool', true(nCand, 1), 'groups', struct('name', {}, 'labels', {}, 'nLevels', {}, ...
        'lower', {}, 'upper', {}, 'enabled', {}, 'levelNames', {}), 'countOffset', {{}}, ...
        'mode', 'none', 'softWeight', 0);
    result = optimize_design(problem, opts, stream);
    rows = reshape((result.design - 1) * K + (1:K)', [], 1);
    s = svd(model.Xt(rows, :));
    ratio = 0;
    if numel(s) >= p && s(1) > 0
        ratio = s(p) / s(1);
    end
    if ratio > rankTolerance
        info.nMin = n;
        info.svRatio = ratio;
        return
    end
end
error('determine_nmin:notFound', 'HOWA %d次で full rank の設計が見つかりませんでした。', model.order);
end
