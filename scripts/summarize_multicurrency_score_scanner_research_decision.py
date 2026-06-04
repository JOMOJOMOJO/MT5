#!/usr/bin/env python3
from __future__ import annotations

import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BACKTEST = ROOT / "reports" / "backtest"
DEVLOG = ROOT / "docs" / "devlog"


MASTER_COLUMNS = [
    "period",
    "strategy_mode",
    "entry_selection_mode",
    "scan_interval",
    "trades",
    "PF",
    "expected_payoff",
    "avg_R",
    "net_profit",
    "maxDD",
    "maxDD_pct",
    "win_rate",
    "profit_by_long",
    "profit_by_short",
    "profit_by_fx",
    "profit_by_xauusd",
    "best_symbol",
    "worst_symbol",
    "best_session",
    "worst_session",
    "main_fail_reason",
    "main_loss_reason",
    "source_artifact",
]


def read_csv(name: str) -> list[dict[str, str]]:
    path = BACKTEST / name
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return list(csv.DictReader(fh))


def write_csv(path: Path, rows: list[dict[str, object]], columns: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=columns)
        writer.writeheader()
        for row in rows:
            writer.writerow({column: row.get(column, "") for column in columns})


def num(row: dict[str, str], key: str, default: float = 0.0) -> float:
    value = row.get(key, "")
    if value in ("", None):
        return default
    try:
        return float(str(value).replace(",", ""))
    except ValueError:
        return default


def text(row: dict[str, str], *keys: str) -> str:
    for key in keys:
        value = row.get(key, "")
        if value not in ("", None):
            return str(value)
    return ""


def fmt(value: object) -> object:
    if isinstance(value, float):
        return round(value, 3)
    return value


def profit_by_fx(row: dict[str, str]) -> float:
    if "fx_net_profit" in row and row.get("fx_net_profit") not in ("", None):
        return num(row, "fx_net_profit")
    return num(row, "net_profit") - num(row, "xauusd_net_profit")


def best_worst(
    rows: list[dict[str, str]],
    predicate,
    label_key: str = "group",
    profit_key: str = "net_profit",
) -> tuple[str, str]:
    filtered = [row for row in rows if predicate(row)]
    if not filtered:
        return "", ""
    best = max(filtered, key=lambda row: num(row, profit_key))
    worst = min(filtered, key=lambda row: num(row, profit_key))
    return (
        f"{best.get(label_key, '')}:{num(best, profit_key):.2f}",
        f"{worst.get(label_key, '')}:{num(worst, profit_key):.2f}",
    )


def infer_loss_reason(
    net_profit: float,
    long_net: float,
    short_net: float,
    fx_net: float,
    xau_net: float,
    xau_share: float,
    scenario: str,
) -> str:
    reasons: list[str] = []
    scenario_lower = scenario.lower()
    if "disable_usdjpy_short" in scenario_lower and short_net < -500:
        reasons.append("residual short loss after USDJPY short removal")
    elif "USDJPY" in scenario and "short" in scenario_lower:
        reasons.append("USDJPY short focus")
    if short_net < -500 and long_net >= 0:
        reasons.append("short branch loss")
    if long_net < -500 and short_net >= 0:
        reasons.append("long branch loss")
    if fx_net < -300 and xau_net >= -100:
        reasons.append("FX basket loss")
    if xau_net < -300 and fx_net >= -100:
        reasons.append("XAUUSD loss")
    if xau_share >= 80:
        reasons.append("XAUUSD concentration")
    if net_profit < 0 and not reasons:
        reasons.append("broad negative expectancy")
    if not reasons:
        reasons.append("no dominant loss bucket")
    return "; ".join(reasons)


