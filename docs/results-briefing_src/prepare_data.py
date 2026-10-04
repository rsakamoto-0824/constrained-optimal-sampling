"""評価結果（results/csv）から、説明資料に載せる数値を deck_data.json にまとめる。

スライドとノートの数値はすべてこのファイルから取る（手で書き写さない）。
使い方: python3 prepare_data.py   （リポジトリの results/csv を読み、同じフォルダに deck_data.json を書く）
"""
import csv
import json
import math
import statistics
from pathlib import Path

HERE = Path(__file__).resolve().parent
CSV_DIR = HERE.parent.parent / "results" / "csv"
LOG_DIR = HERE.parent.parent / "results" / "logs"
ORDERS = [3, 4, 5]
BASE = ["random", "poisson", "human", "dopt", "iopt", "cdopt", "ciopt"]
COMPARATORS = ["random", "poisson", "human", "dopt", "iopt"]
N_SUMMARY = range(8, 20)          # 改善率の中央値をとる shot 数（N_min 付近の極端な値を除く）
N_REF = 12                        # 代表の shot 数
N_PARTIAL_MARKS = 84              # partial shot の mark 数（全312点 − 候補shot 228点）
N_ALL_MARKS = 312
N_INTERIOR_MARKS = 228


def read(name):
    with open(CSV_DIR / name, encoding="utf-8") as f:
        return list(csv.DictReader(f))


