function nList = build_sweep(nMin, nMax, sweepCfg)
%BUILD_SWEEP 計測shot数のスイープ値（N_min 〜 nMax）を作る。
%   full     : step 刻み
%   adaptive : adaptive_fine_until までは step 刻み、それより上は adaptive_coarse_step 刻み（nMax は必ず含める）
if nMax < nMin
    nList = zeros(1, 0);
    return
end
switch sweepCfg.mode
    case 'full'
        nList = nMin:sweepCfg.step:nMax;
    case 'adaptive'
        fine = nMin:sweepCfg.step:min(nMax, sweepCfg.adaptive_fine_until);
        if isempty(fine)
            start = nMin;
        else
            start = fine(end) + sweepCfg.adaptive_coarse_step;
        end
        nList = [fine, start:sweepCfg.adaptive_coarse_step:nMax];
end
if nList(end) ~= nMax
    nList(end + 1) = nMax;
end
nList = unique(nList);
end
