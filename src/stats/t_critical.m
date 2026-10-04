function t = t_critical(confidenceLevel, df)
%T_CRITICAL 両側信頼区間に使う t 分布の分位点（Statistics Toolbox の tinv を使わない実装）。
%   P(|T| <= t) = confidenceLevel となる t。不完全ベータ関数の逆関数から求める。
alpha = 1 - confidenceLevel;
x = betaincinv(alpha, df / 2, 0.5);
t = sqrt(df * (1 / x - 1));
end
