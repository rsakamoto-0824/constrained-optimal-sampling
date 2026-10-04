function scanSign = assign_scan_direction(col, row, shotIds, scanCfg)
%ASSIGN_SCAN_DIRECTION 各shotのscan方向を +1（Up）/ -1（Down）で返す。
%   alternate_column : 隣り合う列で Up/Down が交互（列番号 0 の列が first_direction）
%   alternate_row    : 隣り合う行で交互
%   checkerboard     : 列と行の両方で交互
%   all_up           : すべて first_direction
%   csv              : scanCfg.csv_path の列 shot_id, scan_direction（Up/Down）を使う
firstSign = 1;
if strcmp(scanCfg.first_direction, 'Down')
    firstSign = -1;
end
switch scanCfg.assignment
    case 'alternate_column'
        parity = mod(col, 2);
    case 'alternate_row'
        parity = mod(row, 2);
    case 'checkerboard'
        parity = mod(col + row, 2);
    case 'all_up'
        parity = zeros(size(col));
    case 'csv'
        scanSign = read_scan_csv(scanCfg.csv_path, shotIds);
        return
    otherwise
        error('assign_scan_direction:unknown', '未対応の scan.assignment です: %s', scanCfg.assignment);
end
scanSign = firstSign * (1 - 2 * parity);
end

function scanSign = read_scan_csv(csvPath, shotIds)
if ~isfile(csvPath)
    error('assign_scan_direction:csvNotFound', 'scan方向のCSVが見つかりません: %s', csvPath);
end
T = readtable(csvPath, 'TextType', 'string');
if ~all(ismember({'shot_id', 'scan_direction'}, T.Properties.VariableNames))
    error('assign_scan_direction:csvColumns', 'scan方向のCSVには列 shot_id, scan_direction が必要です。');
end
scanSign = zeros(size(shotIds));
for k = 1:numel(shotIds)
    hit = find(T.shot_id == shotIds(k), 1);
    if isempty(hit)
        error('assign_scan_direction:missingShot', 'scan方向のCSVに shot_id %d がありません。', shotIds(k));
    end
    switch lower(strtrim(T.scan_direction(hit)))
        case "up"
            scanSign(k) = 1;
        case "down"
            scanSign(k) = -1;
        otherwise
            error('assign_scan_direction:badValue', 'scan_direction は Up または Down で指定してください（shot_id %d）。', shotIds(k));
    end
end
end
