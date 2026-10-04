# constrained-optimal-sampling

wafer 高次補正（ASML HOWA をモチーフにした 3〜5 次の多項式補正）のアライメント計測 shot を、
**実務制約（象限・半径領域・scan 方向・強制計測 shot・partial shot 除外）を満たしたうえで
D 最適 / I 最適に選ぶ方法**を MATLAB で実装し、1000 枚の模擬 wafer で補正残差を評価する一式です。

- 比較する sampling 法: Random / Poisson Disk / Human（ルールベース）/ D-opt / I-opt /
  Constrained D-opt / Constrained I-opt、強制計測 shot ありでは Constrained D/I-opt Augmentation（拡張実験計画）ほか
- 評価: HOWA 補正後の残差（真の面内傾向 − 推定補正）の RMS・P95・P99・Max、D/I-efficiency、
  coverage（B_Q・B_R・B_S）、制約違反、paired comparison（bootstrap 信頼区間）、必要 shot 数の削減率
- 技術報告書: `report/technical_report.tex`（Overleaf の LuaLaTeX でそのままコンパイルできる単独ファイル）
- 説明資料: `docs/constrained-sampling-results-briefing.pptx`（24枚。生成元は `docs/results-briefing_src/`）

## フォルダ構成

```
constrained-optimal-sampling/
├── run_study.m              # 本体: 設定ファイルを読んで最初から最後まで実行する
├── run_tests.m              # 自動テスト（品質確認10項目＋部品の単体テスト）
├── setup_paths.m            # src 以下をパスに追加
├── config/
│   ├── default_config.json  # 本計算（1000 wafer）の全評価条件
│   └── smoke_config.json    # 動作確認用の小規模設定（default を上書き）
├── src/
│   ├── config/      設定の読み込みと検証
│   ├── geometry/    shot 配置・partial shot 判定・象限・半径領域・scan 方向・強制 shot
│   ├── model/       HOWA 多項式（項の自動生成・正規直交化した情報行列）
│   ├── design/      制約の上下限・D/I 基準・modified Fedorov 交換法（multi-start）・N_min
│   ├── sampling/    Random・Poisson disk・Human（ルールと外部CSV）
│   ├── wafer/       Fringe Zernike・scan 方向依存成分・mark 計測誤差
│   ├── evaluation/  HOWA 補正と残差指標・モデル不一致の下限
│   ├── stats/       百分位点・paired difference・t 分布の分位点（Toolbox 不要）
│   ├── pipeline/    設計作成・Monte Carlo 評価・統計・CSV 出力・代表 wafer の選定・soft 制約の補助評価
│   ├── plots/       本文の図と Appendix の図
│   └── util/        乱数ストリーム・ログ・手法一覧など
├── tests/           test_study.m（runtests 形式）と test_config.json
├── tools/           check_multistart.m（multi-start 回数が足りているかの確認）
├── results/         本計算の出力（csv/ は登録、figures/ と study_results.mat は再生成）
├── report/          technical_report.tex と figures/（報告書で使う図）
├── docs/            結果の説明資料（PPTX は再生成。生成元は results-briefing_src/）
└── references/      references.json（参考文献の正本）と zotero/（Zotero 取り込み一式）
```

## 必要な環境

- MATLAB R2020b 以降（`tiledlayout` の凡例配置・`boxchart` を使用）。このリポジトリでは R2022b（macOS）で確認した
- Toolbox は不要（Statistics and Machine Learning Toolbox の関数は使わない。百分位点・t 分布・bootstrap は自前実装）
- Parallel Computing Toolbox があれば `config` の `parallel.enabled` を `true` にすると Monte Carlo 評価を `parfor` で並列化できる（なくても同じ結果になる）
- 環境変数・認証情報は不要

## 実行方法

MATLAB でリポジトリのフォルダに移動してから実行します。

```matlab
run_tests                                        % 自動テスト（約30秒、15件）
run_study('config/smoke_config.json')            % 動作確認（約2分、results_smoke/ に出力）
run_study('config/default_config.json')          % 本計算（約35分、results/ に出力）
run_study('config/default_config.json', 'MakeFigures', false)   % 図を作らない（約30分）
make_figures('results'); make_appendix_figures('results')       % 保存済みの結果から図だけ作り直す
addpath('tools'); check_multistart('config/default_config.json')  % multi-start 回数の確認（約3分）
```

