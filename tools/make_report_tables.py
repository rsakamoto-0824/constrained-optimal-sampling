"""results/csv の評価結果から、技術報告書に載せる表（LaTeX）と本文の数値を作る。

使い方: python3 tools/make_report_tables.py [結果フォルダ]（既定は results）
出力: report/generated_tables.tex（報告書へ貼り付ける表の元）と、画面への数値の要約
報告書の tex は単独ファイルにするため、この出力を technical_report.tex に転記している。
"""
import csv
import math
import statistics
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESULTS = ROOT / (sys.argv[1] if len(sys.argv) > 1 else "results")
CSV = RESULTS / "csv"
BASE = ["random", "poisson", "human", "dopt", "iopt", "cdopt", "ciopt"]
MAND = ["random_f", "poisson_f", "human_f", "dopt_aug", "iopt_aug", "cdopt_naive", "ciopt_naive", "cdopt_aug", "ciopt_aug"]
LABEL = {"random": "Random", "poisson": "Poisson", "human": "Human", "dopt": "D-opt", "iopt": "I-opt",
         "cdopt": "C-D-opt", "ciopt": "C-I-opt", "random_f": "Random+F", "poisson_f": "Poisson+F",
         "human_f": "Human+F", "dopt_aug": "D-opt Aug", "iopt_aug": "I-opt Aug", "cdopt_naive": "C-D Naive",
         "ciopt_naive": "C-I Naive", "cdopt_aug": "C-D Aug", "ciopt_aug": "C-I Aug"}
ORDERS = [3, 4, 5]


def read(name):
    with open(CSV / name, encoding="utf-8") as f:
        return list(csv.DictReader(f))


