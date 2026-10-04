function write_json(data, filePath)
%WRITE_JSON 構造体をJSONファイルに書き出す（R2021a以降は整形して出力）。
try
    text = jsonencode(data, 'PrettyPrint', true);
catch
    text = jsonencode(data);
end
fid = fopen(filePath, 'w', 'n', 'UTF-8');
if fid < 0
    error('write_json:open', 'ファイルを開けませんでした: %s', filePath);
end
fprintf(fid, '%s\n', text);
fclose(fid);
end