本計算の計算時間の内訳（R2022b、Apple Silicon 上の Rosetta 2、並列化なし）は `results/logs/timing_log.csv` にあります（設計 12.9 分、Monte Carlo 評価 4.6 分、統計 2.4 分、soft 制約の補助評価 9.7 分、図 3.4 分、合計約 33 分）。

### 計測 shot 数のスイープ

HOWA 次数ごとに、`4 × N ≥ p` を満たす最小の N から 1 shot ずつ増やし、制約なし D 最適で full rank の設計が
見つかった最初の N を N_min とします（3次: 3、4次: 4、5次: 6）。そこから floor(N_candidate / 3) = 19 shot まで
**1 shot 刻み**で全条件を評価しています（adaptive grid は使っていません。`sweep.mode` を `adaptive` にすると
低 shot 側を細かく・高 shot 側を粗くできます）。

## 出力（results/）

| ファイル | 内容 |
|---|---|
| `csv/shot_candidates.csv` | 全 shot（partial shot を含む）の座標・象限・半径領域・scan 方向・候補かどうか・強制 shot |
| `csv/evaluation_points.csv` | 残差を評価する点（全 shot の usable 領域内の mark） |
| `csv/nmin.csv`, `csv/constraint_bounds.csv` | N_min と、shot 数ごとの制約の上下限 |
| `csv/selected_shots.csv` | 各手法・次数・shot 数で選ばれた shot（縦長） |
| `csv/design_metrics.csv` | 各設計の D/I-efficiency・coverage・制約違反・計算時間・full rank 判定 |
| `csv/wafer_results_<条件>_<シナリオ>_howa<次数>.csv` | 1000 wafer ごとの残差指標（Spotfire 入力を想定した縦長の表） |
| `csv/aggregated_metrics.csv` | 設計 × 条件ごとの Monte Carlo 統計量（平均・中央値・標準偏差・P90・P95・P99・最悪値） |
| `csv/paired_comparison.csv` | 提案法と比較法の waferごとの差の統計（t 信頼区間・bootstrap 信頼区間・勝率・改善率） |
| `csv/shot_reduction.csv` | 基準手法と同じ平均 RMS（または P95）に必要な最小 shot 数と削減率 |
| `csv/random_draw_*.csv` | Random の抽選ごとの結果のまとめ（中央値・平均・P95・最良・最悪） |
| `csv/soft_constraint_study.csv` | soft 制約の罰則の重みを変えた補助評価 |
| `csv/model_mismatch_floor.csv` | 計測誤差なし・全評価点を使ったときの HOWA 残差（モデル不一致の下限） |
| `csv/wafer_truth_summary.csv`, `csv/zernike_*.csv` | 生成した wafer の Zernike 項・係数・RMS |
| `csv/appendix_samples.csv` | Appendix の代表 wafer 3 例と選定ルール |
| `figures/`, `figures/appendix/` | 図（PNG 300 dpi）。ファイル名と内容は報告書の図番号と対応 |
| `run_info.json`, `config_resolved.json`, `logs/` | 乱数 seed・MATLAB の版・実行日時・Git のコミット・設定内容・計算時間 |

## 設定ファイルと仮定値

すべての評価条件は `config/default_config.json` で変えられます（コードに数値は埋め込んでいません）。
次の値は実工程の値が未確定のため置いた **仮定値** です。結論はこれらの値に依存します。

