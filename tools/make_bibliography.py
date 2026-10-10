"""references/references.json から技術報告書の参考文献リスト（thebibliography）を作る。

使い方: python3 tools/make_bibliography.py
出力: report/technical_report.tex の「% <自動生成 bibliography>」の印で囲んだ部分を直接書き換える。
並び順は報告書で最初に引用された順（report/technical_report.tex の \\cite を順に読む）。
"""
import json
import re
from pathlib import Path

from report_tex import REPORT_TEX, replace_generated_blocks

ROOT = Path(__file__).resolve().parent.parent


def tex_escape(text):
    for a, b in (("&", "\\&"), ("%", "\\%"), ("_", "\\_"), ("#", "\\#")):
        text = text.replace(a, b)
    return text


def initials(name):
    if ", " not in name:
        # 「名 姓」の順の表記（先行調査の書誌）。最後の語を姓とする。日本語名などの1語はそのまま
        words = name.split()
        if len(words) < 2:
            return name
        last, first = words[-1], " ".join(words[:-1])
        if last.isupper():
            last = last.capitalize()
    else:
        last, first = name.split(", ", 1)
    parts = re.split(r"[\s]+", first.strip())
    ini = " ".join(p[0] + "." if not p.endswith(".") else p for p in parts if p)
    return f"{ini} {last}".strip()


def authors(ref):
    names = ref.get("authors") or []
    if not names:
        return ""
    shown = [initials(n) for n in names[:3]]
    text = ", ".join(shown)
    if len(names) > 3:
        text += ", et al."
    return text


def entry(ref):
    a = tex_escape(authors(ref))
    title = tex_escape(ref["title"])
    year = ref.get("year", "")
    typ = ref["itemType"]
    parts = []
    if typ == "patent":
        assignee = ref.get("assignee") or ref.get("company", "")
        parts.append(f"{a}（{tex_escape(str(assignee))}），``{title},'' {ref.get('number') or ref['url'].split('/')[-2]}（{year}）．")
    elif typ == "webpage":
        parts.append(f"{a}，``{title},'' Web page（{year}，2026-10-04 閲覧）．")
    elif typ == "book":
        parts.append(f"{a}，\\textit{{{title}}}，{tex_escape(ref.get('publisher', ''))}（{year}）．")
    elif typ == "bookSection":
        parts.append(f"{a}，``{title},'' in {tex_escape(ref.get('venue', ''))}，pp.~{ref.get('pages', '')}（{year}）．")
    else:
        venue = tex_escape(ref.get("venue", ""))
        pages = ref.get("pages", "")
        vp = venue + (f", {pages}" if pages else "")
        parts.append(f"{a}，``{title},'' {vp}（{year}）．")
    if ref.get("doi"):
        parts.append(f"doi:\\href{{https://doi.org/{ref['doi']}}}{{{tex_escape(ref['doi'])}}}．")
    elif ref.get("url"):
        parts.append(f"\\url{{{ref['url']}}}．")
    return " ".join(parts)


def main():
    refs = {r["key"]: r for r in json.loads((ROOT / "references" / "references.json").read_text(encoding="utf-8"))["references"]}
    tex = REPORT_TEX.read_text(encoding="utf-8")
    order = []
    for group in re.findall(r"\\cite\{([^}]*)\}", tex):
        for key in group.split(","):
            key = key.strip()
            if key and key not in order:
                order.append(key)
    missing = [k for k in order if k not in refs]
    if missing:
        raise SystemExit(f"references.json に無いキー: {missing}")
    unused = [k for k in refs if k not in order]
    lines = ["\\begin{thebibliography}{99}", "\\small"]
    for key in order:
        lines.append(f"\\bibitem{{{key}}} {entry(refs[key])}")
    lines.append("\\end{thebibliography}")
    changed = replace_generated_blocks({"bibliography": "\n".join(lines)})
    state = "書き換えました" if changed else "変更はありませんでした"
    print(f"{REPORT_TEX.name} の参考文献 {len(order)} 件を確認し、{state}。未引用: {unused}")


if __name__ == "__main__":
    main()
