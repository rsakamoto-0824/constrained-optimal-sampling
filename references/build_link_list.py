"""references.json から参考文献・参考リンクの一覧（Markdown）を作る。

使い方: python3 build_link_list.py  → 参考文献リンク.md
"""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
STATUS_LABEL = {
    "obtained": "本文取得済み（正規の入手先から取得し内容を確認）",
    "existing": "Zotero登録済み・本文確認済み（既存の文献を再利用）",
    "not_obtained": "本文未取得",
}


def authors_text(ref):
    authors = ref.get("authors") or []
    if not authors:
        return ref.get("assignee", "")
    names = [a.split(", ")[0] if ", " in a else a.split(" ")[-1] for a in authors]
    return ", ".join(names[:3]) + (" ほか" if len(names) > 3 else "")


def main():
    data = json.loads((HERE / "references.json").read_text(encoding="utf-8"))
    lines = [
        "# 参考文献・参考リンク",
        "",
        "技術報告書「wafer高次補正のアライメント計測shot選択における実務制約付き最適サンプリング手法の構築と評価」",
        "（`report/technical_report.tex`）で引用した文献の一覧。正本は `references.json`。確認日：2026-10-04。",
        "",
        f"- 合計 {len(data['references'])} 件：本文取得済み {sum(r['status'] == 'obtained' for r in data['references'])} 件、"
        f"Zotero登録済み（既存）{sum(r['status'] == 'existing' for r in data['references'])} 件、"
        f"本文未取得 {sum(r['status'] == 'not_obtained' for r in data['references'])} 件",
        "- 本文ファイルは `references/sources/`（Gitの対象外）。Zoteroの案件コレクション：`2026-10-04_制約付き最適サンプリング評価`",
        "- 社内の情報は使っていない。評価の数値はすべて乱数で生成した模擬データによる",
        "",
    ]
    for status in ("obtained", "existing", "not_obtained"):
        refs = [r for r in data["references"] if r["status"] == status]
        lines += [f"## {STATUS_LABEL[status]}（{len(refs)} 件）", ""]
        for r in refs:
            parts = [f"**{r['title']}**", authors_text(r), str(r.get("year", ""))]
            venue = r.get("venue") or r.get("number") or r.get("publisher") or ""
            if venue:
                parts.append(venue)
            if r.get("pages"):
                parts.append(r["pages"])
            lines.append(f"- [{r['key']}] " + ", ".join(p for p in parts if p))
            if r.get("doi"):
                lines.append(f"  - DOI：{r['doi']}")
            if r.get("url"):
                lines.append(f"  - リンク：{r['url']}")
            if r.get("used_for"):
                lines.append(f"  - 内容・引用箇所：{r['used_for']}")
            if r.get("file"):
                lines.append(f"  - 本文ファイル：`{Path(r['file']).name}`")
            if r.get("reason"):
                lines.append(f"  - 未取得の理由：{r['reason']}")
            if r.get("note"):
                lines.append(f"  - 備考：{r['note']}")
        lines.append("")
    (HERE / "参考文献リンク.md").write_text("\n".join(lines), encoding="utf-8")
    print("参考文献リンク.md を作成しました")


if __name__ == "__main__":
    main()
