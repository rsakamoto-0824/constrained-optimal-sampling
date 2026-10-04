function plot_sampling_map(ax, layout, design, mandatory, methodKey, titleText, background)
%PLOT_SAMPLING_MAP 1つの sampling 設計を wafer map 上に描く。
%   全候補shot（灰色の枠）、選んだshot（手法の色で塗る）、強制計測shot（黒の太枠＋★）、
%   象限境界（実線）、半径領域境界（緑の破線）、scan方向（▲Up / ▼Down）を表示する。
%   background（省略可）: 背景に描く値の構造体（x, y, value, clim）。Appendix で真値の大きさを薄く描く
if nargin >= 7 && ~isempty(background)
    draw_background(ax, background);
end
plot_wafer_frame(ax, layout, struct('showScan', true));
info = method_info(methodKey);
halfW = layout.shotWidth / 2;
halfH = layout.shotHeight / 2;
for c = design(:)'
    x = layout.cand.x_mm(c) + [-halfW, halfW, halfW, -halfW];
    y = layout.cand.y_mm(c) + [-halfH, -halfH, halfH, halfH];
    patch(ax, x, y, info.color, 'FaceAlpha', 0.65, 'EdgeColor', info.color * 0.6, 'LineWidth', 0.6);
    if layout.cand.scan_sign(c) > 0
        marker = '^';
    else
        marker = 'v';
    end
    plot(ax, layout.cand.x_mm(c), layout.cand.y_mm(c) - 9, marker, 'MarkerSize', 2.6, ...
        'Color', 'k', 'MarkerFaceColor', 'k');
end
for c = mandatory(:)'
    x = layout.cand.x_mm(c) + [-halfW, halfW, halfW, -halfW, -halfW];
    y = layout.cand.y_mm(c) + [-halfH, -halfH, halfH, halfH, -halfH];
    plot(ax, x, y, 'k-', 'LineWidth', 1.6);
    plot(ax, layout.cand.x_mm(c), layout.cand.y_mm(c) + 5, 'p', 'MarkerSize', 6, ...
        'MarkerFaceColor', 'y', 'MarkerEdgeColor', 'k');
end
title(ax, titleText, 'FontWeight', 'normal', 'Interpreter', 'none');
end

function draw_background(ax, bg)
hold(ax, 'on');
h = imagesc(ax, bg.x, bg.y, bg.value);
set(h, 'AlphaData', 0.55 * ~isnan(bg.value));
set(ax, 'YDir', 'normal');
colormap(ax, bg.colormap);
caxis(ax, bg.clim);
end
