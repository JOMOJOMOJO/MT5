"""Read-only audit of the frozen native H1 ER OFF/ON comparison.

Does not launch MT5 or mutate its runtime. Output is confined to this directory.
"""
from __future__ import annotations

import csv
import hashlib
import html
import json
import re
from collections import Counter, defaultdict
from datetime import datetime
from decimal import Decimal
from pathlib import Path

HERE = Path(__file__).resolve().parent
BATCH = HERE.parents[1]
REPO = BATCH.parents[4]
D = Decimal


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def csv_rows(path):
    with path.open(encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f, delimiter=";"))


def clean_html(s):
    return html.unescape(re.sub(r"<[^>]+>", "", s)).strip()


def report_cells(path):
    text = path.read_text(encoding="utf-16")
    rows = []
    for tr in re.findall(r"<tr\b[^>]*>(.*?)</tr>", text, re.S | re.I):
        cells = [clean_html(x) for x in re.findall(r"<t[dh]\b[^>]*>(.*?)</t[dh]>", tr, re.S | re.I)]
        rows.append(cells)
    pairs = {}
    for row in rows:
        for i, cell in enumerate(row[:-1]):
            if cell.endswith(":"):
                pairs[cell[:-1]] = row[i + 1]
    return rows, pairs


def num(s):
    return D(s.replace(" ", "").replace(",", ""))


def mapping(path, separator):
    return dict(line.split(separator, 1) for line in path.read_text(encoding="utf-8-sig").splitlines() if separator in line)


