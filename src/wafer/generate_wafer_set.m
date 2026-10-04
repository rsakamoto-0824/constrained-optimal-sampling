function ws = generate_wafer_set(cfg, layout)
%GENERATE_WAFER_SET 比較する全手法で共通に使う N_wafer 枚分の真値・scan成分・mark誤差を作る。
%   すべて評価点（全shotのusable領域内のmark）上で作り、候補shotのmarkはその一部として使う。
%   ws.truthX/Y : 真の面内傾向（Fringe Zernike）[nm]、評価点数 x N_wafer
%   ws.scanX/Y  : scan方向依存成分（Model A+B+C、倍率1）[nm]
%   ws.noiseX/Y : mark計測誤差の標準正規乱数（条件ごとに sigma_mark を掛けて使う）
%   ws.coefX/Y  : Zernike係数（項数 x N_wafer、選ばれなかった項は0、正規化後の値）
%   ws.fingerprint : 全手法で同じ realization を使ったことを確認するための指紋
nW = cfg.monte_carlo.n_wafers;
zc = cfg.zernike;
terms = fringe_zernike_terms(zc.max_radial_order, zc.order_definition);
nTerms = height(terms);
if zc.max_terms > nTerms
    error('generate_wafer_set:tooManyTerms', 'zernike.max_terms（%d）が候補の項数（%d）を超えています。', zc.max_terms, nTerms);
end
ep = layout.evalPoints;
Zeval = zernike_basis(ep.x_mm, ep.y_mm, layout.waferRadius, terms);
sigmaTerm = zc.sigma0_nm ./ max(terms.n, 1) .^ zc.alpha;

% --- 1. Fringe Zernike による真の面内傾向
zStream = make_stream(cfg.study.master_seed, 'wafer|zernike');
coefX = zeros(nTerms, nW);
coefY = zeros(nTerms, nW);
nSelX = zeros(1, nW);
nSelY = zeros(1, nW);
for w = 1:nW
    [selX, aX] = draw_terms(zStream, nTerms, zc, sigmaTerm);
    if strcmp(zc.xy_mode, 'correlated')
        selY = selX;
        [~, aIndep] = draw_coefficients(zStream, selY, zc, sigmaTerm);
        rho = zc.xy_correlation;
        aY = rho * aX + sqrt(1 - rho^2) * aIndep;
    else
        [selY, aY] = draw_terms(zStream, nTerms, zc, sigmaTerm);
    end
    coefX(selX, w) = aX;
    coefY(selY, w) = aY;
    nSelX(w) = numel(selX);
    nSelY(w) = numel(selY);
end
rawRmsX = sqrt(mean((Zeval * coefX) .^ 2, 1));
rawRmsY = sqrt(mean((Zeval * coefY) .^ 2, 1));
scaleX = normalization_scale(rawRmsX, zc.normalization);
scaleY = normalization_scale(rawRmsY, zc.normalization);
coefX = coefX .* scaleX;
coefY = coefY .* scaleY;
truthX = Zeval * coefX;
truthY = Zeval * coefY;

% --- 2. scan方向依存成分（Up: +1、Down: -1）
sStream = make_stream(cfg.study.master_seed, 'wafer|scan');
sc = cfg.scan_noise;
s = ep.scan_sign;
nE = height(ep);
scanA = zeros(nE, nW, 2);
scanB = zeros(nE, nW, 2);
scanC = zeros(nE, nW, 2);
offsetA = sc.model_a.amplitude_nm' .* (1 + sc.model_a.wafer_variation_fraction * randn(sStream, 2, nW));
nB = size(sc.model_b.terms, 1);
coefB = randn(sStream, nB, nW, 2) .* reshape(sc.model_b.amplitude_nm, 1, 1, 2);
basisB = zeros(nE, nB);
for k = 1:nB
    basisB(:, k) = ep.u .^ sc.model_b.terms(k, 1) .* ep.v .^ sc.model_b.terms(k, 2);
