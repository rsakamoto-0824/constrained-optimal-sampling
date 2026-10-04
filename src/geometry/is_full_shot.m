function tf = is_full_shot(centerX, centerY, shotWidth, shotHeight, markOffsets, usableRadius)
%IS_FULL_SHOT partial shotでない（候補にできる）shotかどうかを判定する。
%   判定条件（両方を満たすときだけ true）
%     1. shot矩形の4隅がすべて usable 領域（半径 < usableRadius）の内側にある
%        円は凸なので、4隅が内側なら矩形全体が内側にある。
%     2. shotに属するalignment markがすべて usable 領域の内側にある
%   centerX, centerY : shot中心 [mm]（同じ大きさの配列でよい）
%   markOffsets      : shot中心基準のmark位置 [mm]（K行2列）
if ~isequal(size(centerX), size(centerY))
    error('is_full_shot:sizeMismatch', 'centerX と centerY の大きさをそろえてください。');
end
tf = true(size(centerX));
halfW = shotWidth / 2;
halfH = shotHeight / 2;
cornerOffsets = [-halfW, -halfH; halfW, -halfH; halfW, halfH; -halfW, halfH];
allOffsets = [cornerOffsets; markOffsets];
for k = 1:size(allOffsets, 1)
    r = hypot(centerX + allOffsets(k, 1), centerY + allOffsets(k, 2));
    tf = tf & (r < usableRadius);
end
end
