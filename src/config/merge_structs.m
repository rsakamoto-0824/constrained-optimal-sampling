function merged = merge_structs(base, override)
%MERGE_STRUCTS override の項目で base を上書きした構造体を返す（入れ子の構造体は再帰的に上書き）。
merged = base;
names = fieldnames(override);
for k = 1:numel(names)
    name = names{k};
    value = override.(name);
    if isfield(merged, name) && isstruct(merged.(name)) && isstruct(value) ...
            && isscalar(merged.(name)) && isscalar(value)
        merged.(name) = merge_structs(merged.(name), value);
    else
        merged.(name) = value;
    end
end
end
