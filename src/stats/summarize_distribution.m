function s = summarize_distribution(x)
%SUMMARIZE_DISTRIBUTION 列ごとの Monte Carlo 統計量（平均・中央値・標準偏差・P90・P95・P99・最悪値）。
%   NaN を含む列は NaN を返す（rank不足などで評価できなかった設計）。
s.mean = mean(x, 1);
s.median = percentile_linear(x, 50);
s.std = std(x, 0, 1);
q = percentile_linear(x, [90, 95, 99]);
s.p90 = q(1, :);
s.p95 = q(2, :);
s.p99 = q(3, :);
s.worst = max(x, [], 1);
bad = any(isnan(x), 1);
for f = fieldnames(s)'
    s.(f{1})(bad) = NaN;
end
end
