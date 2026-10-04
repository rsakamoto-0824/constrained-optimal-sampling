function make_figures(results)
%MAKE_FIGURES 評価結果から本文用の図をすべて作る（results/figures/ に PNG で保存）。
%   results は run_study の返り値、または study_results.mat を読み込んだ構造体、
%   または結果フォルダのパス（study_results.mat を読み込む）。
if ischar(results) || isstring(results)
    results = load(fullfile(char(results), 'study_results.mat'));
end
figDir = fullfile(results.outDir, 'figures');
ensure_folder(figDir);
dpi = results.cfg.figures.dpi;

fig_layout_overview(results, figDir, dpi);
fig_sampling_maps(results, figDir, dpi);
for scenario = {'base', 'mandatory'}
    fig_rms_vs_shots(results, scenario{1}, figDir, dpi);
    fig_tail_vs_shots(results, scenario{1}, figDir, dpi);
    fig_distributions(results, scenario{1}, figDir, dpi);
    fig_efficiency(results, scenario{1}, figDir, dpi);
    fig_coverage(results, scenario{1}, figDir, dpi);
    fig_paired_differences(results, scenario{1}, figDir, dpi);
    fig_robustness(results, scenario{1}, figDir, dpi);
    fig_shot_reduction(results, scenario{1}, figDir, dpi);
end
fig_tradeoff(results, figDir, dpi);
fig_augmentation(results, figDir, dpi);
fig_optimization_time(results, figDir, dpi);
fig_soft_constraint(results, figDir, dpi);
end
