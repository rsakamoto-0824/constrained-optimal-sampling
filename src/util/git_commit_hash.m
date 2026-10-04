function hash = git_commit_hash(rootDir)
%GIT_COMMIT_HASH リポジトリの現在のコミットID（取得できなければ 'unknown'）。
hash = 'unknown';
try
    [status, out] = system(sprintf('git -C "%s" rev-parse HEAD', rootDir));
    if status == 0
        hash = strtrim(out);
    end
catch
end
end
