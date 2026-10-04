function stream = make_stream(masterSeed, label)
%MAKE_STREAM master_seed と用途ラベルから、再現可能な独立した乱数ストリームを作る。
%   同じ (masterSeed, label) なら必ず同じ乱数列になる。用途ごとにラベルを分けることで、
%   ある処理の乱数の使い方を変えても、他の処理の乱数は変わらない。
seed = mod(masterSeed + label_hash(label), 2^32);
stream = RandStream('mt19937ar', 'Seed', seed);
end

function h = label_hash(label)
% 文字列から決まる 0〜2^31-1 の整数（djb2 方式）
h = 5381;
codes = double(char(label));
for c = codes
    h = mod(h * 33 + c, 2^31 - 1);
end
end
