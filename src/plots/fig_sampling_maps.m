function fig_sampling_maps(results, figDir, dpi)
%FIG_SAMPLING_MAPS 手法ごとの sampling map（HOWA次数 × 図示するshot数ごと）。
cfg = results.cfg;
designs = results.designs;
for scenario = {'base', 'mandatory'}
    methods = scenario_methods(scenario{1});
    for order = cfg.howa.orders
        for N = cfg.figures.map_n_shots
            idx = zeros(1, numel(methods));
            for k = 1:numel(methods)
                hit = find(strcmp({designs.scenario}, scenario{1}) & strcmp({designs.method}, methods{k}) ...
                    & [designs.order] == order & [designs.nShots] == N & [designs.feasible], 1);
                if ~isempty(hit)
                    idx(k) = hit;
                end
            end
            if all(idx == 0)
                continue
            end
            name = sprintf('fig02_sampling_map_%s_howa%d_N%d.png', scenario{1}, order, N);
            draw_map_grid(results, idx, methods, scenario{1}, ...
                sprintf('Sampling maps: %s scenario, HOWA %d, N = %d shots', scenario{1}, order, N), ...
                fullfile(figDir, name), dpi, []);
        end
    end
end
end