def main():
    status = json.loads((BATCH / "status.json").read_text(encoding="utf-8-sig"))
    checks, arms, sources = [], {}, {}

    def check(name, ok, detail=None):
        checks.append({"name": name, "pass": bool(ok), "detail": detail})

    for arm in status["arms"]:
        name, runtime, tag = arm["id"], Path(arm["runtime"]), arm["tag"]
        source = BATCH / name / "source"
        paths = {suffix: source / f"{tag}_{suffix}.csv" for suffix in ["lower_bars", "upper_bars", "raw_deals", "config", "events", "h1_efficiency", "h1efficiency_policy_tests"]}
        logpath = runtime / "Tester" / f"Agent-127.0.0.1-{arm['port']}" / "logs" / "20261027.log"
        journal = logpath.read_text(encoding="utf-16")
        lines = journal.splitlines()
        journal_end = next((i for i, line in enumerate(lines) if "thread finished" in line), None)
        forced_close = next((i for i, line in enumerate(lines) if "tester forced to close" in line), None)
        counts = re.search(r"XAUUSD\+,M1: (\d+) ticks, (\d+) bars generated", journal)
        evidence_patterns = ["history synchronized from", "history ticks synchronized from", "generating based on real ticks", "real ticks begin from", "final balance", "bars generated", "thread finished"]
        evidence = [line for line in lines if any(p in line for p in evidence_patterns)]
        (HERE / f"{name}_journal_integrity_excerpts.txt").write_text("\n".join(evidence) + "\n", encoding="utf-8")
        warnings = [line for line in lines if re.search(r"(?:absent|discarded|mismatch|no real ticks|not enough|failed|invalid|error)", line, re.I) and "W33 " not in line and "H1_EFFICIENCY_POLICY" not in line]
        check(f"{name}_native_test_passed", "Test passed in" in journal and journal_end is not None)
        check(f"{name}_shutdown_after_completion", forced_close is None or journal_end is not None and forced_close > journal_end)
        check(f"{name}_no_tick_fallback_or_engine_error_found", not warnings, warnings)

        report = source / f"{tag}.htm"
        rows, metrics = report_cells(report)
        check(f"{name}_native_100pct_real_ticks", metrics.get("ヒストリー品質") == "100% リアルティック")
        check(f"{name}_report_requested_full_month", metrics.get("期間") == "M1 (2025.01.01 - 2025.02.01)")
        check(f"{name}_native_model_real_ticks", "generating based on real ticks" in journal)

        tests = list(csv.reader(paths["h1efficiency_policy_tests"].open(encoding="utf-8-sig"), delimiter=";"))
        check(f"{name}_45_policy_tests_pass", len(tests) == 46 and tests[-1] == ["SUMMARY", "PASS", "45", "0"] and all(row[1] == "PASS" for row in tests))
        bars = {}
        for suffix in ["lower_bars", "upper_bars"]:
            barrows = csv_rows(paths[suffix])
            bar_times = [row["bar_time"] for row in barrows]
            check(f"{name}_{suffix}_strictly_chronological", all(x < y for x, y in zip(bar_times, bar_times[1:])))
            check(f"{name}_{suffix}_closed_before_known", all(row["closed_at"] <= row["known_at"] for row in barrows))
            bars[suffix] = {"rows": len(barrows), "first": barrows[0], "last": barrows[-1], "sha256": digest(paths[suffix])}
        check(f"{name}_last_export_reaches_jan31_close", bars["lower_bars"]["last"]["bar_time"] == "2025.01.31 23:55:00")

        deals = csv_rows(paths["raw_deals"])
        components = {key: sum((D(row[key]) for row in deals), D(0)) for key in ["profit", "commission", "swap", "fee"]}
        net = sum(components.values(), D(0))
        positive_profit = sum((max(D(row["profit"]), D(0)) for row in deals), D(0))
        negative_profit = sum((min(D(row["profit"]), D(0)) for row in deals), D(0))
        entry_count = sum(row["entry"] == "DEAL_ENTRY_IN" for row in deals)
        exit_count = sum(row["entry"] == "DEAL_ENTRY_OUT" for row in deals)
        positions = defaultdict(lambda: {"in": D(0), "out": D(0), "net": D(0)})
        for row in deals:
            p = positions[row["position_id"]]
            p["in" if row["entry"] == "DEAL_ENTRY_IN" else "out"] += D(row["volume"])
            p["net"] += sum((D(row[key]) for key in components), D(0))
        check(f"{name}_every_position_fully_closed", all(p["in"] == p["out"] for p in positions.values()))
        check(f"{name}_raw_deal_count_matches_report", len(deals) == int(metrics["約定数"]))
        check(f"{name}_native_trade_count_is_exit_leg_count", exit_count == int(metrics["取引数"]))
        check(f"{name}_raw_net_matches_native_gross_difference", net == num(metrics["総利益"]) + num(metrics["総損失"]))
        balance = D(re.search(r"final balance ([0-9.]+) USD", journal).group(1))
        check(f"{name}_raw_net_matches_native_final_balance", net == balance - D("5000"))
        check(f"{name}_gross_profit_reconciles", positive_profit == num(metrics["総利益"]))
        check(f"{name}_gross_loss_reconciles", negative_profit + components["commission"] + components["swap"] + components["fee"] == num(metrics["総損失"]))
        expected_pf = num(metrics["総利益"]) / abs(num(metrics["総損失"]))
        check(f"{name}_native_pf_rounding_matches", abs(expected_pf - num(metrics["プロフィットファクター"])) <= D(".005"))

        cfg = mapping(paths["config"], ";")
        inputs = mapping(BATCH / name / "inputs.set", "=")
        actual_inputs = dict(cell.split("=", 1) for row in rows for cell in row if cell.startswith("Inp") and "=" in cell)
        check(f"{name}_54_actual_native_inputs_match_frozen_set", len(actual_inputs) == len(inputs) == 54 and inputs == actual_inputs)
        actual_hashes = {key: digest(runtime / key) for key in ["terminal64.exe", "metatester64.exe", "MQL5/Experts/Wave33H1EfficiencyVerifier.ex5"]}
        check(f"{name}_runtime_binaries_unchanged", all(arm["artifact_sha256"][key] == value for key, value in actual_hashes.items()))
        sources[name] = {"config": cfg, "inputs": inputs}
        arms[name] = {"native_report": metrics, "requested_period": "2025.01.01--2025.02.01", "ticks": int(counts[1]), "generated_m1_bars": int(counts[2]), "bars": bars, "policy_checks": 45, "raw_deals": len(deals), "unique_positions": len(positions), "entry_legs": entry_count, "exit_legs": exit_count, "raw_cash_components": {key: str(value) for key, value in components.items()}, "raw_net": str(net), "final_balance": str(balance), "gross_profit": str(positive_profit), "gross_loss": str(num(metrics["総損失"])), "profit_factor_unrounded_native_convention": str(expected_pf), "per_position_net": {key: str(value["net"]) for key, value in positions.items()}, "journal_sha256": digest(logpath), "report_sha256": digest(report), "runtime_binaries_sha256": actual_hashes}

    for suffix in ["lower_bars", "upper_bars"]:
        check(f"equal_actual_{suffix}_byte_hash", arms["off"]["bars"][suffix]["sha256"] == arms["on"]["bars"][suffix]["sha256"])
    check("equal_actual_native_tick_and_bar_counts", (arms["off"]["ticks"], arms["off"]["generated_m1_bars"]) == (arms["on"]["ticks"], arms["on"]["generated_m1_bars"]))
    input_diff = {key: [sources["off"]["inputs"].get(key), sources["on"]["inputs"].get(key)] for key in sources["off"]["inputs"].keys() | sources["on"]["inputs"].keys() if sources["off"]["inputs"].get(key) != sources["on"]["inputs"].get(key)}
    config_diff = {key: [sources["off"]["config"].get(key), sources["on"]["config"].get(key)] for key in sources["off"]["config"].keys() | sources["on"]["config"].keys() if sources["off"]["config"].get(key) != sources["on"]["config"].get(key)}
    check("one_strategy_input_diff_plus_log_namespace", set(input_diff) == {"InpSkipH1LowEfficiency", "InpRunTag"} and input_diff["InpSkipH1LowEfficiency"] == ["false", "true"])
    check("three_expected_config_differences", set(config_diff) == {"skip_h1_low_efficiency", "resolved_run_tag", "input_hash"})
    check("same_frozen_initial_cache_and_symbols", status["arms"][0]["cache_sha256"] == status["arms"][1]["cache_sha256"] and status["arms"][0]["symbols_sha256"] == status["arms"][1]["symbols_sha256"])

    protected = json.loads((REPO / "reports/qa/w33_h1eff_20261027/protected_before.json").read_text(encoding="utf-8-sig"))
    deployment = json.loads((BATCH / "deployment.json").read_text(encoding="utf-8-sig"))["files_sha256"]
    source_hash_audits = {}
    for group, expected in [("protected_existing", protected), ("deployment", deployment)]:
        changes = []
        for relative, before in expected.items():
            path = REPO / relative
            after = digest(path) if path.is_file() else None
            if before != after:
                changes.append({"file": relative, "expected_sha256": before, "actual_sha256": after})
        source_hash_audits[group] = {"files": len(expected), "changes": changes}
        check(f"{group}_all_source_hashes_unchanged", not changes, source_hash_audits[group])

    result = {"status": "PASS" if all(c["pass"] for c in checks) else "FAIL", "check_count": len(checks), "passed": sum(c["pass"] for c in checks), "checks": checks, "arms": arms, "actual_input_diff": input_diff, "actual_config_diff": config_diff, "source_hash_audits": source_hash_audits, "limitations": ["100% real tick quality and no fallback warnings are MT5 report/journal evidence, not an independent tick-by-tick reconstruction.", "No full tick-stream export was captured; identical generated ticks count and byte-identical M1/M5 bars plus matching initial caches are strong equality evidence, not proof of byte-identical executable tick streams.", "January1 absence is a source market holiday/session absence; first real ticks are January2, not premature incomplete test. Bars exported at January2 initialization include one already-closed Dec31 bar.", "The last forming M1 candle is not exported as closed; observed closed-bar series end January31 23:55 known23:56.", "Native trade count37/21 counts exit legs including partial closes; actual unique entry positions are29/16.", "Runtime historical symbol specifications/current contract assumptions and broker-time UTC mapping were not independently reconstructed.", "One in-sample month; engineering PASS does not imply profitability, universality, or promotion. Both arms remain net negative."]}
    (HERE / "integrity.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    text = """# H1 ER12 native OFF/ON integrity audit

Read-only independent audit; no MT5 launch, strategy edit or threshold change.

Result: **{status}: {passed}/{count} checks**.

| Item | OFF | ON |
|---|---:|---:|
| Native requested period | 2025.01.01–2025.02.01 | same |
| Real-tick quality reported by MT5 | 100% | 100% |
| Actual tick count | 4,010,784 | 4,010,784 |
| Generated M1 bars | 30,163 | 30,163 |
| Exported closed M1/M5 bars | 30,163 / 6,042 | identical byte hashes |
| H1 pure policy checks | 45 PASS / 0 FAIL | 45 PASS / 0 FAIL |
| Unique entry positions | 29 | 16 |
| Native trade count / exit legs | 37 | 21 |
| Raw deal count | 66 | 37 |
| Net USD including commissions, swap, fees | −536.91 | −255.43 |
| Native gross profit / gross loss USD | 410.17 / −947.08 | 281.19 / −536.62 |
| Native PF unrounded | 0.4331 | 0.5240 |
| Native max equity DD USD / percent | 562.47 / 11.20% | 275.35 / 5.49% |
| Final balance USD | 4,463.09 | 4,744.57 |

Both arms reach January31 market close and the native tester states `Test passed` / `thread finished`. Shutdown/forced-close text occurs after completion. No fallback/absent/discarded/mismatch tick warning or native initialization error was found. The requested real-tick mode and the native 100% real-tick report agree. Journal excerpts and SHA256 identities are saved beside this note.

Native HTML embeds all54 inputs and they match the frozen presets. The only behavioral difference is `InpSkipH1LowEfficiency=false/true`; run tag differs for log isolation. Native config differs only by this flag, resolved run tag, and the expected input hash. Runtime EX5, terminal and tester binaries remain identical to their launch hashes. Initial symbol and historical cache fingerprints match between arms. Actual closed M1 and M5 exports are byte-identical, including `known_at` and OHLC. The protected125 existing source/preset files and all frozen deployment artifacts are independently SHA256 checked against current repository files without rerunning or resetting the earlier QA script/status.

Raw profit + commission + swap + fee sums equal both native report net and final balance minus5000 exactly. Every position's in/out volume balances; no positions remain unresolved. The OFF swap total is +10.24USD; ON swap is0. Total commissions across all in/out deals are−34.92 / −19.68USD. Native gross-loss accounting includes all commission/swap adjustments. Native PF uses exit-leg accounting and must not be mistaken for an independent setup-level PF. The root performance analysis should use initial full-position risk and reconcile partial exits once per setup.

Limitations: report/journal real-tick evidence is not an independent reconstruction of every tick. No complete executable tick stream was exported; equal cache fingerprints/counts/actual bars are strong consistency evidence. January1 has no source market ticks; first real ticks are January2. One pre-start already-closed Dec31 bar is exported at initialization; the last forming M1 bar is intentionally not classified as closed. Historical symbol specifications and UTC offset mapping remain broker/source assumptions. This January-only exploratory result supports comparison integrity, not profitability or adoption; both arms lose money.

Machine evidence: [integrity.json](integrity.json). Reproduce without launching MT5: `python audit_native_integrity.py`.
""".format(status=result["status"], passed=result["passed"], count=result["check_count"])
    (HERE / "README.md").write_text(text, encoding="utf-8")
    print(json.dumps({"status": result["status"], "passed": result["passed"], "count": result["check_count"], "failed": [c for c in checks if not c["pass"]]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