def master_row(
    *,
    period: str,
    strategy_mode: str,
    entry_selection_mode: str,
    scan_interval: str,
    row: dict[str, str],
    source: str,
    best_symbol: str = "",
    worst_symbol: str = "",
    best_session: str = "",
    worst_session: str = "",
    main_fail_reason: str = "",
    avg_R: str | float = "",
) -> dict[str, object]:
    long_net = num(row, "long_net_profit")
    short_net = num(row, "short_net_profit")
    xau_net = num(row, "xauusd_net_profit")
    fx_net = profit_by_fx(row)
    net_profit = num(row, "net_profit")
    xau_share = num(row, "xauusd_trade_share_pct")
    scenario = text(row, "scenario")
    scenario_upper = scenario.upper()
    if long_net == 0 and short_net == 0 and "LONG_ONLY" in scenario_upper:
        long_net = net_profit
    if long_net == 0 and short_net == 0 and "SHORT_ONLY" in scenario_upper:
        short_net = net_profit
    return {
        "period": period,
        "strategy_mode": strategy_mode,
        "entry_selection_mode": entry_selection_mode,
        "scan_interval": scan_interval,
        "trades": int(num(row, "trades")),
        "PF": text(row, "profit_factor"),
        "expected_payoff": text(row, "expected_payoff"),
        "avg_R": avg_R,
        "net_profit": fmt(net_profit),
        "maxDD": fmt(num(row, "max_balance_dd", num(row, "max_drawdown"))),
        "maxDD_pct": fmt(num(row, "max_balance_dd_pct", num(row, "max_drawdown_pct"))),
        "win_rate": text(row, "win_rate"),
        "profit_by_long": fmt(long_net),
        "profit_by_short": fmt(short_net),
        "profit_by_fx": fmt(fx_net),
        "profit_by_xauusd": fmt(xau_net),
        "best_symbol": best_symbol,
        "worst_symbol": worst_symbol,
        "best_session": best_session,
        "worst_session": worst_session,
        "main_fail_reason": main_fail_reason,
        "main_loss_reason": infer_loss_reason(
            net_profit, long_net, short_net, fx_net, xau_net, xau_share, scenario
        ),
        "source_artifact": source,
    }


