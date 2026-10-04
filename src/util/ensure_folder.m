function ensure_folder(folder)
%ENSURE_FOLDER フォルダがなければ作る。
if ~isfolder(folder)
    [ok, msg] = mkdir(folder);
    if ~ok
        error('ensure_folder:failed', 'フォルダを作れませんでした: %s（%s）', folder, msg);
    end
end
end
