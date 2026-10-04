function cfg = load_config(configPath)
%LOAD_CONFIG JSON設定ファイルを読み込み、検証済みの設定構造体を返す。
%   設定に base_config があれば、そのファイルを先に読み込み、記載された項目だけを上書きする。
if nargin < 1 || isempty(configPath)
    error('load_config:noPath', '設定ファイルのパスを指定してください。');
end
if ~isfile(configPath)
    error('load_config:notFound', '設定ファイルが見つかりません: %s', configPath);
end
raw = jsondecode(fileread(configPath));
if isfield(raw, 'base_config') && ~isempty(raw.base_config)
    basePath = raw.base_config;
    if ~is_absolute_path(basePath)
        basePath = fullfile(fileparts(configPath), basePath);
    end
    baseCfg = load_config_raw(basePath);
    raw = rmfield(raw, 'base_config');
    raw = merge_structs(baseCfg, raw);
end
cfg = validate_config(raw);
cfg.source_path = char(configPath);
end

function raw = load_config_raw(configPath)
if ~isfile(configPath)
    error('load_config:notFound', '基準の設定ファイルが見つかりません: %s', configPath);
end
raw = jsondecode(fileread(configPath));
end

function tf = is_absolute_path(p)
p = char(p);
tf = startsWith(p, '/') || startsWith(p, '\') || (numel(p) >= 2 && p(2) == ':');
end