end
nAllShots = height(layout.shots);
shotNoise = randn(sStream, nAllShots, nW, 2);
[~, shotRow] = ismember(ep.shot_id, layout.shots.shot_id);
for c = 1:2
    if sc.model_a.enabled
        scanA(:, :, c) = s .* offsetA(c, :);
    end
    if sc.model_b.enabled
        scanB(:, :, c) = s .* (basisB * coefB(:, :, c));
    end
    if sc.model_c.enabled
        sigmaShot = sc.model_c.sigma_up_nm(c) * (s > 0) + sc.model_c.sigma_down_nm(c) * (s < 0);
        scanC(:, :, c) = sigmaShot .* shotNoise(shotRow, :, c);
    end
end
scanTotal = scanA + scanB + scanC;

% --- 3. mark計測誤差（標準正規、条件ごとに sigma_mark 倍する）
nStream = make_stream(cfg.study.master_seed, 'wafer|mark_noise');
noiseX = randn(nStream, nE, nW);
noiseY = randn(nStream, nE, nW);

ws.nWafers = nW;
ws.terms = terms;
ws.coefX = coefX;
ws.coefY = coefY;
ws.truthX = truthX;
ws.truthY = truthY;
ws.scanX = scanTotal(:, :, 1);
ws.scanY = scanTotal(:, :, 2);
ws.noiseX = noiseX;
ws.noiseY = noiseY;
ws.summary = table((1:nW)', nSelX', nSelY', rawRmsX', rawRmsY', scaleX', scaleY', ...
    sqrt(mean(truthX .^ 2, 1))', sqrt(mean(truthY .^ 2, 1))', ...
    offsetA(1, :)', offsetA(2, :)', ...
    sqrt(mean(scanA(:, :, 1) .^ 2, 1))', sqrt(mean(scanB(:, :, 1) .^ 2, 1))', sqrt(mean(scanC(:, :, 1) .^ 2, 1))', ...
    sqrt(mean(scanA(:, :, 2) .^ 2, 1))', sqrt(mean(scanB(:, :, 2) .^ 2, 1))', sqrt(mean(scanC(:, :, 2) .^ 2, 1))', ...
    'VariableNames', {'wafer_id', 'n_terms_x', 'n_terms_y', 'raw_rms_x_nm', 'raw_rms_y_nm', ...
    'scale_x', 'scale_y', 'truth_rms_x_nm', 'truth_rms_y_nm', 'scan_a_offset_x_nm', 'scan_a_offset_y_nm', ...
    'scan_a_rms_x_nm', 'scan_b_rms_x_nm', 'scan_c_rms_x_nm', 'scan_a_rms_y_nm', 'scan_b_rms_y_nm', 'scan_c_rms_y_nm'});
ws.fingerprint = wafer_fingerprint(ws);
end

% ======================================================================
function [sel, a] = draw_terms(stream, nTerms, zc, sigmaTerm)
nSel = randi(stream, [zc.min_terms, zc.max_terms]);
sel = sort(randperm(stream, nTerms, nSel))';
[~, a] = draw_coefficients(stream, sel, zc, sigmaTerm);
end

function [sel, a] = draw_coefficients(stream, sel, zc, sigmaTerm)
sigma = sigmaTerm(sel);
switch zc.coefficient_distribution
    case 'normal'
        a = sigma .* randn(stream, numel(sel), 1);
    case 'uniform'
        % 標準偏差が sigma になる一様分布 U(-sqrt(3)σ, sqrt(3)σ)
        a = sigma .* sqrt(3) .* (2 * rand(stream, numel(sel), 1) - 1);
end
end

function scale = normalization_scale(rms, normCfg)
scale = ones(size(rms));
switch normCfg.mode
    case 'none'
    case 'target_rms'
        scale = normCfg.target_rms_nm ./ max(rms, eps);
    case 'clip_range'
        low = rms < normCfg.min_rms_nm;
        high = rms > normCfg.max_rms_nm;
        scale(low) = normCfg.min_rms_nm ./ max(rms(low), eps);
        scale(high) = normCfg.max_rms_nm ./ rms(high);
end
end
