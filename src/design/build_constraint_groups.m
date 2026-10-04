function groups = build_constraint_groups(nShots, layout, constraintCfg)
%BUILD_CONSTRAINT_GROUPS 計測shot数 nShots に対する象限・半径領域・scan方向の整数上下限を作る。
%   groups(g).name    : 'quadrant' / 'radial' / 'scan'
%   groups(g).labels  : 候補shotごとの区分番号（Ncand x 1）
%   groups(g).lower, groups(g).upper : 区分ごとの下限・上限（shot数、最終設計全体に対する値）
%   groups(g).enabled : false の区分は最適化では使わず、coverage指標の計算だけに使う
%
%   割合（fraction）方式: 区分の目標割合 f と許容幅 w = max(tolerance*N, min_slack) から
%     L = floor(N*f - w), U = ceil(N*f + w) とし、候補shot数で上限を切る。
%   scan方向: |N_up - N_down| <= δ を N_up, N_down それぞれの上下限に直す。

nCand = layout.nCand;
groups = struct('name', {}, 'labels', {}, 'nLevels', {}, 'lower', {}, 'upper', {}, 'enabled', {}, 'levelNames', {});

groups(1).name = 'quadrant';
groups(1).labels = layout.cand.quadrant;
groups(1).nLevels = 4;
groups(1).levelNames = {'Q1', 'Q2', 'Q3', 'Q4'};
[groups(1).lower, groups(1).upper] = fraction_bounds(nShots, groups(1).labels, 4, constraintCfg.quadrant);
groups(1).enabled = constraintCfg.quadrant.enabled;

nRadial = numel(layout.radialNames);
groups(2).name = 'radial';
groups(2).labels = layout.cand.radial_region;
groups(2).nLevels = nRadial;
groups(2).levelNames = layout.radialNames;
[groups(2).lower, groups(2).upper] = fraction_bounds(nShots, groups(2).labels, nRadial, constraintCfg.radial);
groups(2).enabled = constraintCfg.radial.enabled;

delta = constraintCfg.scan.max_abs_difference;
scanLabels = 1 + (layout.cand.scan_sign < 0);   % 1 = Up, 2 = Down
available = accumarray(scanLabels, 1, [2, 1]);
groups(3).name = 'scan';
groups(3).labels = scanLabels;
groups(3).nLevels = 2;
groups(3).levelNames = {'Up', 'Down'};
groups(3).lower = max(0, ceil((nShots - delta) / 2)) * ones(2, 1);
groups(3).upper = min(available, floor((nShots + delta) / 2) * ones(2, 1));
groups(3).enabled = constraintCfg.scan.enabled;

for g = 1:numel(groups)
    if numel(groups(g).labels) ~= nCand
        error('build_constraint_groups:labels', '区分ラベルの数が候補shot数と一致しません。');
    end
end
end

function [lower, upper] = fraction_bounds(nShots, labels, nLevels, groupCfg)
available = accumarray(labels(:), 1, [nLevels, 1]);
if strcmp(groupCfg.bound_mode, 'explicit')
    lower = groupCfg.explicit_lower;
    upper = min(groupCfg.explicit_upper, available);
    return
end
if ischar(groupCfg.target_fraction)
    if strcmp(groupCfg.target_fraction, 'proportional')
        fraction = available / sum(available);
    else
        fraction = ones(nLevels, 1) / nLevels;
    end
else
    fraction = groupCfg.target_fraction;
end
width = max(groupCfg.tolerance_fraction * nShots, groupCfg.min_slack_shots);
% 1e-9 は浮動小数の丸めで floor/ceil が1つずれないための余裕
lower = max(0, floor(nShots * fraction - width + 1e-9));
upper = min(available, ceil(nShots * fraction + width - 1e-9));
end
