function style_axes(ax)
%STYLE_AXES 軸を控えめに整える（薄いグリッド、外向きの目盛りなし）。
set(ax, 'Box', 'off', 'TickDir', 'out', 'LineWidth', 0.6, 'XColor', [0.25 0.25 0.25], ...
    'YColor', [0.25 0.25 0.25], 'GridColor', [0.85 0.85 0.85], 'GridAlpha', 1, ...
    'MinorGridColor', [0.92 0.92 0.92], 'MinorGridAlpha', 1);
grid(ax, 'on');
end
