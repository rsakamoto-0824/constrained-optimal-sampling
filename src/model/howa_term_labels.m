function labels = howa_term_labels(order)
%HOWA_TERM_LABELS HOWA項の表示名（例: '1', 'u', 'u^2v'）を返す。
exponents = howa_exponents(order);
labels = cell(size(exponents, 1), 1);
for k = 1:size(exponents, 1)
    labels{k} = [power_label('u', exponents(k, 1)), power_label('v', exponents(k, 2))];
    if isempty(labels{k})
        labels{k} = '1';
    end
end
end

function s = power_label(name, power)
if power == 0
    s = '';
elseif power == 1
    s = name;
else
    s = sprintf('%s^%d', name, power);
end
end
