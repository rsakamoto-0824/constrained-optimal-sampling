"""references.json から Zotero 取り込み用の manifest.json を作る。

使い方: python3 build_zotero_manifest.py
- 新しく登録する文献（status = obtained / not_obtained）は items に入れる。本文ファイルがあればリンク添付する
- 既に Zotero にある文献（status = existing）は existing_references に入れ、案件コレクションに追加するだけにする
- タグは5系統（種別/・分野/・所属/・掲載誌/・ライブラリ/）だけを使う
"""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
REFERENCES_DIR = HERE.parent
CASE_COLLECTION = "2026-10-04_制約付き最適サンプリング評価"
UNREAD_TAG = "未読"
ACCESS_DATE = "2026-10-04"

# 文献ごとの分類（テーマのコレクションとタグ）。所属は本文または書誌で確認できたものだけ付ける
CLASSIFICATION = {
    "wang2009": ("01_半導体プロセス", ["種別/論文", "掲載誌/SPIE Proceedings", "分野/オーバーレイ・EPE", "所属/Inotera", "所属/ASML"]),
    "pike2012": ("01_半導体プロセス", ["種別/論文", "掲載誌/SPIE Proceedings", "分野/オーバーレイ・EPE", "所属/IBM", "所属/GLOBALFOUNDRIES", "所属/ASML"]),
    "jeon2013": ("01_半導体プロセス", ["種別/論文", "掲載誌/SPIE Proceedings", "分野/オーバーレイ・EPE"]),
    "chue2009": ("01_半導体プロセス", ["種別/論文", "掲載誌/SPIE Proceedings", "分野/オーバーレイ・EPE", "所属/Nanya", "所属/ASML"]),
    "koay2010": ("01_半導体プロセス", ["種別/論文", "掲載誌/SPIE Proceedings", "分野/オーバーレイ・EPE"]),
    "chiu2022a": ("01_半導体プロセス", ["種別/論文", "掲載誌/SPIE Proceedings", "分野/オーバーレイ・EPE"]),
    "chiu2022b": ("01_半導体プロセス", ["種別/論文", "掲載誌/SPIE Proceedings", "分野/オーバーレイ・EPE"]),
    "us9291916": ("05_資料", ["種別/資料", "分野/オーバーレイ・EPE", "所属/ASML"]),
    "us7197722": ("05_資料", ["種別/資料", "分野/オーバーレイ・EPE", "所属/Intel"]),
    "us7571420": ("05_資料", ["種別/資料", "分野/オーバーレイ・EPE", "所属/Intel"]),
    "us7042552": ("05_資料", ["種別/資料", "分野/オーバーレイ・EPE", "所属/ASML"]),
    "wo2020234028": ("05_資料", ["種別/資料", "分野/オーバーレイ・EPE", "所属/ASML"]),
    "us11775728": ("05_資料", ["種別/資料", "分野/オーバーレイ・EPE", "所属/ASML"]),
    "nikon_litho_booster": ("05_資料", ["種別/資料", "分野/オーバーレイ・EPE", "所属/Nikon"]),
    "canon_ms001": ("05_資料", ["種別/資料", "分野/オーバーレイ・EPE", "所属/Canon"]),
    "fedorov1972": ("04_統計", ["種別/書籍", "分野/実験計画法"]),
    "mitchell1974": ("04_統計", ["種別/論文", "掲載誌/Technometrics", "分野/実験計画法"]),
    "cook1980": ("04_統計", ["種別/論文", "掲載誌/Technometrics", "分野/実験計画法"]),
    "dykstra1971": ("04_統計", ["種別/論文", "掲載誌/Technometrics", "分野/実験計画法"]),
    "meyer1995": ("04_統計", ["種別/論文", "掲載誌/Technometrics", "分野/実験計画法"]),
    "atkinson2007": ("04_統計", ["種別/書籍", "分野/実験計画法"]),
    "goos2011": ("04_統計", ["種別/書籍", "分野/実験計画法"]),
    "jones2012": ("04_統計", ["種別/論文", "掲載誌/Journal of Quality Technology", "分野/実験計画法"]),
    "wyant1992": ("02_フォトニクス・光学シミュレーション", ["種別/書籍", "分野/光学"]),
    "bridson2007": ("04_統計", ["種別/論文", "掲載誌/ACM SIGGRAPH", "分野/サンプリング"]),
    "efron1993": ("04_統計", ["種別/書籍", "分野/統計"]),
}


