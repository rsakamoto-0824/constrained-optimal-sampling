function fig = new_figure(widthCm, heightCm)
%NEW_FIGURE 画面に出さない図を、指定サイズ（cm）・白背景・Arialで作る。
fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'centimeters', ...
    'Position', [1, 1, widthCm, heightCm]);
set(fig, 'DefaultAxesFontName', 'Arial', 'DefaultTextFontName', 'Arial', ...
    'DefaultAxesFontSize', 8, 'DefaultTextFontSize', 8, 'DefaultLegendFontSize', 7);
end
