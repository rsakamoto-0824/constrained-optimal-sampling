function rootDir = setup_paths()
%SETUP_PATHS src 以下のフォルダをMATLABパスに追加し、リポジトリのルートを返す。
rootDir = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(rootDir, 'src')));
end
