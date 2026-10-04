function save_figure(fig, filePath, dpi)
%SAVE_FIGURE 図をPNGで保存して閉じる（ベクターPDFは環境によりフォントが欠けるためPNGにする）。
ensure_folder(fileparts(filePath));
set(fig, 'PaperPositionMode', 'auto');
print(fig, filePath, '-dpng', sprintf('-r%d', dpi));
close(fig);
end