def build_master_comparison() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []

    phase2 = read_csv("ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_run_comparison.csv")
    phase2_symbol = read_csv("ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_by_symbol.csv")
    for row in phase2:
        best_symbol, worst_symbol = best_worst(
            phase2_symbol, lambda item, run=row.get("run"): item.get("run") == run
        )
        rows.append(
            master_row(
                period="2025",
                strategy_mode=f"Phase2 {row.get('scenario', '')}",
                entry_selection_mode="best_candidate",
                scan_interval="5m",
                row=row,
                source="ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_run_comparison.csv",
                best_symbol=best_symbol,
                worst_symbol=worst_symbol,
                main_fail_reason=text(row, "structure_top_fail_reason"),
            )
        )

    oos = read_csv("ExpectedValue_MultiCurrency_ScoreScanner_oos_run_comparison.csv")
    for row in oos:
        rows.append(
            master_row(
                period=text(row, "year"),
                strategy_mode=f"Phase2 OOS {row.get('scenario', '')}",
                entry_selection_mode="best_candidate",
                scan_interval="5m",
                row=row,
                source="ExpectedValue_MultiCurrency_ScoreScanner_oos_run_comparison.csv",
                best_symbol=text(row, "major_winning_symbols"),
                worst_symbol=text(row, "major_losing_symbols"),
                main_fail_reason=text(row, "structure_top_fail_reason"),
            )
        )

    thirdwave = read_csv("ExpectedValue_MultiCurrency_ScoreScanner_2025_thirdwave_run_comparison.csv")
    for row in thirdwave:
        rows.append(
            master_row(
                period="2025",
                strategy_mode=f"ThirdWave original {row.get('scenario', '')}",
                entry_selection_mode="best_candidate",
                scan_interval="5m",
                row=row,
                source="ExpectedValue_MultiCurrency_ScoreScanner_2025_thirdwave_run_comparison.csv",
                main_fail_reason=text(row, "thirdwave_top_skip_reason"),
            )
        )

    regime = read_csv("ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_regime_run_comparison.csv")
    regime_symbol = read_csv("ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_regime_by_symbol.csv")
    regime_session = read_csv("ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_regime_by_session.csv")
    for row in regime:
        period = text(row, "period", "year")
        scenario = text(row, "scenario")
        best_symbol, worst_symbol = best_worst(
            regime_symbol,
            lambda item, p=period, s=scenario: item.get("period") == p and item.get("scenario") == s,
        )
        best_session, worst_session = best_worst(
            regime_session,
            lambda item, p=period, s=scenario: item.get("period") == p and item.get("scenario") == s,
        )
        rows.append(
            master_row(
                period=period,
                strategy_mode=scenario,
                entry_selection_mode="best_candidate",
                scan_interval="5m",
                row=row,
                source="ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_regime_run_comparison.csv",
                best_symbol=best_symbol or text(row, "major_winning_symbols"),
                worst_symbol=worst_symbol or text(row, "major_losing_symbols"),
                best_session=best_session,
                worst_session=worst_session,
                main_fail_reason=text(row, "top_structure_stage_fail_reason", "top_execution_block_reason"),
            )
        )

    scan = read_csv("ExpectedValue_MultiCurrency_ScoreScanner_scan_interval_run_comparison.csv")
    scan_symbol = read_csv("ExpectedValue_MultiCurrency_ScoreScanner_scan_interval_by_symbol.csv")
    scan_session = read_csv("ExpectedValue_MultiCurrency_ScoreScanner_scan_interval_by_session.csv")
    for row in scan:
        period = text(row, "period")
        selection = text(row, "selection_mode")
        scan_minutes = text(row, "scan_minutes")
        best_symbol, worst_symbol = best_worst(
            scan_symbol,
            lambda item, p=period, sel=selection, minutes=scan_minutes: (
                item.get("period") == p
                and item.get("selection_mode") == sel
                and item.get("scan_minutes") == minutes
            ),
        )
        best_session, worst_session = best_worst(
            scan_session,
            lambda item, p=period, sel=selection, minutes=scan_minutes: (
                item.get("period") == p
                and item.get("selection_mode") == sel
                and item.get("scan_minutes") == minutes
            ),
        )
        rows.append(
            master_row(
                period=period,
                strategy_mode=text(row, "scenario"),
                entry_selection_mode=selection,
                scan_interval=f"{scan_minutes}m",
                row=row,
                source="ExpectedValue_MultiCurrency_ScoreScanner_scan_interval_run_comparison.csv",
                best_symbol=best_symbol,
                worst_symbol=worst_symbol,
                best_session=best_session,
                worst_session=worst_session,
                main_fail_reason="summary-only diagnostics; see scan interval aggregates",
            )
        )

    v2 = read_csv("ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v2_comparison.csv")
    v2_symbol = read_csv("ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v2_by_symbol.csv")
    v2_session = read_csv("ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v2_by_session.csv")
    v2_filter = read_csv("ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v2_filter_summary.csv")
    top_v2_reason = {
        (item.get("period"), item.get("variant")): item.get("top_v2_filter_fail_reason", "")
        for item in v2_filter
    }
    for row in v2:
        variant = text(row, "variant")
        best_symbol, worst_symbol = best_worst(
            v2_symbol, lambda item, v=variant: item.get("variant") == v, label_key="symbol"
        )
        best_session, worst_session = best_worst(
            v2_session, lambda item, v=variant: item.get("variant") == v, label_key="session"
        )
        rows.append(
            master_row(
                period=text(row, "period"),
                strategy_mode=f"ThirdWave v2 {variant}",
                entry_selection_mode="all_score_passing",
                scan_interval="5m",
                row=row,
                source="ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v2_comparison.csv",
                best_symbol=best_symbol,
                worst_symbol=worst_symbol,
                best_session=best_session,
                worst_session=worst_session,
                main_fail_reason=top_v2_reason.get((text(row, "period"), variant), ""),
                avg_R=text(row, "avg_R"),
            )
        )

    return rows


