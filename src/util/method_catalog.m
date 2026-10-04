function catalog = method_catalog()
%METHOD_CATALOG 比較するsampling手法の一覧（キー・表示名・シナリオ・図の色と線種）。
%   scenario = base      : 強制計測shotなし（手法1〜7）
%   scenario = mandatory : 強制計測shotあり（手法8・9の拡張実験計画と、その比較対象）
% 色は色覚多様性に配慮して検証した4色相（D系=青、I系=紫、Human=橙、Poisson=青緑）と、
% 基準線として扱う Random の灰色。D/I の中では線種と記号で区別する
% （制約付き・拡張計画=実線・塗りつぶし、制約なし=破線・白抜き、素朴な方法=点線・白抜き）。
blue = [0.165 0.471 0.839];     % #2a78d6
violet = [0.290 0.227 0.655];   % #4a3aa7
orange = [0.922 0.408 0.204];   % #eb6834
aqua = [0.106 0.686 0.478];     % #1baf7a
gray = [0.420 0.420 0.404];     % #6b6b67
rows = {
  % key            label                         scenario     family      color   line  marker filled
  'random',        'Random',                     'base',      'baseline', gray,   '-',  'o',   false
  'poisson',       'Poisson Disk',               'base',      'baseline', aqua,   '-',  's',   false
  'human',         'Human',                      'base',      'baseline', orange, '-',  'd',   false
  'dopt',          'D-opt',                      'base',      'optimal',  blue,   '--', '^',   false
  'iopt',          'I-opt',                      'base',      'optimal',  violet, '--', 'v',   false
  'cdopt',         'Constrained D-opt',          'base',      'proposed', blue,   '-',  '^',   true
  'ciopt',         'Constrained I-opt',          'base',      'proposed', violet, '-',  'v',   true
  'random_f',      'Random + F',                 'mandatory', 'baseline', gray,   '-',  'o',   false
  'poisson_f',     'Poisson Disk + F',           'mandatory', 'baseline', aqua,   '-',  's',   false
  'human_f',       'Human + F',                  'mandatory', 'baseline', orange, '-',  'd',   false
  'dopt_aug',      'D-opt Aug. (unconstr.)',     'mandatory', 'optimal',  blue,   '--', '^',   false
  'iopt_aug',      'I-opt Aug. (unconstr.)',     'mandatory', 'optimal',  violet, '--', 'v',   false
  'cdopt_naive',   'Constr. D-opt Naive',        'mandatory', 'naive',    blue,   ':',  '>',   false
  'ciopt_naive',   'Constr. I-opt Naive',        'mandatory', 'naive',    violet, ':',  '<',   false
  'cdopt_aug',     'Constr. D-opt Augmentation', 'mandatory', 'proposed', blue,   '-',  '^',   true
  'ciopt_aug',     'Constr. I-opt Augmentation', 'mandatory', 'proposed', violet, '-',  'v',   true
};
catalog = cell2struct(rows, {'key', 'label', 'scenario', 'family', 'color', 'lineStyle', 'marker', 'filled'}, 2);
end
