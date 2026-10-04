function info = method_info(key)
%METHOD_INFO 手法キーから method_catalog の1行を返す。
catalog = method_catalog();
hit = find(strcmp({catalog.key}, key), 1);
if isempty(hit)
    error('method_info:unknown', '未登録の手法キーです: %s', key);
end
info = catalog(hit);
end