def num(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return float("nan")


AGG = read("aggregated_metrics.csv")
PAIR = read("paired_comparison.csv")
DM = read("design_metrics.csv")
RED = read("shot_reduction.csv")
RDS = read("random_draw_design_summary.csv")
RRS = read("random_draw_residual_summary.csv")
FLOOR = read("model_mismatch_floor.csv")
SOFT = read("soft_constraint_study.csv")
SAMPLES = read("appendix_samples.csv")

agg_index = {(r["condition"], r["scenario"], r["method"], int(r["howa_order"]), int(r["n_shots"])): r for r in AGG}
dm_index = {(r["scenario"], r["method"], int(r["howa_order"]), int(r["n_shots"])): r for r in DM}
pair_index = {(r["condition"], r["scenario"], int(r["howa_order"]), int(r["n_shots"]), r["proposed_method"],
               r["comparator_method"]): r for r in PAIR}


def agg(cond, scen, meth, order, n, col):
    r = agg_index.get((cond, scen, meth, order, n))
    return num(r[col]) if r else float("nan")


def dm(scen, meth, order, n, col):
    r = dm_index.get((scen, meth, order, n))
    return num(r[col]) if r else float("nan")


def pair(cond, scen, order, n, prop, comp):
    return pair_index.get((cond, scen, order, n, prop, comp))


def fmt(x, digits=2):
    if x != x:
        return "--"
    if abs(x) >= 100:
        return f"{x:.0f}"
    return f"{x:.{digits}f}"


out = []


def table_mean_rms():
    ns = [6, 8, 10, 12, 15, 19]
    out.append("% 表: 平均RMS（主評価条件・強制shotなし）")
    out.append("\\begin{tabular}{cr" + "r" * len(BASE) + "r}\n\\toprule")
    out.append("次数 & $N$ & " + " & ".join(LABEL[m] for m in BASE) + " & 下限 \\\\\n\\midrule")
    for o in ORDERS:
        floor = statistics.mean(num(r[f"floor_rms_vec_howa{o}_nm"]) for r in FLOOR)
        for k, n in enumerate(ns):
            vals = [agg("nominal", "base", m, o, n, "rms_vec_nm_mean") for m in BASE]
            best = min(v for v in vals if v == v) if any(v == v for v in vals) else float("nan")
            cells = []
            for v in vals:
                s = fmt(v)
                if v == best:
                    s = "\\textbf{" + s + "}"
                cells.append(s)
            first = f"\\multirow{{{len(ns)}}}{{*}}{{{o}}}" if k == 0 else ""
            last = fmt(floor) if k == 0 else ""
            out.append(f"{first} & {n} & " + " & ".join(cells) + f" & {last} \\\\")
        out.append("\\midrule" if o != ORDERS[-1] else "\\bottomrule")
    out.append("\\end{tabular}\n")


def table_tail(n=12):
    out.append(f"% 表: tail指標（N = {n}）")
    cols = [("rms_vec_nm_mean", "平均"), ("rms_vec_nm_median", "中央値"), ("rms_vec_nm_p95", "P95"),
            ("rms_vec_nm_worst", "最悪"), ("p99_mag_nm_mean", "P99$|e|$"), ("max_mag_nm_mean", "Max$|e|$"),
            ("rms_vec_interior_nm_mean", "内側RMS")]
    out.append("\\begin{tabular}{cl" + "r" * len(cols) + "}\n\\toprule")
    out.append("次数 & 手法 & " + " & ".join(c[1] for c in cols) + " \\\\\n\\midrule")
    for o in ORDERS:
        for k, m in enumerate(BASE):
            first = f"\\multirow{{{len(BASE)}}}{{*}}{{{o}}}" if k == 0 else ""
            out.append(f"{first} & {LABEL[m]} & " + " & ".join(fmt(agg('nominal', 'base', m, o, n, c)) for c, _ in cols) + " \\\\")
        out.append("\\midrule" if o != ORDERS[-1] else "\\bottomrule")
    out.append("\\end{tabular}\n")


def table_paired(n=12, scen="base", props=("cdopt", "ciopt"), comps=("random", "poisson", "human", "dopt", "iopt")):
    out.append(f"% 表: paired comparison（N = {n}, {scen}）")
    out.append("\\begin{tabular}{ccl" + "r" * 4 + "}\n\\toprule")
    out.append("次数 & 提案法 & 比較法 & 平均$\\Delta$RMS [nm] & 平均改善率 [\\%] & 95\\%CI [\\%] & 勝率 \\\\\n\\midrule")
    for o in ORDERS:
        rows = []
        for p in props:
            for c in comps:
                r = pair("nominal", scen, o, n, p, c)
                if r is None:
                    continue
                rows.append((p, c, r))
        for k, (p, c, r) in enumerate(rows):
            first = f"\\multirow{{{len(rows)}}}{{*}}{{{o}}}" if k == 0 else ""
            out.append(f"{first} & {LABEL[p]} & {LABEL[c]} & {num(r['mean_delta_nm']):+.3f} & "
                       f"{num(r['mean_improvement_pct']):+.1f} & [{num(r['boot_improvement_ci_low_pct']):+.1f}, "
                       f"{num(r['boot_improvement_ci_high_pct']):+.1f}] & {num(r['win_rate']):.2f} \\\\")
        out.append("\\midrule" if o != ORDERS[-1] else "\\bottomrule")
    out.append("\\end{tabular}\n")


def summary_paired_over_n():
    lines = ["% 要約: 改善率（平均RMSどうし）の N=8〜19 の中央値と、95%CIが0を超えた/下回った N の数"]
    for o in ORDERS:
        for p in ("cdopt", "ciopt"):
            parts = []
            for c in ("random", "poisson", "human", "dopt", "iopt"):
                vals, better, worse = [], 0, 0
                for n in range(8, 20):
                    r = pair("nominal", "base", o, n, p, c)
                    if r is None or num(r["mean_delta_nm"]) != num(r["mean_delta_nm"]):
                        continue
                    vals.append(num(r["improvement_of_means_pct"]))
                    better += num(r["boot_mean_ci_low_nm"]) > 0
                    worse += num(r["boot_mean_ci_high_nm"]) < 0
                parts.append(f"{c}:med {statistics.median(vals):+.1f}% (+{better}/-{worse}/{len(vals)})")
            lines.append(f"% HOWA{o} {p}: " + "  ".join(parts))
    out.extend(lines)
    out.append("")


def table_efficiency():
    out.append("% 表: D/I-efficiency（強制shotなし）")
    ns = [8, 12, 19]
    out.append("\\begin{tabular}{cl" + "rr" * len(ns) + "}\n\\toprule")
    out.append("次数 & 手法 & " + " & ".join(f"\\multicolumn{{2}}{{c}}{{$N={n}$}}" for n in ns) + " \\\\")
    out.append(" & & " + " & ".join("D & I" for _ in ns) + " \\\\\n\\midrule")
    for o in ORDERS:
        for k, m in enumerate(BASE):
            first = f"\\multirow{{{len(BASE)}}}{{*}}{{{o}}}" if k == 0 else ""
            cells = []
            for n in ns:
                if m == "random":
                    rr = [r for r in RDS if r["scenario"] == "base" and int(r["howa_order"]) == o and int(r["n_shots"]) == n]
                    cells += [fmt(num(rr[0]["d_eff_median"])), fmt(num(rr[0]["i_eff_median"]))] if rr else ["--", "--"]
                else:
                    cells += [fmt(dm("base", m, o, n, "d_efficiency")), fmt(dm("base", m, o, n, "i_efficiency"))]
            out.append(f"{first} & {LABEL[m]} & " + " & ".join(cells) + " \\\\")
        out.append("\\midrule" if o != ORDERS[-1] else "\\bottomrule")
    out.append("\\end{tabular}\n")


def table_violation():
    out.append("% 表: 制約違反とcoverage（全次数・全shot数の設計で集計）")
    out.append("\\begin{tabular}{lrrrrrrr}\n\\toprule")
    out.append("手法 & 象限 & 半径 & scan & いずれか & $\\bar{B}_Q$ & $\\bar{B}_R$ & $\\bar{B}_S$ \\\\\n\\midrule")
    rows = [r for r in RDS if r["scenario"] == "base"]
    out.append("Random（抽選の割合） & " + " & ".join(f"{statistics.mean(num(r[k]) for r in rows) * 100:.0f}\\%" for k in
               ["violation_rate_quadrant", "violation_rate_radial", "violation_rate_scan", "violation_rate_any"]) + " & " +
               " & ".join(fmt(statistics.mean(num(r[k]) for r in rows)) for k in
                          ["balance_quadrant_mean", "balance_radial_mean", "balance_scan_mean"]) + " \\\\")
    for m in BASE[1:]:
        rs = [r for r in DM if r["scenario"] == "base" and r["method"] == m and r["feasible"] == "1"]
        rate = lambda key: statistics.mean(num(r[key]) > 0 for r in rs) * 100
        anyv = statistics.mean((num(r["violation_quadrant"]) + num(r["violation_radial"]) + num(r["violation_scan"])) > 0 for r in rs) * 100
        out.append(f"{LABEL[m]}（設計の割合） & {rate('violation_quadrant'):.0f}\\% & {rate('violation_radial'):.0f}\\% & "
                   f"{rate('violation_scan'):.0f}\\% & {anyv:.0f}\\% & " +
                   " & ".join(fmt(statistics.mean(num(r[k]) for r in rs)) for k in
                              ["balance_quadrant", "balance_radial", "balance_scan"]) + " \\\\")
    out.append("\\bottomrule\n\\end{tabular}\n")


def table_robust(n=12):
    out.append(f"% 表: 条件ごとの平均RMS（N = {n}）")
    conds = [("noise_low", "誤差0.25"), ("nominal", "0.5"), ("noise_high", "1.0"), ("scan_x0", "scan×0"),
             ("scan_x0.5", "×0.5"), ("scan_x2", "×2"), ("scan_x4", "×4")]
    meths = ["poisson", "human", "dopt", "iopt", "cdopt", "ciopt"]
    out.append("\\begin{tabular}{cl" + "r" * len(conds) + "}\n\\toprule")
    out.append("次数 & 手法 & " + " & ".join(c[1] for c in conds) + " \\\\\n\\midrule")
    for o in ORDERS:
        for k, m in enumerate(meths):
            first = f"\\multirow{{{len(meths)}}}{{*}}{{{o}}}" if k == 0 else ""
            vals = [agg(c, "base", m, o, n, "rms_vec_nm_mean") for c, _ in conds]
            out.append(f"{first} & {LABEL[m]} & " + " & ".join(fmt(v) for v in vals) + " \\\\")
        out.append("\\midrule" if o != ORDERS[-1] else "\\bottomrule")
    out.append("\\end{tabular}\n")
    lines = [f"% 要約: 制約付き vs 制約なし（改善率、平均RMSどうし）条件別、N=8/12/19"]
    for o in ORDERS:
        for c, _ in conds:
            parts = []
            for nn in (8, 12, 19):
                p = pair(c, "base", o, nn, "cdopt", "dopt")
                q = pair(c, "base", o, nn, "ciopt", "iopt")
                parts.append(f"N{nn}: CD/D {num(p['improvement_of_means_pct']):+.1f} CI/I {num(q['improvement_of_means_pct']):+.1f}")
            lines.append(f"% HOWA{o} {c}: " + " | ".join(parts))
    out.extend(lines)
    out.append("")


def table_mandatory():
    out.append("% 表: 強制計測shotありの平均RMS")
    ns = [7, 8, 9, 10, 12, 15, 19]
    meths = ["random_f", "human_f", "dopt_aug", "cdopt_naive", "ciopt_naive", "cdopt_aug", "ciopt_aug"]
    out.append("\\begin{tabular}{cr" + "r" * len(meths) + "rr}\n\\toprule")
    out.append("次数 & $N$ & " + " & ".join(LABEL[m] for m in meths) + " & C-D（Fなし） & C-I（Fなし） \\\\\n\\midrule")
    for o in ORDERS:
        for k, n in enumerate(ns):
            cells = []
            for m in meths:
                v = agg("nominal", "mandatory", m, o, n, "rms_vec_nm_mean")
                valid = dm("mandatory", m, o, n, "valid")
                if v != v and dm("mandatory", m, o, n, "feasible") == 1 and valid == 0:
                    cells.append("rank不足")
                elif v != v:
                    cells.append("--")
                else:
                    cells.append(fmt(v))
            cells += [fmt(agg("nominal", "base", m, o, n, "rms_vec_nm_mean")) for m in ("cdopt", "ciopt")]
            first = f"\\multirow{{{len(ns)}}}{{*}}{{{o}}}" if k == 0 else ""
            out.append(f"{first} & {n} & " + " & ".join(cells) + " \\\\")
        out.append("\\midrule" if o != ORDERS[-1] else "\\bottomrule")
    out.append("\\end{tabular}\n")
    lines = ["% 要約: Aug vs Naive の改善率（*: bootstrap CI が 0 より上、-: 0 より下）"]
    for o in ORDERS:
        parts = []
        for n in range(7, 20):
            s = []
            for p, c in (("cdopt_aug", "cdopt_naive"), ("ciopt_aug", "ciopt_naive")):
                r = pair("nominal", "mandatory", o, n, p, c)
                if r is None or num(r["mean_delta_nm"]) != num(r["mean_delta_nm"]):
                    s.append("NA")
                    continue
                mark = "*" if num(r["boot_mean_ci_low_nm"]) > 0 else ("-" if num(r["boot_mean_ci_high_nm"]) < 0 else "")
                s.append(f"{num(r['improvement_of_means_pct']):+.1f}{mark}")
            parts.append(f"N{n}:" + "/".join(s))
        lines.append(f"% HOWA{o}: " + " ".join(parts))
    out.extend(lines)
    out.append("")


def table_reduction():
    out.append("% 表: Humanと同じ平均RMSに必要な最小shot数（強制shotなし）")
    nrefs = [8, 12, 15, 19]
    meths = ["poisson", "dopt", "iopt", "cdopt", "ciopt"]
    out.append("\\begin{tabular}{cr" + "r" * len(meths) + "}\n\\toprule")
    out.append("次数 & Human の $N$（目標RMS） & " + " & ".join(LABEL[m] for m in meths) + " \\\\\n\\midrule")
    for o in ORDERS:
        for k, nref in enumerate(nrefs):
            rows = {r["method"]: r for r in RED if r["scenario"] == "base" and int(r["howa_order"]) == o and
                    r["reference_method"] == "human" and int(r["reference_n_shots"]) == nref and r["target_statistic"] == "mean"}
            if not rows:
                continue
            target = num(next(iter(rows.values()))["target_rms_nm"])
            cells = []
            for m in meths:
                r = rows.get(m)
                req = num(r["required_n_shots"]) if r else float("nan")
                red = num(r["measurement_reduction_pct"]) if r else float("nan")
                cells.append("--" if req != req else f"{req:.0f}（{red:+.0f}\\%）")
            first = f"\\multirow{{{len(nrefs)}}}{{*}}{{{o}}}" if k == 0 else ""
            out.append(f"{first} & {nref}（{target:.2f}\\,nm） & " + " & ".join(cells) + " \\\\")
        out.append("\\midrule" if o != ORDERS[-1] else "\\bottomrule")
    out.append("\\end{tabular}\n")
    lines = ["% 要約: P95目標と、強制shotありでHuman+F基準"]
    for o in ORDERS:
        for scen, ref, ms in (("base", "human", ["poisson", "dopt", "iopt", "cdopt", "ciopt"]),
                              ("mandatory", "human_f", ["poisson_f", "dopt_aug", "cdopt_naive", "ciopt_naive", "cdopt_aug", "ciopt_aug"])):
            for stat in ("mean", "p95"):
                for nref in (12, 19):
                    rows = {r["method"]: r for r in RED if r["scenario"] == scen and int(r["howa_order"]) == o and
                            r["reference_method"] == ref and int(r["reference_n_shots"]) == nref and r["target_statistic"] == stat}
                    lines.append(f"% HOWA{o} {scen} {stat} ref{nref}: " + " ".join(
                        f"{m}:{rows[m]['required_n_shots']}" for m in ms if m in rows))
    out.extend(lines)
    out.append("")


def table_time():
    out.append("% 表: 設計1件の計算時間 [s]（平均 / 最大）")
    meths = [("base", "dopt"), ("base", "iopt"), ("base", "cdopt"), ("base", "ciopt"), ("mandatory", "cdopt_aug"),
             ("mandatory", "ciopt_aug"), ("base", "poisson")]
    out.append("\\begin{tabular}{c" + "r" * len(meths) + "}\n\\toprule")
    out.append("次数 & " + " & ".join(LABEL[m] for _, m in meths) + " \\\\\n\\midrule")
    for o in ORDERS:
        cells = []
        for scen, m in meths:
            ts = [num(r["optimization_time_s"]) for r in DM if r["scenario"] == scen and r["method"] == m and
                  int(r["howa_order"]) == o and num(r["optimization_time_s"]) == num(r["optimization_time_s"])]
            cells.append(f"{statistics.mean(ts):.2f} / {max(ts):.2f}")
        out.append(f"{o} & " + " & ".join(cells) + " \\\\")
    out.append("\\bottomrule\n\\end{tabular}\n")
    lines = ["% 要約: 最良値に到達した初期解の割合（中央値）"]
    for o in ORDERS:
        lines.append(f"% HOWA{o}: " + " ".join(
            f"{m}:{statistics.median(num(r['fraction_starts_at_best']) for r in DM if r['method'] == m and int(r['howa_order']) == o):.2f}"
            for m in ["dopt", "iopt", "cdopt", "ciopt", "cdopt_aug", "ciopt_aug"]))
    timing = (RESULTS / "logs" / "timing_log.csv").read_text(encoding="utf-8")
    lines.append("% timing_log: " + timing.replace("\n", " | "))
    out.extend(lines)
    out.append("")


def table_soft():
    out.append("% 表: soft制約（λ）")
    lams = ["0", "0.02", "0.05", "0.2", "1", "5"]
    out.append("\\begin{tabular}{crl" + "c" * len(lams) + "}\n\\toprule")
    out.append("次数 & $N$ & 基準 & " + " & ".join(f"$\\lambda={l}$" for l in lams) + " \\\\\n\\midrule")
    for o in ORDERS:
        for n in (8, 12, 19):
            for crit in ("D", "I"):
                cells = []
                for lam in lams:
                    rs = [r for r in SOFT if int(r["howa_order"]) == o and int(r["n_shots"]) == n and r["criterion"] == crit
                          and abs(num(r["soft_weight"]) - float(lam)) < 1e-12]
                    eff = "d_efficiency" if crit == "D" else "i_efficiency"
                    cells.append("--" if not rs else f"{num(rs[0]['violation_total']):.0f} / {num(rs[0][eff]):.2f} / {num(rs[0]['rms_vec_mean_nm']):.2f}")
                out.append(f"{o} & {n} & {crit} & " + " & ".join(cells) + " \\\\")
        out.append("\\midrule" if o != ORDERS[-1] else "\\bottomrule")
    out.append("\\end{tabular}\n")


def edge_rms():
    lines = ["% 要約: 外周（partial shotのmark 84点）だけのRMSの平均（waferごとに RMS_all と RMS_interior から算出）"]
    n_all, n_int = 312, 228
    for o in ORDERS:
        rows = read(f"wafer_results_nominal_base_howa{o}.csv")
        acc = defaultdict(list)
        for r in rows:
            a, i = num(r["rms_vec_nm"]), num(r["rms_vec_interior_nm"])
            if a != a:
                continue
            acc[(r["method"], int(r["n_shots"]))].append(math.sqrt(max(0.0, (n_all * a * a - n_int * i * i) / (n_all - n_int))))
        for n in (8, 12, 19):
            lines.append(f"% HOWA{o} N{n}: " + " ".join(f"{m}:{statistics.mean(acc[(m, n)]):.2f}" for m in BASE if (m, n) in acc))
    out.extend(lines)
    out.append("")


def misc():
    lines = ["% その他"]
    for r in SAMPLES:
        lines.append(f"% {r['sample']}: wafer {r['wafer_id']} meanRMS {num(r['mean_rms_over_methods_nm']):.3f} "
                     f"imp {num(r['mean_improvement_pct']):.1f}% minRMS {num(r['min_rms_over_methods_nm']):.3f}")
    rejected = sum(int(r["n_rejected_draws"]) for r in RDS)
    lines.append(f"% Random のrank不足でやり直した抽選の合計: {rejected}")
    invalid = [(r["scenario"], r["method"], r["howa_order"], r["n_shots"], r["feasible"]) for r in DM if r["valid"] != "1"]
    lines.append(f"% 無効な設計（feasible=0 は制約を満たす設計なし、1 は rank 不足）: {invalid}")
    for o in ORDERS:
        for m in ("cdopt", "ciopt"):
            de = [dm("base", m, o, n, "d_efficiency") for n in range(3, 20) if dm("base", m, o, n, "d_efficiency") == dm("base", m, o, n, "d_efficiency")]
            ie = [dm("base", m, o, n, "i_efficiency") for n in range(3, 20) if dm("base", m, o, n, "i_efficiency") == dm("base", m, o, n, "i_efficiency")]
            lines.append(f"% HOWA{o} {m}: D-eff median {statistics.median(de):.3f} [{min(de):.3f}, {max(de):.3f}], "
                         f"I-eff median {statistics.median(ie):.3f} [{min(ie):.3f}, {max(ie):.3f}]")
    out.extend(lines)
    out.append("")


if __name__ == "__main__":
    table_mean_rms()
    table_tail()
    table_paired()
    summary_paired_over_n()
    table_efficiency()
    table_violation()
    table_robust()
    table_mandatory()
    table_reduction()
    table_time()
    table_soft()
    edge_rms()
    misc()
    target = ROOT / "report" / "generated_tables.tex"
    target.write_text("\n".join(out), encoding="utf-8")
    print("\n".join(line for line in out if line.startswith("%")))
    print(f"\n書き出し: {target}")
