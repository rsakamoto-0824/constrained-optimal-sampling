function results = run_tests()
%RUN_TESTS 自動テスト（tests/test_study.m）を実行し、結果の一覧を表示する。
rootDir = setup_paths();
results = runtests(fullfile(rootDir, 'tests', 'test_study.m'));
disp(table(results));
fprintf('合格 %d / %d\n', sum([results.Passed]), numel(results));
if any([results.Failed])
    error('run_tests:failed', 'テストに失敗があります。上の一覧を確認してください。');
end
end