def num(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return float("nan")


def finite(x):
    return x == x and not math.isinf(x)


AGG = read("aggregated_metrics.csv")
PAIR = read("paired_comparison.csv")
DM = read("design_metrics.csv")
RED = read("shot_reduction.csv")
RDS = read("random_draw_design_summary.csv")
RRS = read("random_draw_residual_summary.csv")
SOFT = read("soft_constraint_study.csv")
FLOOR = read("model_mismatch_floor.csv")
SHOTS = read("shot_candidates.csv")
SEL = read("selected_shots.csv")
NMIN = read("nmin.csv")
SAMPLES = read("appendix_samples.csv")
MULTI = read("multistart_check.csv")

agg_i = {(r["condition"], r["scenario"], r["method"], int(r["howa_order"]), int(r["n_shots"])): r for r in AGG}
dm_i = {(r["scenario"], r["method"], int(r["howa_order"]), int(r["n_shots"])): r for r in DM}
pair_i = {(r["condition"], r["scenario"], int(r["howa_order"]), int(r["n_shots"]), r["proposed_method"], r["comparator_method"]): r for r in PAIR}


def agg(cond, scen, meth, o, n, col="rms_vec_nm_mean"):
    r = agg_i.get((cond, scen, meth, o, n))
    return num(r[col]) if r else float("nan")


def dm(scen, meth, o, n, col):
    r = dm_i.get((scen, meth, o, n))
    return num(r[col]) if r else float("nan")


def pair(cond, scen, o, n, prop, comp):
    return pair_i.get((cond, scen, o, n, prop, comp))


def r3(x):
    return None if not finite(x) else round(x, 3)


def improvement_summary():
    """C-D-opt / C-I-opt の比較手法に対する改善率（平均RMSどうし）の N=8〜19 の中央値と有意な点の数"""
    out = {}
    for o in ORDERS:
        for prop in ("cdopt", "ciopt"):
            for comp in COMPARATORS:
                vals, better, worse = [], 0, 0
                for n in N_SUMMARY:
                    r = pair("nominal", "base", o, n, prop, comp)
                    if r is None or not finite(num(r["mean_delta_nm"])):
                        continue
                    vals.append(num(r["improvement_of_means_pct"]))
                    better += num(r["boot_mean_ci_low_nm"]) > 0
                    worse += num(r["boot_mean_ci_high_nm"]) < 0
                out[f"{o}|{prop}|{comp}"] = {"median": r3(statistics.median(vals)), "min": r3(min(vals)), "max": r3(max(vals)),
                                             "better": better, "worse": worse, "n": len(vals)}
    return out


def interior_summary():
    """wafer内側（候補shotのmark）だけの平均RMSで見た改善率の N=8〜19 の中央値"""
    out = {}
    for o in ORDERS:
        vals = [(1 - agg("nominal", "base", "cdopt", o, n, "rms_vec_interior_nm_mean") /
                 agg("nominal", "base", "dopt", o, n, "rms_vec_interior_nm_mean")) * 100 for n in N_SUMMARY]
        out[str(o)] = r3(statistics.median(vals))
    return out


def edge_rms(o, n, method):
    rows = read(f"wafer_results_nominal_base_howa{o}.csv")
    vals = []
    for r in rows:
        if r["method"] != method or int(r["n_shots"]) != n:
            continue
        a, i = num(r["rms_vec_nm"]), num(r["rms_vec_interior_nm"])
        if finite(a):
            vals.append(math.sqrt(max(0.0, (N_ALL_MARKS * a * a - N_INTERIOR_MARKS * i * i) / N_PARTIAL_MARKS)))
    return statistics.mean(vals)


def main():
    data = {"orders": ORDERS, "n_ref": N_REF}
    data["nmin"] = {r["howa_order"]: {"p": int(r["n_terms"]), "nmin": int(r["n_min"]), "nmax": int(r["n_max"])} for r in NMIN}
    data["floor"] = {str(o): r3(statistics.mean(num(r[f"floor_rms_vec_howa{o}_nm"]) for r in FLOOR)) for o in ORDERS}
    data["mean_rms"] = {f"{o}|{m}|{n}": r3(agg("nominal", "base", m, o, n)) for o in ORDERS for m in BASE for n in range(3, 20)}
    data["improvement"] = improvement_summary()
    data["interior_improvement"] = interior_summary()
    # N=12 の paired comparison
    data["paired_ref"] = {}
    for o in ORDERS:
        for prop in ("cdopt", "ciopt"):
            for comp in COMPARATORS:
                r = pair("nominal", "base", o, N_REF, prop, comp)
                data["paired_ref"][f"{o}|{prop}|{comp}"] = {
                    "imp": r3(num(r["mean_improvement_pct"])), "lo": r3(num(r["boot_improvement_ci_low_pct"])),
                    "hi": r3(num(r["boot_improvement_ci_high_pct"])), "win": r3(num(r["win_rate"])),
                    "delta": r3(num(r["mean_delta_nm"]))}
    # tail と外周・内側（N=12）
    data["tail_ref"] = {}
    for o in ORDERS:
        for m in ("dopt", "iopt", "cdopt", "ciopt", "poisson", "human"):
            data["tail_ref"][f"{o}|{m}"] = {
                "mean": r3(agg("nominal", "base", m, o, N_REF)), "p95w": r3(agg("nominal", "base", m, o, N_REF, "rms_vec_nm_p95")),
                "max": r3(agg("nominal", "base", m, o, N_REF, "max_mag_nm_mean")),
                "interior": r3(agg("nominal", "base", m, o, N_REF, "rms_vec_interior_nm_mean")),
                "edge": r3(edge_rms(o, N_REF, m))}
    # 効率と制約違反
    data["eff_median"] = {}
    for o in ORDERS:
        for m in ("cdopt", "ciopt"):
            de = [dm("base", m, o, n, "d_efficiency") for n in range(3, 20) if finite(dm("base", m, o, n, "d_efficiency"))]
            ie = [dm("base", m, o, n, "i_efficiency") for n in range(3, 20) if finite(dm("base", m, o, n, "i_efficiency"))]
            data["eff_median"][f"{o}|{m}"] = {"d": r3(statistics.median(de)), "i": r3(statistics.median(ie))}
        for m in ("human", "poisson"):
            de = [dm("base", m, o, n, "d_efficiency") for n in range(8, 20)]
            data["eff_median"][f"{o}|{m}"] = {"d": r3(statistics.median(de))}
        rr = [num(r["d_eff_median"]) for r in RDS if r["scenario"] == "base" and int(r["howa_order"]) == o and int(r["n_shots"]) >= 8]
        data["eff_median"][f"{o}|random"] = {"d": r3(statistics.median(rr))}
    viol = {}
    for m in ("poisson", "human", "dopt", "iopt", "cdopt", "ciopt"):
        rs = [r for r in DM if r["scenario"] == "base" and r["method"] == m and r["feasible"] == "1"]
        viol[m] = {k: r3(100 * statistics.mean(num(r[f"violation_{k}"]) > 0 for r in rs)) for k in ("quadrant", "radial", "scan")}
        viol[m]["any"] = r3(100 * statistics.mean((num(r["violation_quadrant"]) + num(r["violation_radial"]) + num(r["violation_scan"])) > 0 for r in rs))
    rs = [r for r in RDS if r["scenario"] == "base"]
    viol["random"] = {k: r3(100 * statistics.mean(num(r[f"violation_rate_{k}"]) for r in rs)) for k in ("quadrant", "radial", "scan", "any")}
    data["violation"] = viol
    # shot 削減（Human 基準、平均RMS）
    data["reduction"] = {}
    for o in ORDERS:
        for nref in (8, 12, 15, 19):
            for r in RED:
                if (r["scenario"] == "base" and int(r["howa_order"]) == o and r["reference_method"] == "human"
                        and int(r["reference_n_shots"]) == nref and r["target_statistic"] == "mean"):
                    data["reduction"][f"{o}|{nref}|{r['method']}"] = r3(num(r["required_n_shots"]))
    for o in ORDERS:
        for r in RED:
            if (r["scenario"] == "mandatory" and int(r["howa_order"]) == o and r["reference_method"] == "human_f"
                    and int(r["reference_n_shots"]) == 19 and r["target_statistic"] == "mean"):
                data["reduction"][f"{o}|19|{r['method']}"] = r3(num(r["required_n_shots"]))
    # scan 成分・計測誤差への頑健性（N=12）
    scan_conds = [("scan_x0", 0.0), ("scan_x0.5", 0.5), ("nominal", 1.0), ("scan_x2", 2.0), ("scan_x4", 4.0)]
    noise_conds = [("noise_low", 0.25), ("nominal", 0.5), ("noise_high", 1.0)]
    data["scan"] = {str(o): [{"scale": s, "imp": r3(num(pair(c, "base", o, N_REF, "cdopt", "dopt")["improvement_of_means_pct"])),
                              "dopt": r3(agg(c, "base", "dopt", o, N_REF)), "cdopt": r3(agg(c, "base", "cdopt", o, N_REF))}
                             for c, s in scan_conds] for o in ORDERS}
    data["noise"] = {str(o): [{"sigma": s, "imp": r3(num(pair(c, "base", o, N_REF, "cdopt", "dopt")["improvement_of_means_pct"]))}
                              for c, s in noise_conds] for o in ORDERS}
    data["scan_n8_howa3_x4"] = r3(num(pair("scan_x4", "base", 3, 8, "cdopt", "dopt")["improvement_of_means_pct"]))
    # 強制計測shot: Augmentation と Naive
    data["aug"] = {}
    for o in ORDERS:
        rows = []
        for n in range(7, 20):
            item = {"n": n}
            for prop, comp, key in (("cdopt_aug", "cdopt_naive", "cd"), ("ciopt_aug", "ciopt_naive", "ci")):
                r = pair("nominal", "mandatory", o, n, prop, comp)
                ok = r is not None and finite(num(r["mean_delta_nm"]))
                item[key] = r3(num(r["improvement_of_means_pct"])) if ok else None
                item[key + "_sig"] = (num(r["boot_mean_ci_low_nm"]) > 0) if ok else None
                item[key + "_worse"] = (num(r["boot_mean_ci_high_nm"]) < 0) if ok else None   # Naive の方が有意に良い
            item["naive_rank_deficient"] = dm("mandatory", "cdopt_naive", o, n, "feasible") == 1 and dm("mandatory", "cdopt_naive", o, n, "valid") == 0
            item["cdopt_aug"] = r3(agg("nominal", "mandatory", "cdopt_aug", o, n))
            item["cdopt_naive"] = r3(agg("nominal", "mandatory", "cdopt_naive", o, n))
            item["cdopt_base"] = r3(agg("nominal", "base", "cdopt", o, n))
            item["dopt_aug"] = r3(agg("nominal", "mandatory", "dopt_aug", o, n))
            rows.append(item)
        data["aug"][str(o)] = rows
    # soft 制約（4次 N=12）
    data["soft"] = [{"crit": r["criterion"], "lam": num(r["soft_weight"]), "viol": int(num(r["violation_total"])),
                     "viol_scan": int(num(r["violation_scan"])), "viol_radial": int(num(r["violation_radial"])),
                     "d_eff": r3(num(r["d_efficiency"])), "i_eff": r3(num(r["i_efficiency"])), "rms": r3(num(r["rms_vec_mean_nm"]))}
                    for r in SOFT if int(r["howa_order"]) == 4 and int(r["n_shots"]) == N_REF]
    # Random 抽選のばらつき（5次 N=12）
    rr = [r for r in RRS if r["condition"] == "nominal" and r["scenario"] == "base" and int(r["howa_order"]) == 5 and int(r["n_shots"]) == N_REF][0]
    data["random_spread"] = {k: r3(num(rr[k])) for k in ("mean_rms_best_draw", "mean_rms_median_over_draws", "mean_rms_p95_over_draws", "mean_rms_worst_draw")}
    # multi-start の確認
    data["multistart"] = {n: {"below": sum(num(r["efficiency_vs_max_starts"]) < 0.9999 for r in MULTI if r["n_starts"] == n),
                              "min": r3(min(num(r["efficiency_vs_max_starts"]) for r in MULTI if r["n_starts"] == n))}
                          for n in ("20", "100", "200")}
    # 計算時間
    timing = {}
    with open(LOG_DIR / "timing_log.csv", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            timing[r["stage"]] = round(num(r["seconds"]) / 60, 1)
    data["timing_min"] = timing
    # 設計1件の計算時間（全シナリオの最適化設計、D・I基準別、秒）と、最良値に届いた初期解の割合
    def criterion_of(method):
        return "I" if "iopt" in method else ("D" if "dopt" in method else None)
    optimized = [r for r in DM if criterion_of(r["method"]) and finite(num(r["optimization_time_s"]))]
    data["design_count"] = len(optimized)
    data["design_time_s"] = {f"{c}|{o}": {"mean": r3(statistics.mean(num(r["optimization_time_s"]) for r in optimized
                                                                     if criterion_of(r["method"]) == c and int(r["howa_order"]) == o)),
                                        "max": r3(max(num(r["optimization_time_s"]) for r in optimized
                                                      if criterion_of(r["method"]) == c and int(r["howa_order"]) == o))}
                             for c in ("D", "I") for o in ORDERS}
    data["start_fraction_median"] = {m: r3(statistics.median(num(r["fraction_starts_at_best"]) for r in DM
                                                             if r["scenario"] == "base" and r["method"] == m))
                                     for m in ("dopt", "iopt", "cdopt", "ciopt")}
    data["multistart_conditions"] = sum(1 for r in MULTI if r["n_starts"] == "20")
    # ウェーハ図（候補shotと、HOWA 4次 N=12 の設計）
    data["shots"] = [{"id": int(r["shot_id"]), "x": num(r["x_mm"]), "y": num(r["y_mm"]),
                      "cand": r["is_candidate"] in ("1", "true", "True"), "region": r["radial_region_name"],
                      "scan": r["scan_direction"], "mand": r["is_mandatory"] in ("1", "true", "True")} for r in SHOTS]
    designs = {}
    for r in SEL:
        if int(r["howa_order"]) == 4 and int(r["n_shots"]) == N_REF:
            designs.setdefault(f"{r['scenario']}|{r['method']}", []).append(int(r["shot_id"]))
    data["designs_howa4_n12"] = designs
    data["design_balance_howa4_n12"] = {m: {k: dm("base", m, 4, N_REF, k) for k in ("balance_quadrant", "balance_radial", "balance_scan", "n_inner", "n_middle", "n_outer", "n_up", "n_down")}
                                        for m in BASE}
    data["samples"] = [{"name": r["sample"], "wafer": int(r["wafer_id"])} for r in SAMPLES]
    # 典型例（Sample 1）の waferごとの値（Appendix と同じ HOWA 4次・N=12）
    typical = int(SAMPLES[0]["wafer_id"])
    data["typical_wafer"] = {r["method"]: {"rms": r3(num(r["rms_vec_nm"])), "max": r3(num(r["max_mag_nm"]))}
                             for r in read("wafer_results_nominal_base_howa4.csv")
                             if int(r["wafer_id"]) == typical and int(r["n_shots"]) == N_REF}
    (HERE / "deck_data.json").write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    print("deck_data.json を書き出しました")


if __name__ == "__main__":
    main()