def build_failure_matrix() -> list[dict[str, object]]:
    return [
        {
            "category": "A. higher timeframe trend recognition",
            "severity": "high",
            "confidence": "high",
            "affected_modes": "ThirdWave, regime ThirdWave, v2",
            "evidence": "thirdwave diagnostics: no_higher_tf_trend is the largest structure-stage fail; regime gate improves 2024/2026 but not 2025.",
            "interpretation": "The current HH/HL or LL/LH state is not separating clean trend, range, transition, and exhaustion strongly enough.",
            "next_action": "Improve trend-quality and exhaustion diagnostics only after entry timing is fixed.",
        },
        {
            "category": "B. mid timeframe pullback quality",
            "severity": "medium-high",
            "confidence": "medium",
            "affected_modes": "ThirdWave v2, wave audit",
            "evidence": "v2 filter summary: deep pullback and old-trend filters remove many candidates, but annual gate did not pass cleanly.",
            "interpretation": "Pullback quality matters, but filtering it directly reduced trades and increased XAU concentration.",
            "next_action": "Keep as secondary filter; do not optimize pullback thresholds yet.",
        },
        {
            "category": "C. lower timeframe reversal timing",
            "severity": "critical",
            "confidence": "high",
            "affected_modes": "ThirdWave, ThirdWave v2",
            "evidence": "wave audit: chasing_entry 100 trades, third_wave_initial 1 trade; v2 still leaves 50 chasing_entry trades.",
            "interpretation": "The strategy name is not matching execution reality. It usually enters continuation/chase positions, not clean third-wave starts.",
            "next_action": "Prioritize an entry-timing and wave-position branch before regime or SL/TP work.",
        },
        {
            "category": "D. SL/TP design",
            "severity": "medium",
            "confidence": "medium",
            "affected_modes": "ThirdWave, Phase2 scanner",
            "evidence": "Fixed R TP keeps comparison clean, but audit shows entries are often late; SL/ATR alone is not proven as the first bottleneck.",
            "interpretation": "Exit design may be inefficient, but changing it before fixing entry position would mask the root cause.",
            "next_action": "Defer SL/TP changes; add exit diagnostics later.",
        },
        {
            "category": "E. regime classification",
            "severity": "high",
            "confidence": "medium-high",
            "affected_modes": "Regime ThirdWave, scan interval tests",
            "evidence": "Regime gate turns 2024/2026YTD positive in several scan-interval runs, while 2025 remains negative.",
            "interpretation": "Regime filtering is useful but incomplete; it does not solve bad wave-position entries in adverse years.",
            "next_action": "Second priority after entry timing.",
        },
        {
            "category": "F. execution and scan conditions",
            "severity": "medium",
            "confidence": "high",
            "affected_modes": "All ThirdWave variants",
            "evidence": "spread_guard dominates raw evaluations; 15m reduces runtime and DD in 2025 but loses robustness in 2024/2026.",
            "interpretation": "Execution logs explain runtime and candidate attrition, not the core edge failure.",
            "next_action": "Use 5m or 10m for research; do not choose 15m solely because it trades less.",
        },
        {
            "category": "G. research design and concentration",
            "severity": "high",
            "confidence": "high",
            "affected_modes": "Phase2 LONG_ONLY, XAU branches, v2",
            "evidence": "Phase2 D is positive in 2025 but negative in 2024 and flat in 2026YTD; v2 short-period sample remains 84.5% XAUUSD.",
            "interpretation": "Several positive results are too concentrated or period-specific to promote.",
            "next_action": "Reject XAU-only promotion as generic evidence; require FX and direction-balanced validation.",
        },
    ]


