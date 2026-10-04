function T = model_mismatch_floor(models, ws)
%MODEL_MISMATCH_FLOOR 計測誤差なし・全評価点を使ったときのHOWA補正残差（モデル不一致の下限）。
%   真値は Fringe Zernike（7次まで）なので、HOWA多項式では表せない成分が残る。
%   どの sampling でもこれより小さくはならない目安として、waferごとの vector RMS を返す。
nW = ws.nWafers;
T = table((1:nW)', 'VariableNames', {'wafer_id'});
for k = 1:numel(models)
    F = models(k).Feval;
    ex = ws.truthX - F * (F \ ws.truthX);
    ey = ws.truthY - F * (F \ ws.truthY);
    T.(sprintf('floor_rms_vec_howa%d_nm', models(k).order)) = sqrt(mean(ex .^ 2 + ey .^ 2, 1))';
end
end
