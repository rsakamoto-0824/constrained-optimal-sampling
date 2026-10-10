"""技術報告書 report/technical_report.tex の「自動生成」の印で囲んだ部分を書き換える。

報告書の tex は Overleaf でそのままコンパイルできるよう1ファイルにまとめているため、
表と参考文献は別ファイルに書き出さず、次の印の間を直接差し替える。

    % <自動生成 名前> ...
    （ここが差し替わる）
    % </自動生成 名前>
"""
import re
from pathlib import Path

REPORT_TEX = Path(__file__).resolve().parent.parent / "report" / "technical_report.tex"


def replace_generated_blocks(blocks):
    """blocks（名前 → 印の間に入れる文字列）で報告書を書き換え、内容が変わった名前の一覧を返す。"""
    tex = REPORT_TEX.read_text(encoding="utf-8")
    changed = []
    for name, body in blocks.items():
        pattern = re.compile(rf"(% <自動生成 {re.escape(name)}>[^\n]*\n)(.*?)(\n% </自動生成 {re.escape(name)}>)", re.S)
        found = pattern.findall(tex)
        if len(found) != 1:
            raise SystemExit(f"{REPORT_TEX.name} に「% <自動生成 {name}>」と「% </自動生成 {name}>」の組が"
                             f"1つだけ必要です（見つかった数: {len(found)}）。")
        if found[0][1] != body:
            changed.append(name)
        tex = pattern.sub(lambda m: m.group(1) + body + m.group(3), tex)
    if changed:
        REPORT_TEX.write_text(tex, encoding="utf-8")
    return changed
