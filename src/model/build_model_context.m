function models = build_model_context(layout, cfg)
%BUILD_MODEL_CONTEXT HOWA次数ごとに、設計と評価で使う行列をまとめて作る。
%   models(k).order     : HOWA次数
%   models(k).p         : 項数
%   models(k).Fcand     : 候補shotのmark位置での説明変数（Ncand*K 行、候補shot順・mark順）
%   models(k).Xt        : Fcand を正規直交化した基底で表したもの（設計の評価に使う）
%   models(k).Feval     : 評価点（全有効mark）での説明変数
%   models(k).info      : 候補shotごとの情報行列（p x p x Ncand、I最適の評価点で正規直交化した基底）
%   models(k).Rortho    : 正規直交化に使った上三角行列（Fortho = F / Rortho）
%
%   正規直交化の理由: 単項式のままだと5次で情報行列の条件数が大きくなる。
%   I最適の評価点集合 E で平均 (1/|E|) Σ f f' = I となる基底に直すと、
%   I基準（平均予測分散）は trace(M^-1) になり、D基準・予測値は基底の取り方によらない。

K = layout.nMarksPerShot;
candRows = reshape(layout.candMarkRows', [], 1);      % 候補shot順・mark順の評価点行番号
uCand = layout.evalPoints.u(candRows);
vCand = layout.evalPoints.v(candRows);
[uI, vI] = i_eval_points(layout, cfg.optimizer.i_eval_set, candRows);

orders = cfg.howa.orders;
models = struct('order', {}, 'p', {}, 'Fcand', {}, 'Xt', {}, 'Feval', {}, 'info', {}, ...
    'Rortho', {}, 'nIEval', {}, 'labels', {});
for k = 1:numel(orders)
    m = orders(k);
    FI = howa_design_matrix(uI, vI, m);
    nI = size(FI, 1);
    [~, Rortho] = qr(FI / sqrt(nI), 0);
    Fcand = howa_design_matrix(uCand, vCand, m);
    Xt = Fcand / Rortho;
    p = size(Fcand, 2);
    info = zeros(p, p, layout.nCand);
    for c = 1:layout.nCand
        rows = (c - 1) * K + (1:K);
        info(:, :, c) = Xt(rows, :)' * Xt(rows, :);
    end
    models(k).order = m;
    models(k).p = p;
    models(k).Fcand = Fcand;
    models(k).Xt = Xt;
    models(k).Feval = howa_design_matrix(layout.evalPoints.u, layout.evalPoints.v, m);
    models(k).info = info;
    models(k).Rortho = Rortho;
    models(k).nIEval = nI;
    models(k).labels = howa_term_labels(m);
end
end

function [u, v] = i_eval_points(layout, setName, candRows)
switch setName
    case 'dense_grid'
        u = layout.denseGrid.u;
        v = layout.denseGrid.v;
    case 'all_valid_marks'
        u = layout.evalPoints.u;
        v = layout.evalPoints.v;
    case 'candidate_marks'
        u = layout.evalPoints.u(candRows);
        v = layout.evalPoints.v(candRows);
    otherwise
        error('build_model_context:iEvalSet', '未対応の optimizer.i_eval_set です: %s', setName);
end
end
