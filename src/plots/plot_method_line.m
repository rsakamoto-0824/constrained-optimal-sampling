function h = plot_method_line(ax, x, y, methodKey, markerSize)
%PLOT_METHOD_LINE 手法の色・線種・記号で折れ線を描く（凡例名は手法の表示名）。
if nargin < 5
    markerSize = 3.5;
end
info = method_info(methodKey);
faceColor = 'w';
if info.filled
    faceColor = info.color;
end
h = plot(ax, x, y, 'LineStyle', info.lineStyle, 'Color', info.color, 'LineWidth', 1.1, ...
    'Marker', info.marker, 'MarkerSize', markerSize, 'MarkerFaceColor', faceColor, ...
    'MarkerEdgeColor', info.color, 'DisplayName', info.label);
end
