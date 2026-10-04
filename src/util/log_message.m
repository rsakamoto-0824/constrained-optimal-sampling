function log_message(logFile, varargin)
%LOG_MESSAGE 時刻付きのメッセージを画面とログファイルの両方に出す。
text = sprintf(varargin{:});
line = sprintf('[%s] %s', datestr(now, 'yyyy/mm/dd HH:MM:SS'), text);
fprintf('%s\n', line);
if ~isempty(logFile)
    fid = fopen(logFile, 'a');
    if fid > 0
        fprintf(fid, '%s\n', line);
        fclose(fid);
    end
end
end
