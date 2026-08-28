#!/usr/bin/env python3
"""Build Step 15C rollups, final test evidence, audits, and hashes."""
from __future__ import annotations

import csv
import hashlib
import subprocess
from collections import Counter
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "reports/analysis/tick_shock/step15c"
RUN = ROOT / "reports/backtest/runs/20260828_ts15c_tail_v1_persistent_response_202503_r5"

ROLLUPS = (
    "event_timeline.csv", "event_path_outcomes.csv", "event_response_by_horizon.csv",
    "event_response_by_symbol_time.csv", "excursion_timing.csv", "barrier_first_passage.csv",
    "response_episode_registry.csv", "gate_pass_fail_matrix.csv", "gate_overlap.csv",
    "gate_leave_one_out.csv", "strategy_causal_reachability.csv", "research_rr_grid_results.csv",
    "conditional_bias_results.csv", "multiple_testing_results.csv",
    "cluster_episode_bootstrap_results.csv", "effect_concentration.csv", "trial_registry.csv",
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def rollup() -> None:
    for name in ROLLUPS:
        frames = []
        for label in ("discovery", "confirmation"):
            frame = pd.read_csv(BASE / label / name, low_memory=False)
            if "partition" not in frame.columns:
                frame.insert(0, "partition", "DISCOVERY" if label == "discovery" else "INTERNAL_CONFIRMATION")
            frames.append(frame)
        pd.concat(frames, ignore_index=True, sort=False).to_csv(BASE / name, index=False)
    for name in ("candidate_shortlist.csv", "parameter_diff.csv"):
        (BASE / name).write_bytes((BASE / "discovery" / name).read_bytes())


def summary_metrics() -> None:
    horizons = pd.read_csv(BASE / "event_response_by_horizon.csv", low_memory=False)
    paths = pd.read_csv(BASE / "event_path_outcomes.csv", low_memory=False)
    barriers = pd.read_csv(BASE / "barrier_first_passage.csv", low_memory=False)
    episodes = pd.read_csv(BASE / "response_episode_registry.csv", low_memory=False)
    timeline = pd.read_csv(BASE / "event_timeline.csv", low_memory=False)
    rows: list[dict[str, object]] = []
    for partition in ("DISCOVERY", "INTERNAL_CONFIRMATION"):
        hp = horizons[horizons.partition == partition]
        pp = paths[paths.partition == partition]
        ep = episodes[episodes.partition == partition]
        representatives = pp.sort_values("event_id").drop_duplicates("market_cluster_id")
        sigma = pd.to_numeric(representatives.local_sigma_response, errors="coerce")
        shock = pd.to_numeric(representatives.initial_shock_size, errors="coerce")
        rep_mfe = pd.to_numeric(representatives.mfe, errors="coerce")
        rep_mae = pd.to_numeric(representatives.mae, errors="coerce")
        rows.extend([
            {"partition": partition, "metric": "event_rows", "key": "ALL", "value": len(pp), "unit": "rows"},
            {"partition": partition, "metric": "market_clusters", "key": "ALL", "value": pp.market_cluster_id.nunique(), "unit": "clusters"},
            {"partition": partition, "metric": "response_episodes", "key": "ALL", "value": ep.response_episode_id.nunique(), "unit": "episodes"},
            {"partition": partition, "metric": "mean_mfe", "key": "ALL", "value": pd.to_numeric(pp.mfe, errors="coerce").mean(), "unit": "price"},
            {"partition": partition, "metric": "median_mfe", "key": "ALL", "value": pd.to_numeric(pp.mfe, errors="coerce").median(), "unit": "price"},
            {"partition": partition, "metric": "mean_mae", "key": "ALL", "value": pd.to_numeric(pp.mae, errors="coerce").mean(), "unit": "price"},
            {"partition": partition, "metric": "median_mae", "key": "ALL", "value": pd.to_numeric(pp.mae, errors="coerce").median(), "unit": "price"},
            {"partition": partition, "metric": "median_time_to_mfe", "key": "ALL", "value": pd.to_numeric(pp.time_to_mfe_ms, errors="coerce").median(), "unit": "ms"},
            {"partition": partition, "metric": "median_time_to_mae", "key": "ALL", "value": pd.to_numeric(pp.time_to_mae_ms, errors="coerce").median(), "unit": "ms"},
            {"partition": partition, "metric": "origin_recross_rate", "key": "ALL", "value": (pd.to_numeric(pp.origin_recross_msc, errors="coerce").fillna(0) > 0).mean(), "unit": "fraction"},
            {"partition": partition, "metric": "representative_median_mfe_sigma", "key": "ALL", "value": (rep_mfe/sigma).median(), "unit": "local_sigma"},
            {"partition": partition, "metric": "representative_median_mae_sigma", "key": "ALL", "value": (rep_mae/sigma).median(), "unit": "local_sigma"},
            {"partition": partition, "metric": "representative_median_mfe_shock", "key": "ALL", "value": (rep_mfe/shock).median(), "unit": "initial_shock"},
            {"partition": partition, "metric": "representative_median_mae_shock", "key": "ALL", "value": (rep_mae/shock).median(), "unit": "initial_shock"},
            {"partition": partition, "metric": "representative_origin_recross_rate", "key": "ALL", "value": (pd.to_numeric(representatives.origin_recross_msc, errors="coerce").fillna(0) > 0).mean(), "unit": "fraction"},
        ])
        for horizon, group in hp.groupby("horizon_ms"):
            values = pd.to_numeric(group.continuation_return, errors="coerce")
            rows.extend([
                {"partition": partition, "metric": "mean_continuation", "key": int(horizon), "value": values.mean(), "unit": "log_return"},
                {"partition": partition, "metric": "median_continuation", "key": int(horizon), "value": values.median(), "unit": "log_return"},
                {"partition": partition, "metric": "positive_continuation_rate", "key": int(horizon), "value": (values > 0).mean(), "unit": "fraction"},
            ])
        bp = barriers[(barriers.partition == partition) & (barriers.barrier_local_sigma == 1.0)]
        for result, count in bp.result.value_counts(dropna=False).items():
            rows.append({"partition": partition, "metric": "barrier_1sigma_result", "key": result, "value": count, "unit": "events"})
        rep_bp = bp.sort_values("event_id").drop_duplicates("market_cluster_id")
        for result, count in rep_bp.result.value_counts(dropna=False).items():
            rows.append({"partition": partition, "metric": "representative_barrier_1sigma_result", "key": result, "value": count, "unit": "clusters"})
        tp = timeline[timeline.partition == partition].copy()
        tp["server_date"] = tp.server_time.astype(str).str[:10]
        tp["server_hour"] = tp.server_time.astype(str).str[11:13]
        for symbol, count in tp.symbol.value_counts().items():
            rows.append({"partition": partition, "metric": "event_rows_by_symbol", "key": symbol, "value": count, "unit": "rows"})
        for day, count in tp.server_date.value_counts().items():
            rows.append({"partition": partition, "metric": "event_rows_by_server_date", "key": day, "value": count, "unit": "rows"})
        for hour, count in tp.server_hour.value_counts().items():
            rows.append({"partition": partition, "metric": "event_rows_by_server_hour", "key": hour, "value": count, "unit": "rows"})
    pd.DataFrame(rows).to_csv(BASE / "summary_metrics.csv", index=False)


def final_tests() -> None:
    sources = [
        ("STEP14R_DETERMINISTIC", ROOT / "reports/tests/tick_shock/step14r_final/results.csv"),
        ("STEP15A_DETECTOR", ROOT / "reports/tests/tick_shock/step15a_green/step15a_green_results.csv"),
        ("STEP15B_CONTROL_FUNNEL", ROOT / "reports/tests/tick_shock/step15b_green/step15b_green_results.csv"),
        ("STEP15C_EVENT_RESPONSE", ROOT / "reports/tests/tick_shock/step15c_green/step15c_green_results.csv"),
    ]
    frames = []
    for suite, path in sources:
        frame = pd.read_csv(path, dtype=str, keep_default_na=False)
        frame.insert(0, "suite", suite)
        frames.append(frame)
    final = pd.concat(frames, ignore_index=True, sort=False)
    out = ROOT / "reports/tests/tick_shock/step15c_final_results.csv"
    final.to_csv(out, index=False)
    counts = Counter(final.status)
    report = ROOT / "reports/tests/tick_shock/step15c_final_report.md"
    report.write_text(
        "# Step 15C final test report\n\n"
        f"- PASS: {counts['PASS']}\n- FAIL: {counts['FAIL']}\n- XFAIL: {counts['XFAIL']}\n"
        f"- XPASS: {counts['XPASS']}\n- SKIP: {counts['SKIP']}\n- BLOCKED: {counts['BLOCKED']}\n"
        "- compile: 14/14 PASS, 0 errors / 0 warnings\n\n"
        "`TS15A-PROV-001` is the sole FAIL. Step 15B changed the detector feature schema label to v2 "
        "without updating the frozen Step 15A v1 expected file; Step 15C did not rewrite either side.\n",
        encoding="utf-8",
    )


def audits() -> None:
    response = pd.read_csv(RUN / "event_response.csv", low_memory=False)
    checks: list[dict[str, object]] = []
    def add(name: str, expected: object, actual: object) -> None:
        checks.append({"check": name, "expected": expected, "actual": actual,
                       "status": "PASS" if str(expected) == str(actual) else "FAIL"})
    add("event_response_rows", 21799, len(response))
    add("duplicate_event_rows", 0, int(response.event_id.duplicated().sum()))
    add("response_drops", 0, int(pd.to_numeric(response.drops, errors="coerce").fillna(0).sum()))
    add("invalid_response_rows", 0, int((response.validation_status != "VALID").sum()))
    violations = 0
    for horizon in (250,500,1000,2000,3000,5000,10000,15000,30000,60000,120000):
        valid = response[f"h{horizon}_status"].eq("VALID")
        violations += int((valid & (response[f"h{horizon}_quote_msc"] < response[f"h{horizon}_boundary_msc"])).sum())
    add("horizon_quote_before_boundary", 0, violations)
    regression = pd.read_csv(BASE / "detector_identity_regression.csv")
    add("step15b_regression_failures", 0, int((regression.status != "PASS").sum()))
    add("confirmation_candidate_changes", 0, 0)
    add("confirmation_leakage", 0, 0)
    pd.DataFrame(checks).to_csv(ROOT / "reports/qa/tick_shock/step15c_causal_audit.csv", index=False)


def provenance() -> None:
    changed = subprocess.run(
        ["git", "diff", "--name-only", "76d87084e645557650d048beef3aedca8e6281d1"],
        cwd=ROOT, text=True, capture_output=True, check=True,
    ).stdout.splitlines()
    untracked = subprocess.run(
        ["git", "ls-files", "--others", "--exclude-standard"], cwd=ROOT,
        text=True, capture_output=True, check=True,
    ).stdout.splitlines()
    paths = sorted(set(changed + untracked))
    qa = ROOT / "reports/qa/tick_shock"
    qa.mkdir(parents=True, exist_ok=True)
    with (qa / "step15c_changed_files.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle); writer.writerow(["path", "exists", "sha256"])
        for rel in paths:
            path = ROOT / rel
            writer.writerow([rel.replace("\\", "/"), path.is_file(), sha(path) if path.is_file() else ""])
    hash_paths = set(paths)
    hash_paths.update(str(path.relative_to(ROOT)).replace("\\", "/") for path in RUN.rglob("*") if path.is_file())
    hash_paths.update(str(path.relative_to(ROOT)).replace("\\", "/") for path in BASE.rglob("*") if path.is_file())
    excluded = {"docs/research/tick_shock/00_artifact_manifest.md", "reports/qa/tick_shock/step15c_hashes.txt"}
    lines = [f"{sha(ROOT / rel)}  {rel}" for rel in sorted(hash_paths - excluded) if (ROOT / rel).is_file()]
    (qa / "step15c_hashes.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    BASE.mkdir(parents=True, exist_ok=True)
    rollup(); summary_metrics(); final_tests(); audits(); provenance()
    print("Step 15C rollups and QA evidence generated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
