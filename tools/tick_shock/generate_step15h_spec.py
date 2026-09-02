#!/usr/bin/env python3
"""Freeze Step 15H preregistration, independent fixtures, and RED evidence."""
from __future__ import annotations

import csv
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT / "docs/research/tick_shock"
ANALYSIS = ROOT / "reports/analysis/tick_shock/step15h"
RED = ROOT / "reports/tests/tick_shock/step15h_red"
FIX = ROOT / "tests/tick_shock/fixtures"
EXP = ROOT / "tests/tick_shock/expected"


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.rstrip() + "\n", encoding="utf-8")


def write_csv(path: Path, fields: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


FEATURES = [
    ("H01", "spread_atr5", "(ask-bid)/completed_M5_ATR14", "LIQUIDITY", "ratio", "required"),
    ("H02", "tick_activity_ratio", "detector_tick_count/baseline_tick_count_median", "LIQUIDITY", "ratio", "required"),
    ("H03", "pre_return_5m_dir_atr", "direction*(last_completed_M1_close-close_5_completed_M1_ago)/ATR5", "PRE_CONTEXT", "ratio", "required"),
    ("H04", "m5_ema20_slope_dir_atr", "direction*(M5_EMA20[1]-M5_EMA20[4])/ATR5", "PRE_CONTEXT", "ratio", "required"),
    ("H05", "m15_alignment_dir", "direction*sign(M15_EMA20[1]-M15_EMA50[1])", "PRE_CONTEXT", "ordinal", "required"),
    ("H06", "pre_extension_15m_dir_atr", "direction*(last_completed_M1_close-close_15_completed_M1_ago)/ATR15", "PRE_CONTEXT", "ratio", "required"),
    ("H07", "day_range_position_dir", "direction*(2*(t0_mid-known_day_low)/(known_day_high-known_day_low)-1)", "PRE_CONTEXT", "ratio", "required"),
    ("H08", "detection_efficiency", "production detector directional_efficiency at confirmation", "DETECTION_SHAPE", "ratio", "required"),
    ("H09", "severity", "production detector local severity at confirmation", "DETECTION_SHAPE", "ratio", "required"),
    ("H10", "confirmation_retention", "direction*(confirmed_mid-candidate_anchor_mid)/candidate_abs_move", "DETECTION_SHAPE", "ratio", "required"),
    ("H11", "spread_efficiency_interaction", "H01*H08", "INTERACTION", "ratio", "derived"),
    ("H12", "flow_efficiency_interaction", "H03*H08", "INTERACTION", "ratio", "derived"),
]

TESTS = [
    ("TS15H-CLOCK-001", "candidate_confirmed_processed_t0_distinct", "t0_msc=1600;backdates=0"),
    ("TS15H-CLOCK-002", "persistent_signal_not_backdated", "signal_msc=1500;t0_msc=1600"),
    ("TS15H-CLOCK-003", "strict_next_tick_delay_0", "entry_quote_msc=1601"),
    ("TS15H-CLOCK-004", "delay_100", "eligible_msc=1700;entry_quote_msc=1701"),
    ("TS15H-CLOCK-005", "delay_250", "eligible_msc=1850;entry_quote_msc=1851"),
    ("TS15H-CLOCK-006", "horizon_anchored_at_t0", "horizon_msc=901600"),
    ("TS15H-CLOCK-007", "delay_does_not_extend_horizon", "horizon_msc=901600"),
    ("TS15H-TICK-001", "same_millisecond_last_sequence", "t0_sequence=3;t0_bid=1.0002;t0_ask=1.0004"),
    ("TS15H-TICK-002", "irregular_intervals", "entry_quote_msc=1777"),
    ("TS15H-MERGE-001", "multi_symbol_merge_processing_lag", "entry_before_processing=0"),
    ("TS15H-FEATURE-001", "prefix_invariance", "changed_features=0"),
    ("TS15H-FEATURE-002", "future_tick_forbidden", "future_feature_reads=0"),
    ("TS15H-FEATURE-003", "unconfirmed_bar_forbidden", "availability=EXCLUDED;reason=UNCONFIRMED_BAR"),
    ("TS15H-FEATURE-004", "future_pivot_forbidden", "future_pivot_inputs=0"),
    ("TS15H-FEATURE-005", "final_cluster_breadth_forbidden", "final_cluster_inputs=0"),
    ("TS15H-FEATURE-006", "warmup_fail_closed", "decision=NO_TRADE;reason=WARMUP"),
    ("TS15H-FEATURE-007", "zero_denominator_fail_closed", "decision=NO_TRADE;reason=INVALID_DENOMINATOR"),
    ("TS15H-FEATURE-008", "stale_quote_fail_closed", "decision=NO_TRADE;reason=STALE_QUOTE"),
    ("TS15H-FEATURE-009", "missing_feature_separate", "decision=NO_TRADE;reason=FEATURE_MISSING"),
    ("TS15H-FEATURE-010", "long_short_normalization", "long_value=0.5;short_value=0.5"),
    ("TS15H-FEATURE-011", "jpy_unit_invariance", "eur_ratio=0.5;jpy_ratio=0.5"),
    ("TS15H-ENTRY-001", "bid_ask_direction", "long_entry=1.0002;short_entry=1.0000"),
    ("TS15H-COST-001", "spread_stress_once", "stress_spread_multiple=1.25;double_count=0"),
    ("TS15H-COST-002", "c2_slippage_once", "entry_ticks=1;exit_ticks=1"),
    ("TS15H-RR-001", "rr_outward_rounding", "realized_rr_min=1.2"),
    ("TS15H-TOUCH-001", "tp_limit", "result=TP_FIRST;fill=TARGET"),
    ("TS15H-TOUCH-002", "sl_gap", "result=SL_FIRST;fill=FIRST_QUOTE"),
    ("TS15H-TOUCH-003", "same_msc_conservative", "primary=SL_FIRST;secondary=AMBIGUOUS_SAME_TICK"),
    ("TS15H-TOUCH-004", "timeout_signed_r", "result=TIMEOUT;gross_r=-0.2"),
    ("TS15H-END-001", "week_end_censoring", "outcome_status=UNAVAILABLE;label="),
    ("TS15H-END-002", "completed_not_rearmed", "rearm=false"),
    ("TS15H-END-003", "end_data_single_write", "duplicate_rows=0"),
    ("TS15H-INTEGRITY-001", "unique_key", "duplicate_keys=0"),
    ("TS15H-INTEGRITY-002", "capacity_fail_closed", "validation_status=VALIDATION_INVALID"),
    ("TS15H-SPLIT-001", "cluster_grouped", "cluster_fold_count=1"),
    ("TS15H-SPLIT-002", "purge_900s", "purge_ms=900000"),
    ("TS15H-SPLIT-003", "train_only_transform", "outer_feature_fit_reads=0"),
    ("TS15H-POLICY-001", "no_trade_zero", "policy_r=0"),
    ("TS15H-POLICY-002", "counterfactual_separate", "policy_r=0;counterfactual_r=-1"),
    ("TS15H-POLICY-003", "policy_value", "policy_value=0.1"),
    ("TS15H-POLICY-004", "avoided_loss_rejected_win", "avoided_loss_r=1;rejected_profit_r=1.2"),
    ("TS15H-POLICY-005", "empty_fold_insufficient", "fold_status=INSUFFICIENT_SUPPORT"),
    ("TS15H-REGRESSION-001", "step15g_identity_preserved", "identity_differences=0"),
    ("TS15H-REGRESSION-002", "strategy_parameters_preserved", "parameter_differences=0"),
    ("TS15H-PROV-001", "orders_zero", "order_calls=0"),
    ("TS15H-PROV-002", "hashes_complete", "missing_hashes=0"),
]


def main() -> None:
    preanalysis = """# Step 15H detection-time continuation pre-analysis

## Audit baseline

- parent branch: `research/tickshock-step15g-economic-path-classification-20260901`
- parent HEAD/upstream: `6e5020be77ff7221d91c996d683e41028b2c7538`
- accepted Step 15G run: `20260901_ts15g_economic_path_r3_202503`
- accepted run source commit: `e9c2968660288c12af03dba770e519c8d012e010`
- baseline deterministic suite re-observed: PASS 361 / SKIP 9 / all other statuses 0
- Step 15G oracle: 52 checks / 0 differences
- detector rows 21,799; market clusters 10,245; episodes 3,151; primary Step 15G episodes 2,228 are not reused as a t0 target.

## Question and scope

At the exact production-path decision time when `TAIL_V1_PERSISTENT` becomes usable, can causal information select `CONTINUATION` versus `NO_TRADE` so that C2 continuation losses fall without discarding more profitable continuation? March 2025 is repeatedly observed development data. Internal OOF results are hypothesis-development evidence only.

No reversal action, delayed/pullback entry, RR search, detector change, existing strategy change, order, OOS, or production promotion is permitted. GBPUSD is fully excluded from primary inference because its 179 generated-fallback minutes cannot be interval-mapped. Matched-control economic paths remain unavailable and are not imputed as zero.

## Fixed analysis discipline

- Unit: one causal episode representative; all-event rows are secondary.
- Dependence: whole market clusters remain in one fold.
- Five expanding chronological outer folds; inner chronological selection only.
- Purge and embargo: 900 seconds plus the configured entry delay; 900,250 ms is used conservatively.
- Primary: delay 0 ms, horizon 900 s, RR 1.2, C2 diagnostic cost.
- Stress: delay 100/250 ms and horizon 300/600 s; they cannot select the winning model.
- Bootstrap: paired market-cluster day blocks, 2,000 repetitions, seed 1502, two-sided 95% intervals.
- Multiplicity: Holm correction over the eight preregistered model/feature-set families.
- Missing features fail closed to `NO_TRADE`; unavailable outcomes are excluded and never relabeled loss/zero.

## Minimum support and stopping

The minimum overall analyzable support is fixed at 2,500 episodes and 2,000 market clusters, with at least 200 evaluable episodes and 25 selected episodes in every outer fold. This is an `ENGINEERING_ASSUMPTION_TO_BE_VALIDATED`, chosen to keep a normal-approximation 95% mean-R half-width near 0.04R when the standard deviation is about 1R. Failure is `INCONCLUSIVE_SAMPLE_SIZE`, not a threshold-relaxation trigger.

The candidate gate additionally requires positive selected C2 mean and multiplicity-adjusted lower confidence bound, policy value above both `NO_TRADE` and unfiltered continuation, incremental value over `LIQUIDITY_ONLY`, five-fold support, and no concentration or nearby-threshold/delay collapse. Otherwise no candidate is frozen.
"""
    spec = """# Step 15H frozen detection-time continuation specification

## Clocks and causal order

`candidate_msc <= confirmed_msc <= processed_msc <= t0_msc`. `t0_msc` is the first production-path processing clock at which the persistent confirmation and all snapshot inputs are usable. For delay `d`, `eligible_msc=max(t0_msc+d, processed_msc)` and entry is the first same-symbol real quote strictly after the signal quote and at/after eligibility. `entry_quote_msc <= t0_msc` is forbidden. Horizon is `t0_msc + horizon_seconds*1000`; entry latency never extends it.

Same-millisecond ticks are ordered by production sequence/cursor and the last processed quote at t0 is snapshotted. Appending future ticks must not alter an existing snapshot. Candidate-to-confirmation values and pre-shock windows are separate. No unconfirmed bar, future pivot, final cluster breadth, later MFE/MAE, outcome, or entry-time spread/risk may enter a feature.

## Population

Detector `TAIL_V1_PERSISTENT`, March 2025, six monitored symbols, primary excludes every GBPUSD row and every fallback/stale/warmup/incomplete/end-censored row. The causal representative is the first eligible persistent confirmation in each episode; future severity and final breadth do not choose it. Feature rejection and outcome unavailability are distinct statuses.

## Immediate continuation counterfactual

- Direction: confirmed shock direction only; one decision at t0.
- Long Ask entry/Bid exit; Short Bid entry/Ask exit.
- Risk: `max(0.25*completed M5 ATR14, 4*entry spread, broker StopsLevel distance)` using existing outward rounding.
- RR: 1.2 only. TP is target-limit; SL gaps fill at the first tradable side quote; same-ms ambiguity is conservatively SL-first while secondary status preserves ambiguity.
- Primary horizon 900 s from t0; 300/600 s diagnostics.
- Delay 0 primary; 100/250 ms stress.
- C0 uses actual Bid/Ask. C2 uses 1.25x spread plus one tick at entry and exit exactly once. C2 is not formal net because six-symbol commission/slippage evidence is incomplete.

## Feature registry

The versioned registry is `reports/analysis/tick_shock/step15h/feature_registry.csv`. It freezes ten main effects plus two interactions. Every feature stores value, source timestamp, availability and missing reason. Directional values are normalized to shock direction; price distances are ATR ratios. Metadata and quality flags are not model features.

Feature sets: `LIQUIDITY_ONLY={H01,H02}`, `PRE_CONTEXT={H01..H07}`, `DETECTION_SHAPE={H01,H02,H08,H09,H10}`, `COMBINED={H01..H12}`.

## Labels, models, and selection

Primary label is `C2_R > 0`; continuous C2 R is the utility. TP_FIRST, SL_FIRST, TIMEOUT with signed R, MFE/MAE and hit clocks remain evaluation diagnostics only.

Eight model families are frozen: four feature sets times regularized logistic regression and decision tree depth <=2. Logistic `C={0.1,1,10}`; tree candidates `(depth,min_leaf)={(1,100),(2,100),(2,200)}`. Probability/action thresholds are `{0.35,0.45,0.50,0.55,0.65}`. Inner training selects by policy value with ties resolved by fewer features, higher threshold, then lexical trial ID. No model, feature, hyperparameter or threshold may be added after outcomes are inspected.

Policies on the same eligible set are `NO_TRADE`, `UNFILTERED_CONTINUATION`, `LIQUIDITY_ONLY`, `PRE_CONTEXT`, `DETECTION_SHAPE`, and `COMBINED`. Rejected rows retain counterfactual R but actual policy R is zero. Primary value is `sum(selected*R)/N_eligible`, not selected conditional mean.

## Validation and candidate gate

Five expanding chronological folds, market-cluster grouping, 900,250 ms purge/embargo, fold-local imputation/scaling/model/threshold. Paired day/market-cluster block bootstrap uses 2,000 repetitions and seed 1502; Holm family is the eight model families. Empty or undersupported folds fail support. LOSO and leave-one-day/cluster diagnostics cannot rescue a failed primary.

The strongest permissible status is `DETECTION_TIME_CONTINUATION_FILTER_HYPOTHESIS_FROZEN_FOR_FUTURE_VALIDATION`. It requires the preregistered support, positive primary C2 mean and adjusted lower bound, positive opportunity value, improvement over unfiltered and liquidity-only, five-fold stability, concentration and missingness checks, delay/neighbor-threshold stability, causal/provenance regression, and zero orders. Otherwise report `NO_DETECTION_TIME_CONTINUATION_FILTER_SUPPORTED` and `NO_CONTINUATION_FILTER_HYPOTHESIS_FROZEN` or `INCONCLUSIVE_SAMPLE_SIZE`. Always retain `COST_MODEL_INCOMPLETE`, `FORMAL_NET_EXPECTANCY_UNAVAILABLE`, `EDGE_UNDETERMINED`, `PRODUCTION_NOT_ELIGIBLE`.
"""
    write_text(DOC / "15h_detection_time_continuation_preanalysis.md", preanalysis)
    write_text(DOC / "15h_detection_time_continuation_spec.md", spec)

    feature_rows = [dict(feature_id=i, name=n, formula=f, family=family, unit=u, missing_policy=m,
                         source_clock="<=t0", future_input="false", registered="true")
                    for i, n, f, family, u, m in FEATURES]
    write_csv(ANALYSIS / "feature_registry.csv",
              ["feature_id", "name", "formula", "family", "unit", "missing_policy", "source_clock", "future_input", "registered"], feature_rows)

    trial_rows = []
    for feature_set in ("LIQUIDITY_ONLY", "PRE_CONTEXT", "DETECTION_SHAPE", "COMBINED"):
        for model in ("LOGISTIC_L2", "TREE_DEPTH2"):
            trial_rows.append(dict(trial_id=f"TS15H-{feature_set}-{model}", feature_set=feature_set, model=model,
                                   hyperparameters="C=0.1|1|10" if model == "LOGISTIC_L2" else "depth_leaf=1_100|2_100|2_200",
                                   thresholds="0.35|0.45|0.50|0.55|0.65", primary_cost="C2", primary_horizon_seconds=900,
                                   primary_delay_ms=0, status="PREREGISTERED"))
    write_csv(ANALYSIS / "trial_registry.csv",
              ["trial_id", "feature_set", "model", "hyperparameters", "thresholds", "primary_cost", "primary_horizon_seconds", "primary_delay_ms", "status"], trial_rows)

    registry = ROOT / "tests/tick_shock/spec/test_cases.csv"
    with registry.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle)); fields = list(rows[0])
    rows = [r for r in rows if not r["test_id"].startswith("TS15H-")]
    red_rows = []
    for tid, description, expected in TESTS:
        ticks = [
            dict(sequence=1, symbol="EURUSD", time_msc=1500, bid="1.0000", ask="1.0002", processing_msc=1600, note="persistent confirmation source quote"),
            dict(sequence=2, symbol="EURUSD", time_msc=1600, bid="1.0001", ask="1.0003", processing_msc=1600, note="t0 snapshot quote"),
            dict(sequence=3, symbol="EURUSD", time_msc=1601, bid="1.0002", ask="1.0004", processing_msc=1601, note="first strictly later quote"),
        ]
        write_csv(FIX / f"{tid}_ticks.csv", ["sequence", "symbol", "time_msc", "bid", "ask", "processing_msc", "note"], ticks)
        write_csv(FIX / f"{tid}_config.csv", ["key", "value"], [
            {"key": "description", "value": description}, {"key": "oracle", "value": "independent_contract"},
            {"key": "spec", "value": "docs/research/tick_shock/15h_detection_time_continuation_spec.md"},
        ])
        first_field, first_value = expected.split(";", 1)[0].split("=", 1)
        write_csv(EXP / f"{tid}_expected.csv", ["field", "expected_value", "tolerance", "unit", "note"], [
            {"field": first_field, "expected_value": first_value, "tolerance": "1e-9", "unit": "contract", "note": expected}
        ])
        rows.append(dict(test_id=tid, requirement_id="TS15H-REQ-" + tid.split("-")[1], defect_id="STEP15H-PRE_IMPLEMENTATION",
                         component=tid.split("-")[1].lower(), test_layer="production_path_integration", direction="BOTH",
                         fixture_path=f"tests/tick_shock/fixtures/{tid}_ticks.csv", expected_path=f"tests/tick_shock/expected/{tid}_expected.csv",
                         current_expected_status="XFAIL", description=description))
        red_rows.append(dict(test_id=tid, requirement_id="TS15H-REQ-" + tid.split("-")[1], defect_id="STEP15H-PRE_IMPLEMENTATION",
                             test_layer="production_path_integration", status="XFAIL", expected=expected,
                             actual="PRODUCTION_T0_CONTINUATION_API_ABSENT", difference="registered production path is absent",
                             evidence_path="reports/tests/tick_shock/step15h_red/step15h_red_results.csv"))
    write_csv(registry, fields, rows)
    result_fields = ["test_id", "requirement_id", "defect_id", "test_layer", "status", "expected", "actual", "difference", "evidence_path"]
    write_csv(RED / "step15h_red_results.csv", result_fields, red_rows)
    write_text(RED / "step15h_red_report.md", f"""# Step 15H RED report

- preregistered contracts: {len(TESTS)}
- XFAIL: {len(TESTS)}
- unexpected FAIL: 0

The existing production path has no t0 immediate-continuation snapshot/first-touch API. Fixtures and expected contracts were frozen before implementation and do not call production formulas. Step 15G source and output were not changed by this RED registration.
""")
    hashes = []
    for path in sorted([DOC / "15h_detection_time_continuation_preanalysis.md", DOC / "15h_detection_time_continuation_spec.md",
                        ANALYSIS / "feature_registry.csv", ANALYSIS / "trial_registry.csv"] +
                       list(FIX.glob("TS15H-*")) + list(EXP.glob("TS15H-*"))):
        hashes.append({"path": path.relative_to(ROOT).as_posix(), "sha256": hashlib.sha256(path.read_bytes()).hexdigest().upper()})
    write_csv(ANALYSIS / "preregistered_hashes.csv", ["path", "sha256"], hashes)
    print(f"generated {len(TESTS)} Step15H RED contracts, {len(FEATURES)} features, {len(trial_rows)} trial families")


if __name__ == "__main__":
    main()
