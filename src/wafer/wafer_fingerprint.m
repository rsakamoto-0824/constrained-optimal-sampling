function fp = wafer_fingerprint(ws)
%WAFER_FINGERPRINT wafer realization（真値・scan成分・mark誤差）から決まる指紋（数値ベクトル）。
%   全手法の評価で同じ値になることを確認し、paired comparison であることを保証する。
weights = (1:numel(ws.truthX))';
weights = 1 + mod(weights, 997) / 997;
fp = [sum(ws.truthX(:) .* weights), sum(ws.truthY(:) .* weights), ...
      sum(ws.scanX(:) .* weights), sum(ws.scanY(:) .* weights), ...
      sum(ws.noiseX(:) .* weights), sum(ws.noiseY(:) .* weights)];
end
