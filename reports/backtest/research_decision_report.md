# Multi-Currency Score Scanner / ThirdWave Research Decision Report

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