| 項目 | 既定値（仮定値） | 設定の場所 |
|---|---|---|
| shot サイズ・pitch・格子原点 | 26 × 33 mm、pitch 26 × 33 mm、原点 (0, 0) | `shot` |
| edge exclusion | 3 mm（usable 半径 147 mm） | `wafer` |
| alignment mark 位置 | shot 中心から (±12, ±15.5) mm の4点 | `marks.offsets_mm` |
| scan 方向の割当 | 隣接する列で Up/Down 交互 | `scan` |
| 半径領域の境界 | 正規化半径 0.5 / 0.7（Inner / Middle / Outer、候補 21 / 22 / 14 shot） | `constraints.radial` |
| 象限・半径の許容幅 | 目標割合（象限 1/4、半径 1/3）± max(割合×N, 1 shot)（象限 5%、半径 10%） | `constraints.*.tolerance_fraction` |
| scan balance の許容差 | \|N_up − N_down\| ≤ 1 | `constraints.scan` |
| 強制計測 shot | 中心と上下左右の十字（5 shot） | `mandatory` |
| Zernike 係数 | 7次まで（36項）から 10〜20 項、σ_k = 3 nm / n、RMS を 1〜8 nm に収める | `zernike` |
| scan 方向依存成分 | Model A 0.3 nm、Model B 0.5 nm（u, v 項）、Model C Up 0.15 / Down 0.25 nm | `scan_noise` |
| mark 計測誤差 | low 0.25 / nominal 0.5 / high 1.0 nm（1σ） | `mark_noise` |
| Human 配置 | 中心＋正規化半径 0.45・0.78 の円上に等角度 | `human`（`csv_path` で実配置の CSV を読める） |
| Poisson の最小距離 | shot 数に合うよう自動調整、20 個の初期値 | `poisson` |
| 最適化の multi-start・収束判定 | 200 回（＋D/I の相互初期解 1 回）、相対改善 1e-9 未満で終了 | `optimizer` |
| Random の抽選回数 | 200 回 | `random_sampling` |

### Human sampling を実配置にする

列 `n_shots, shot_id` の CSV（shot_id は `csv/shot_candidates.csv` の ID）を作り、`human.csv_path` に指定すると、
その shot 数では CSV の配置を使います（それ以外の shot 数はルールベースのまま）。

## 報告書の更新（report/）

- `report/technical_report.tex` は単独で完結する tex ファイルです。Overleaf では `report/` フォルダ（tex と `figures/`）をアップロードし、メニューの Compiler を **LuaLaTeX** にしてコンパイルします
- 表の数値は `python3 tools/make_report_tables.py` が `results/csv` から作る `report/generated_tables.tex` を転記したものです（本文中の数値もこの出力と CSV で確認できます）
- 参考文献リストは `python3 tools/make_bibliography.py` が `references/references.json` から作る `report/generated_bibliography.tex` を転記したものです
- 図は `results/figures/` から報告書で使う分を `report/figures/` にコピーしています。再計算したらコピーし直してください

## 説明資料の更新（docs/）

- 実験結果を説明する PowerPoint は `docs/results-briefing_src/` のスクリプトで作ります。手順は同フォルダの README を参照してください
- 数値は `results/csv` から自動で取り出します。PPTX はバイナリのため Git に登録していません

## 参考文献（references/）

- `references.json`：引用38件の正本（書誌・URL・取得状況・未取得の理由）
- `参考文献リンク.md`：上の一覧を読みやすくしたもの（`python3 references/build_link_list.py` で再生成）
- `zotero/`：Zotero への取り込み一式（Zotero の［ツール］→［開発］→［JavaScriptを実行］で実行。手順は `zotero/README.md`）

## 注意事項

- 実データ・社内情報は使っていません。wafer の面内傾向・scan 成分・計測誤差はすべて乱数で生成した模擬データです
- HOWA は ASML 製品の内部アルゴリズムの再現ではなく、公開情報を参考にした「総次数 3〜5 の 2 変数多項式」です
- 残差は、計測誤差と scan 成分を含まない真の面内傾向（Fringe Zernike）に対して、全 shot（partial shot を含む）の
  usable 領域内の mark で評価しています。候補 shot の mark だけで評価した値（`rms_vec_interior_nm`）も出力しています
- 図は PNG（300 dpi）です。macOS の MATLAB では図のフォントが Arial 以外に置き換わることがあります
- `results/csv/wafer_results_*.csv` は 1 ファイル約 10 MB です
- 参考文献の本文（`references/sources/`）は著作物のため Git に登録していません。Zotero には `references/zotero/` の手順でリンク添付します
