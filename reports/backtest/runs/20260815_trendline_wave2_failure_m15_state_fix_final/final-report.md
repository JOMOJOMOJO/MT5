# TRENDLINE_WAVE2_FAILURE M15 state-machine fix

## Outcome

The M15 state machine was corrected without relaxing any strategy parameter. The revised EA compiled with 0 errors and 0 warnings, and all six Long/Short reachability tests passed. The locked 2024 real-tick rerun still produced zero new-bucket trades because its only H1 reversal-leg setup expired before M15 countertrend structure formed; therefore the market run did not dynamically exercise the new M15 states.

## Implemented state flow

1. `counterStructure` is evaluated only in `H1_REVERSAL_LEG`.
2. The transition to `M15_PULLBACK_ACTIVE` freezes the reference extreme, reference pivot/confirmation times, protected swing, and protected pivot/confirmation times.
3. `M15_PULLBACK_ACTIVE` searches only for a confirmed same-kind swing strictly after the frozen reference; it does not re-evaluate `counterStructure`.
4. The new swing can be classified as equal double bottom/top, higher low/lower high, false-break recovery, or triple bottom/top.
5. A valid classification advances the setup to `M15_CONTINUATION_FAILED`.
6. The failure state keeps the frozen protected swing and waits for its closed-bar break.
7. `InpRequireM15MASlope` is evaluated only after a protected-swing break, as an entry filter.
8. A confirmed extreme that clearly breaks the pattern extreme re-anchors the setup and returns it to `M15_PULLBACK_ACTIVE`; it does not invalidate the setup. Existing H4/H1 invalidation and expiry rules were not changed.
9. M15 handling is split into anchor detection/freezing, active classification, failure re-anchoring, and protected-break entry handling.
10. Runtime initialization tests cover Long/Short equal, higher-low/lower-high, and false-break paths through `M15_PULLBACK_ACTIVE -> M15_CONTINUATION_FAILED`.
11. The requested detailed funnel is written to the summary CSV. `triple_extreme` is retained as one additional diagnostic branch.

## Locked 2024 validation

- Period: 2024-01-01 through 2024-12-31
- Tester: MT5 `Model=4`, Every tick based on real ticks
- History quality: 99% real ticks
- Ticks: 37,115,045
- Parameter changes versus the original 2024 preset: only run ID, magic numbers, and log folders; strategy parameter changes: 0
- Compile: 0 errors, 0 warnings
- Reachability tests: 6 passed, 0 failed
- MT5 trades/deals: 0 / 0
- Custom funnel orders: 0

## Old versus new funnel

| Stage | Old | New | Note |
|---|---:|---:|---|
| H4 impulses | 80 | 80 | unchanged |
| H4 structure breaks | 80 | 80 | unchanged |
| H1 mature | 4 | 4 | unchanged |
| H1 trendline breaks | 1 | 1 | unchanged |
| countertrend_structure | not recorded | 0 | new counter |
| anchor_frozen | 0 (`m15_pullbacks`) | 0 | no 2024 anchor |
| post_anchor_swing | not recorded | 0 | new counter |
| equal_extreme | not recorded | 0 | new counter |
| higher_low_or_lower_high | not recorded | 0 | new counter |
| false_break_recovery | not recorded | 0 | new counter |
| failure_invalidated | not recorded | 0 | new counter |
| continuation_failure | 0 | 0 | unchanged outcome |
| protected_break | 0 | 0 | unchanged outcome |
| ma_filter_reject | not recorded | 0 | new counter |
| execution_pass | 0 | 0 | unchanged |
| order | 0 | 0 | unchanged |

The detailed machine-readable comparison is in [funnel_comparison_2024.csv](funnel_comparison_2024.csv).

## Representative transition

The only 2024 setup that reached `H1_REVERSAL_LEG` was USDJPY Short:

1. 2024-02-27 08:00 — `H1_STRUCTURE_RECONSTRUCTED -> H1_TREND_MATURE`
2. 2024-03-05 16:00 — `H1_TREND_MATURE -> H1_TRENDLINE_BROKEN`
3. 2024-03-05 16:00 — `H1_TRENDLINE_BROKEN -> H1_REVERSAL_LEG`
4. 2024-03-08 17:00 — `H1_REVERSAL_LEG -> EXPIRED` due to the unchanged H1 setup-expiry rule

See [representative_state_timeline_2024.csv](representative_state_timeline_2024.csv).

## Future-reference audit

- Swing pivot time remains distinct from the later confirmation time.
- Post-anchor searches require both pivot and confirmation to be strictly after the frozen reference and require confirmation time to be no later than the current closed-bar signal time.
- Re-anchor searches apply the same confirmation-time cutoff.
- Protected swings are selected only between already-known same-kind pivots and with confirmation no later than the current signal time.
- The runtime CSV audit checked 243 populated generic pivot/confirmation rows and found 0 pivot-after-confirmation or confirmation-after-event violations.
- The 2024 market run produced no M15 anchor rows, so dynamic M15 timestamp evidence is unavailable in this window. The absence of future reference in those branches is supported by the explicit time guards and the six deterministic transition tests, not by a 2024 market occurrence.

See [causality_audit_2024.csv](causality_audit_2024.csv).

## Trade-integrity audit

No new-bucket order was generated. Lot, SL, post-fill 2R, total/currency-direction risk, margin, and MT5-history-versus-custom-CSV checks are therefore not applicable to this run. This status is recorded in [trade_integrity_2024.csv](trade_integrity_2024.csv).

## Evidence

- [MT5 report](m15_state_fix_final_2024/report.html)
- [Detailed funnel summary](m15_state_fix_final_2024/new_tw2f_m15_state_fix_final_2024_summary.csv)
- [State-event CSV](m15_state_fix_final_2024/new_tw2f_m15_state_fix_final_2024_events.csv)
- [Validation summary](validation_summary_2024.json)
- [Parameter diff](parameter_diff_2024.csv)
- [Run lock](run_lock.json)