def creators_of(ref):
    creator_type = "inventor" if ref["itemType"] == "patent" else "author"
    if ref["itemType"] == "webpage":
        return []
    creators = []
    for name in ref.get("authors", []):
        last, _, first = name.partition(", ")
        creators.append({"lastName": last, "firstName": first, "creatorType": creator_type})
    return creators


def fields_of(ref):
    item_type = ref["itemType"]
    fields = {"url": ref.get("url", "")}
    if item_type == "conferencePaper":
        fields.update({"proceedingsTitle": ref.get("venue", ""), "pages": ref.get("pages", ""),
                       "DOI": ref.get("doi", ""), "publisher": "SPIE" if "SPIE" in ref.get("venue", "") else ""})
    elif item_type == "journalArticle":
        venue = ref.get("venue", "")
        title, _, rest = venue.partition(" ")
        journal = venue.split(" ")[0] if venue.startswith("Technometrics") else "Journal of Quality Technology"
        volume = rest.split("(")[0] if venue.startswith("Technometrics") else "44"
        issue = venue[venue.find("(") + 1:venue.find(")")] if "(" in venue else ""
        fields.update({"publicationTitle": journal, "volume": volume, "issue": issue,
                       "pages": ref.get("pages", ""), "DOI": ref.get("doi", "")})
    elif item_type == "patent":
        fields.update({"patentNumber": ref.get("number", ""), "assignee": ref.get("assignee", ""),
                       "country": ref.get("number", "")[:2], "issueDate": ref.get("date", "")})
    elif item_type == "webpage":
        fields.update({"accessDate": ref.get("accessed", ACCESS_DATE)})
    elif item_type == "book":
        fields.update({"publisher": ref.get("publisher", "")})
    elif item_type == "bookSection":
        fields.update({"bookTitle": ref.get("venue", ""), "pages": ref.get("pages", ""), "publisher": "Academic Press"})
    return {k: v for k, v in fields.items() if v}


def import_id(ref):
    source = ref.get("file")
    if source and (REFERENCES_DIR / source).exists():
        digest = hashlib.sha256((REFERENCES_DIR / source).read_bytes()).hexdigest()
    else:
        digest = hashlib.sha256((ref["key"] + "|" + ref["title"]).encode("utf-8")).hexdigest()
    return "constrained-sampling:" + digest


def main():
    refs = json.loads((REFERENCES_DIR / "references.json").read_text(encoding="utf-8"))["references"]
    items, existing = [], []
    for ref in refs:
        if ref["status"] == "existing":
            existing.append({"key": ref["key"], "doi": ref.get("doi", ""), "title": ref["title"]})
            continue
        collection, tags = CLASSIFICATION[ref["key"]]
        record = {
            "key": ref["key"], "itemType": ref["itemType"], "title": ref["title"], "collection": collection,
            "tags": tags, "creators": creators_of(ref), "date": str(ref.get("date", ref.get("year", ""))),
            "fields": fields_of(ref), "importId": import_id(ref),
            "status": ref["status"], "reason": ref.get("reason", ""),
        }
        if ref.get("file"):
            record["file"] = ref["file"]
        items.append(record)
    manifest = {"base": str(REFERENCES_DIR), "case_collection": CASE_COLLECTION, "unread_tag": UNREAD_TAG,
                "items": items, "existing_references": existing}
    (HERE / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"manifest.json: 新規 {len(items)} 件（本文あり {sum('file' in i for i in items)} 件）、登録済み {len(existing)} 件")


if __name__ == "__main__":
    main()
