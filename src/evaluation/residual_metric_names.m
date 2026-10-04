function names = residual_metric_names()
%RESIDUAL_METRIC_NAMES waferごとの残差指標の列名（evaluate_design の出力列の順）。
names = {'rms_x_nm', 'rms_y_nm', 'rms_vec_nm', 'p95_mag_nm', 'p99_mag_nm', 'max_mag_nm', 'rms_vec_interior_nm'};
end
