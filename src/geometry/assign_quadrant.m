function quadrant = assign_quadrant(x, y)
%ASSIGN_QUADRANT shot中心の角度から象限番号（1〜4）を返す。
%   角度 θ = atan2(y, x) を [0, 360) 度に直し、[0,90)→1, [90,180)→2, [180,270)→3, [270,360)→4。
%   軸上のshotは反時計回り側の象限に入る。ウェーハ中心 (0,0) のshotは第1象限とする。
theta = mod(atan2(y, x), 2 * pi);
quadrant = floor(theta / (pi / 2)) + 1;
quadrant = min(max(quadrant, 1), 4);
end