def write_markdown_reports(master_rows: list[dict[str, object]]) -> None:
    report = BACKTEST / "research_decision_report.md"
    candidates = BACKTEST / "next_phase_candidates.md"
    recommended = BACKTEST / "recommended_next_task.md"
    devlog = DEVLOG / "2026-06-04-multicurrency-score-scanner-research-decision.md"

    report.write_text(
        """# Multi-Currency Score Scanner / ThirdWave Research Decision Report

## Scope

This report consolidates Phase2, OOS, ThirdWave, regime-aware ThirdWave, All Candidates, scan interval, Wave Audit, and ThirdWave v2 evidence. No new logic or parameter optimization was performed in this step.

Primary evidence:
- `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_phase2_summary.md`
- `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_oos_summary.md`
- `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_2025_thirdwave_summary.md`
- `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_regime_summary.md`
- `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_scan_interval_summary.md`
- `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_summary.md`
- `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v2_short_period_summary.md`
- `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v2_oos_summary.md`
- `reports/backtest/research_master_comparison.csv`
- `reports/backtest/failure_cause_matrix.csv`

## Executive Decision

The current family should not be promoted and should not be optimized yet.

The strongest 2025 result, Phase2 `LONG_ONLY + DowFractalStructureFilter`, did not survive OOS cleanly: 2024 was negative and 2026YTD was close to flat unless treated as an XAUUSD-heavy branch. ThirdWave regime filtering is more promising than the original ThirdWave, but 2025 remains weak and the edge is not yet broad across symbols and directions.

The main bottleneck is not parameter values. The Wave Audit shows the current ThirdWave rarely enters a clean third-wave initial position. It is dominated by `chasing_entry` classifications, while `third_wave_initial` appears only once in the audited sample and lost.

## Key Numbers

| Branch | Period | Result |
|---|---|---|
| Phase2 `BOTH_5m_new_bar` | 2025 | 1690 trades, PF 0.982, net -750.91, LONG +2641.86, SHORT -3392.77 |
| Phase2 `LONG_ONLY_DowFractal_5m_new_bar` | 2025 | 675 trades, PF 1.159, net +3349.91, max DD 6.64% |
| Phase2 `LONG_ONLY_DowFractal_5m_new_bar` | 2024 OOS | 510 trades, PF 0.908, net -1305.43 |
| Phase2 `LONG_ONLY_DowFractal_5m_new_bar` | 2026YTD OOS | 181 trades, PF 1.007, net +36.70 |
| ThirdWave original BOTH | 2025 | 451 trades, PF 0.963, net -464.41 |
| ThirdWave original LONG_ONLY | 2025 | 271 trades, PF 0.821, net -1364.56 |
| ThirdWave original SHORT_ONLY | 2025 | 208 trades, PF 1.043, net +246.70 |
| Scan interval regime all 5m | 2025 | 269 trades, PF 0.944, net -431.98 |
| Scan interval regime all 15m | 2025 | 147 trades, PF 0.972, net -118.91, but OOS support is weak |
| Wave Audit | short samples | `chasing_entry` 100 trades vs `third_wave_initial` 1 trade |
| ThirdWave v2 | short samples | avg R improved, but trades fell to 53.2% and XAUUSD share stayed 84.5%; annual gate not passed |

## What Is Consistently Good

- Regime-aware ThirdWave is better than original ThirdWave in 2024 and 2026YTD, especially at 5m/10m scan intervals.
- 10m scan often preserves much of the 5m result while reducing runtime, but it is not an edge fix.
- All Candidates mode is useful diagnostically because it exposes hidden symbol/direction behavior. It did not reveal a robust multi-symbol edge in 2025.
- XAUUSD often contributes positively, but the concentration is too high to treat as generic multi-currency evidence.

## What Is Consistently Bad

- Original ThirdWave BOTH is not stable enough: 2025 BOTH is negative and LONG_ONLY is materially negative.
- Phase2 SHORT remains structurally weak in 2025. Removing USDJPY short helps, but does not prove a healthy short model.
- Phase2 LONG_ONLY + structure has a 2025 win but fails broad OOS confirmation.
- 15m scan can look safer in 2025 by reducing trades, but 2024 and 2026YTD do not support it as a robust improvement.
- ThirdWave v2 improves average R in short samples but does so by cutting trades to about half and retaining high XAUUSD concentration. The annual test gate did not pass.

## XAUUSD And FX Read

XAUUSD is an important source of positive excursions, but it is also the largest source of concentration risk. XAUUSD-only branches are useful references, not acceptable proof for a shared multi-currency strategy.

FX-only expectancy is not consistently positive. In scan interval tests, 2025 FX net remains negative across best/all and 5m/10m/15m. That means the next phase must improve generic structure quality, not escape into symbol filtering.

## LONG / SHORT Read

Phase2 LONG looked good in 2025, but OOS weakened the case. ThirdWave original had the opposite symptom: SHORT_ONLY was small positive in 2025 while LONG_ONLY was bad. This is not proof that short is solved. It indicates the entry construction is unstable across branches and years.

The most defensible interpretation is that direction behavior is an output of poor regime and wave-position detection, not a stable directional edge yet.

## Scan Interval Decision

Use 5m or 10m for research. 10m is acceptable for faster diagnostic cycles when the goal is broad filtering or OOS sanity checks. Keep 5m for entry-timing work because the next problem is precise lower-timeframe reversal timing.

Do not switch to 15m as an improvement. The 2025 drawdown reduction appears mostly trade-count reduction, and OOS does not support it.

## All Candidates Decision

All Candidates mode should remain a diagnostic mode. It helps reveal which symbol/direction/regime buckets are actually carrying expectancy, but it is not a live candidate because it can inflate exposure and does not fix the 2025 edge problem.

Best Only may discard some candidates, but the All Candidates evidence does not show a broad enough hidden edge to redesign ranking yet. Ranking is a later task after entry quality is fixed.

## ThirdWave Failure Classification

| Category | Verdict |
|---|---|
| Higher timeframe trend recognition | Weak. `no_higher_tf_trend` dominates stage failures, and regime filtering helps but not enough. |
| Mid timeframe pullback quality | Relevant but secondary. v2 pullback filters reduce weak cases but over-filter and concentrate exposure. |
| Lower timeframe reversal timing | Primary failure. Wave Audit shows entries are mostly `chasing_entry`, not third-wave initial entries. |
| SL/TP design | Not first. Changing exits now would hide whether entries are structurally valid. |
| Regime classification | Important second priority. It improves some OOS windows but cannot fix late entries. |
| Execution and scan conditions | Runtime/log concern, not edge root cause. 5m/10m remain the useful research intervals. |
| Research design | High risk of XAUUSD and period-specific conclusions. Annual/OOS gates must remain strict. |

## Decision

Do not abandon the entire ThirdWave direction yet, because regime-aware variants show some OOS signal and the diagnostic tooling is now strong. But do abandon the idea that the current ThirdWave is already a valid third-wave initial entry model.

The next phase should be a narrowly scoped entry-timing / wave-position diagnostic branch. It must prove that entries can move from `chasing_entry` toward `third_wave_initial` or `third_wave_middle` without merely cutting trades or concentrating into XAUUSD.
""",
        encoding="utf-8",
    )

    candidates.write_text(
        """# Next Phase Candidates

## 1. Entry Timing v3 / Wave-Position Gate

- Aim: stop entering after the move has already run.
- Failure cause addressed: lower timeframe reversal timing and chasing entries.
- Implementation difficulty: medium.
- Overfit risk: medium, controlled by short-period plus annual OOS gates.
- Expected improvement: higher average R, fewer late/chasing entries, cleaner wave labels.
- Evidence: Wave Audit classified 100 audited trades as `chasing_entry` and only 1 as `third_wave_initial`.
- Minimal change: add a separate research branch that requires the lower reversal to be close to the reclaim/breakdown and pullback extreme, and records the wave-position label before entry.
- Reason not to skip: this is the clearest root cause.

## 2. Regime Quality v2

- Aim: distinguish trend, range, transition, and exhaustion more strictly.
- Failure cause addressed: higher timeframe trend and regime classification.
- Implementation difficulty: medium-high.
- Overfit risk: medium-high.
- Expected improvement: fewer range/exhaustion trades.
- Evidence: regime-aware ThirdWave improved 2024/2026YTD but did not solve 2025.
- Minimal change: add trend-age, swing freshness, and exhaustion counters before entry.
- Reason to defer: current entries are still too late even inside allowed regimes.

## 3. Pullback Quality Filter

- Aim: reject shallow noise and deep trend-breaking pullbacks.
- Failure cause addressed: mid timeframe pullback quality.
- Implementation difficulty: medium.
- Overfit risk: high if thresholds are tuned.
- Expected improvement: fewer invalid structures.
- Evidence: v2 filters removed deep/old setups but over-filtered and concentrated XAUUSD.
- Minimal change: make pullback quality a diagnostic gate with fixed audit-derived bands.
- Reason to defer: v2 already showed this alone is not enough.

## 4. Multi-Symbol Candidate Ranking

- Aim: use All Candidates evidence to choose better candidates instead of only the top score.
- Failure cause addressed: research design and candidate selection.
- Implementation difficulty: high.
- Overfit risk: high.
- Expected improvement: avoid choosing weak symbols when multiple candidates pass.
- Evidence: All Candidates mode exposes hidden buckets but did not prove broad 2025 edge.
- Minimal change: rank only among candidates that pass a future wave-position gate.
- Reason to defer: ranking bad entries better still leaves bad entries.

## 5. Structure TP / Exit Diagnostics

- Aim: test whether fixed R exits are mismatched to structure.
- Failure cause addressed: SL/TP design.
- Implementation difficulty: medium.
- Overfit risk: medium.
- Expected improvement: better realized R if entries are valid.
- Evidence: fixed R may be inefficient, but entry quality is not yet proven.
- Minimal change: add exit-opportunity diagnostics without changing TP.
- Reason to defer: entry timing is the current bottleneck.

## Priority

1. Entry Timing v3 / Wave-Position Gate
2. Regime Quality v2
3. Pullback Quality Filter
4. Multi-Symbol Candidate Ranking
5. Structure TP / Exit Diagnostics
""",
        encoding="utf-8",
    )

    recommended.write_text(
        """# Recommended Next Task

- task_name: ThirdWave Entry Timing v3 Wave-Position Diagnostic Branch
- reason: The strongest evidence says current ThirdWave is not entering third-wave initial positions. Wave Audit is dominated by `chasing_entry`; v2 reduced weak setups but did not change the core wave-position problem.
- expected_benefit: Improve average R and reduce late/chasing losses without escaping into XAUUSD-only or direction-only filtering.
- why_not_other_tasks: Regime filtering helps but still leaves late entries. Pullback filters already over-filtered in v2. SL/TP work would mask bad entries. Candidate ranking should wait until candidate quality is real.
- minimal_implementation: Add a separate research mode that keeps existing ThirdWave structure but gates final entry by wave-position quality: reclaim/breakdown proximity, bars since reclaim/breakdown, distance from pullback extreme, and pre-entry momentum exhaustion. Keep all values fixed from audit distributions, not optimized.
- validation_plan: First run the same short windows used for Wave Audit and v2: 2025-02, 2025-08, 2025-10, and 2026-Q1. Compare against current ThirdWave regime BOTH all-candidates 5m. If it improves PF or avg_R without over-filtering, run annual 2024, 2025, and 2026YTD.
- stop_condition: Discard if 2 of 3 annual windows do not improve PF or avg_R. Discard as generic logic if FX net does not improve. Discard if trade count falls more than 50% without clear PF/avg_R improvement. Discard as generic logic if improvement is only XAUUSD. Split or park if only LONG or only SHORT improves. Discard if `third_wave_initial` plus `third_wave_middle` share does not materially rise and `chasing_entry` remains dominant.
""",
        encoding="utf-8",
    )

    devlog.write_text(
        """# 2026-06-04 - Multi-Currency Scanner Research Decision

## Summary

- Task: consolidate Phase2, OOS, ThirdWave, regime, scan interval, All Candidates, Wave Audit, and ThirdWave v2 evidence before starting another implementation cycle.
- Scope: reporting only. No EA logic, parameters, or tester configs were changed.

## Evidence

- Master comparison: `reports/backtest/research_master_comparison.csv`
- Failure matrix: `reports/backtest/failure_cause_matrix.csv`
- Decision report: `reports/backtest/research_decision_report.md`
- Candidate list: `reports/backtest/next_phase_candidates.md`
- Recommended task: `reports/backtest/recommended_next_task.md`

## Decision

- Do not promote the current Phase2 or ThirdWave branches.
- Do not optimize parameters yet.
- Treat Phase2 2025 LONG strength as OOS-weak and XAUUSD-influenced.
- Treat ThirdWave v2 as diagnostic, not validated, because its annual gate did not pass.
- The next research task should target ThirdWave entry timing and wave-position quality, not regime, SL/TP, or candidate ranking first.

## Rationale

- Wave Audit showed current ThirdWave is mostly `chasing_entry`, not clean third-wave initial entry.
- Regime filtering improves some years but does not solve 2025.
- All Candidates and scan interval comparisons did not reveal a broad multi-symbol edge.
- 15m scan improvement is likely trade-count reduction, not a stable edge.
""",
        encoding="utf-8",
    )


def main() -> None:
    master_rows = build_master_comparison()
    failure_rows = build_failure_matrix()

    write_csv(BACKTEST / "research_master_comparison.csv", master_rows, MASTER_COLUMNS)
    write_csv(
        BACKTEST / "failure_cause_matrix.csv",
        failure_rows,
        [
            "category",
            "severity",
            "confidence",
            "affected_modes",
            "evidence",
            "interpretation",
            "next_action",
        ],
    )
    write_markdown_reports(master_rows)


if __name__ == "__main__":
    main()
