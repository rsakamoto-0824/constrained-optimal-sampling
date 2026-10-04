function [designs, nRejected] = random_sampling(nShots, nCand, fixed, nDraws, maxRedraws, stream, isValid)
%RANDOM_SAMPLING 制約なしのランダム抽選を nDraws 回行う（強制計測shot fixed は必ず含める）。
%   designs   : nDraws 行 nShots 列（各行が1回の抽選の候補番号、昇順）
%   nRejected : rank不足などで isValid が false になり、やり直した回数の合計
%   isValid   : 設計（候補番号の行ベクトル）を受け取り、使える設計なら true を返す関数
fixed = fixed(:)';
nFree = nShots - numel(fixed);
if nFree < 0
    error('random_sampling:tooManyFixed', '強制計測shot数が計測shot数を超えています。');
end
pool = setdiff(1:nCand, fixed);
designs = zeros(nDraws, nShots);
nRejected = 0;
for d = 1:nDraws
    accepted = false;
    for attempt = 1:maxRedraws
        pick = pool(randperm(stream, numel(pool), nFree));
        design = sort([fixed, pick]);
        if isValid(design)
            accepted = true;
            break
        end
        nRejected = nRejected + 1;
    end
    if ~accepted
        error('random_sampling:noValidDraw', ...
            '%d 回抽選しても使える設計が得られませんでした（shot数 %d）。', maxRedraws, nShots);
    end
    designs(d, :) = design;
end
end
