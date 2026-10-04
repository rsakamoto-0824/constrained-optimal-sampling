function [N, y] = metric_curve(T, condition, scenario, method, order, column)
%METRIC_CURVE 統計量の表 T から、1手法の shot数ごとの値を取り出す（shot数の昇順）。
rows = strcmp(T.condition, condition) & strcmp(T.scenario, scenario) & strcmp(T.method, method) ...
    & T.howa_order == order;
N = T.n_shots(rows);
y = T.(column)(rows);
[N, idx] = sort(N);
y = y(idx);
end
