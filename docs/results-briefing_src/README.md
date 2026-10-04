# 評価結果の説明資料（PowerPoint）の生成元

技術報告書 `report/technical_report.tex` の実験結果を説明する24枚のスライド
`docs/constrained-sampling-results-briefing.pptx` を作るためのファイルです。
スライドとノートの数値は、すべて `results/csv` から自動で取り出します（手で書き写していません）。

## ファイル

| ファイル | 役割 |
| --- | --- |
| `prepare_data.py` | `results/csv` と `results/logs/timing_log.csv` から、スライドに載せる数値を `deck_data.json` にまとめる |
| `deck_data.json` | 上の出力（Git管理。Pythonがなくてもスライドを作り直せるようにするため） |
| `build_deck.js` | `deck_data.json` と `report/figures` の図からスライドを作る（pptxgenjs） |
| `postprocess.py` | 日本語フォントの指定（BIZ UDGothic／欧文Arial）の修正、重複した段落設定・空のグラフ点の削除、再圧縮 |
| `check_deck.py` | 枚数・ノート・フォント・はみ出し・ZIPの整合を確認する |

## 作り直す手順

リポジトリ直下で実行します。

```bash
cd docs/results-briefing_src
python3 prepare_data.py
NODE_PATH="$(npm root -g)" node build_deck.js deck_raw.pptx
python3 postprocess.py deck_raw.pptx deck.building.pptx
python3 check_deck.py deck.building.pptx 24
mv deck.building.pptx ../constrained-sampling-results-briefing.pptx
rm deck_raw.pptx
```

## 必要な環境

- Node.js と、グローバルにインストールした `pptxgenjs`（4.0.1で確認）
- Python 3 と `python-pptx`（`check_deck.py` で使用）
- 認証情報や環境変数は不要です

## 注意事項

- PPTXはバイナリなのでGitに登録しません（`.gitignore` 済み）。正本はこのフォルダの生成元です。
- `run_study` をやり直して `results/csv` が変わったら、`prepare_data.py` から実行し直してください。
  結果⑧（強制計測shot）の「D基準の11 shotではNaiveの方が有意に良く、I基準では拡張計画が良い」という記述は、データと合わなくなると
  `build_deck.js` がエラーで止まるようにしています。ほかの文章は数値だけが自動で変わるので、
  結論の向きが変わっていないかスライドを見て確認してください。
- 数値はすべて乱数で作った模擬waferによるもので、実データ・社内データは使っていません。
