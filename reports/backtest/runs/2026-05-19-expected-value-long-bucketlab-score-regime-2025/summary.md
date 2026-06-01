# ExpectedValue LongOnly BucketLab Score-Regime 2025 Backtest

## Scope

- EA: `mql/Experts/ExpectedValue_LongOnly_BucketLab.mq5`
- Preset: `reports/presets/ExpectedValue_LongOnly_BucketLab_usd100_score_regime_2025.set`
- Symbol: `USDJPY`
- Period: `2025.01.01` to `2025.12.31`
- Tester period: `M1`; context: `M5 / M15 / H1 / H4`
- Deposit: `100 USD`; fixed lot under 300 USD: `0.01`
- OOS `2026 Jan-Apr`: not run.
- Execution environment: isolated portable MT5 under `C:/Users/windows/AppData/Local/CodexMT5BucketLab`.

## Run Status

- Compile: `0 errors / 0 warnings`.
- Backtest completion: completed, terminal exit code `0`.
- Preset loaded: yes. Tester log shows `InpEnableTrading=true`, `InpEventLogFileName=mt5_company_expected_value_long_bucketlab_score_regime_2025_events.csv`, old buckets disabled.
- Final balance: `123.92 USD`.
- Ruin / margin failure: not observed.
- Stop-condition events: `0`.

## Overall Metrics

| metric | value |
| --- | --- |
| closed_trades | 119 |
| trades_per_day_approx_260d | 0.4577 |
| winrate | 51.26% |
| avg_win_r | 1.0805 |
| avg_loss_r | -0.8331 |
| expectancy_r | 0.1478 |
| profit_factor | 1.3640 |
| total_r | 17.5886 |
| net_money | 23.92 |
| max_dd_percent_ea | 12.4566 |
| max_consecutive_losses | 5 |

## Decision

Proceed to a controlled 2026 Jan-Apr OOS check next, but do not tune on OOS. This 2025 score-regime run meets the current research gate: no ruin, no stop-condition trigger, 119 trades versus the old BucketLab 9 and old strict 23, positive ExpectancyR, PF above 1.05, MaxDD below 20-25%, and max losing streak 5.

Caveat: trades/day is still far below the eventual 5/day target. The improvement is framework-level frequency and survival, not final production turnover.

## Bucket Analysis

| bucket | trades | winrate | avg_win_r | avg_loss_r | expectancy_r | PF | total_r |
| --- | --- | --- | --- | --- | --- | --- | --- |
| M1_PULLBACK_SCORE_LONG | 119 | 51.3% | 1.0805 | -0.8331 | 0.1478 | 1.364006 | 17.5886 |

## Exit Reason Analysis

| exit_reason | trades | winrate | avg_win_r | avg_loss_r | expectancy_r | PF | total_r |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SL | 44 | 0.0% | 0.0000 | -1.0189 | -1.0189 | 0.000000 | -44.8320 |
| TIMEOUT | 34 | 58.8% | 0.5059 | -0.2491 | 0.1950 | 2.901428 | 6.6310 |
| TP | 41 | 100.0% | 1.3607 | 0.0000 | 1.3607 | inf | 55.7896 |

## SL Mode Analysis

| sl_mode | trades | winrate | avg_win_r | avg_loss_r | expectancy_r | PF | total_r |
| --- | --- | --- | --- | --- | --- | --- | --- |
| HYBRID | 119 | 51.3% | 1.0805 | -0.8331 | 0.1478 | 1.364006 | 17.5886 |

## TP Mode Analysis

| tp_mode | trades | winrate | avg_win_r | avg_loss_r | expectancy_r | PF | total_r |
| --- | --- | --- | --- | --- | --- | --- | --- |
| FIXED_R | 119 | 51.3% | 1.0805 | -0.8331 | 0.1478 | 1.364006 | 17.5886 |

## Monthly Analysis

| month | trades | winrate | avg_win_r | avg_loss_r | expectancy_r | PF | total_r |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 202501 | 12 | 41.7% | 1.0595 | -0.8080 | -0.0299 | 0.936618 | -0.3585 |
| 202502 | 9 | 88.9% | 0.9684 | -1.0233 | 0.7471 | 7.571170 | 6.7240 |
| 202503 | 11 | 36.4% | 0.6663 | -1.0234 | -0.4089 | 0.372046 | -4.4983 |
| 202504 | 40 | 47.5% | 1.1090 | -0.8293 | 0.0914 | 1.209868 | 3.6550 |
| 202505 | 11 | 36.4% | 1.3507 | -0.6690 | 0.0654 | 1.153596 | 0.7193 |
| 202506 | 8 | 50.0% | 1.3744 | -0.8787 | 0.2479 | 1.564179 | 1.9829 |
| 202507 | 7 | 57.1% | 1.1177 | -0.7218 | 0.3293 | 2.064463 | 2.3051 |
| 202508 | 5 | 80.0% | 0.9192 | -1.0076 | 0.5338 | 3.649175 | 2.6692 |
| 202509 | 5 | 60.0% | 1.3525 | -0.3118 | 0.6868 | 6.506376 | 3.4339 |
| 202510 | 7 | 57.1% | 1.0519 | -1.0095 | 0.1684 | 1.389299 | 1.1790 |
| 202511 | 4 | 50.0% | 0.9072 | -1.0188 | -0.0558 | 0.890496 | -0.2231 |

## Relative Metrics Files

- `analysis_relative_metrics.csv` contains bins for score, Spread/ATR, Spread/Risk, ATR ratio, Range position, Body/ATR, Wick/ATR, EMA deviation/ATR, recent high/low distance, recent range, pullback depth, breakout acceptance, pressure, and risk distance.
- `analysis_candidate_scores.csv` contains candidate score event counts and score reject reasons.
- `analysis_hour.csv` and `analysis_day_of_week.csv` are diagnostics only; no time/day filter is promoted from this run.

## Stop Conditions

- Stop-condition rows: `0`.
- Daily, weekly, drawdown, and loss-streak stops did not fire in the accepted score-regime run.

## Failed Loose-Score Control

Before this accepted score-regime run, a loose score-only run produced 113 trades, ExpectancyR `-0.2275`, PF `0.5994`, MaxDD `35.01%`, and drawdown stop. That failure is the reason the final bucket requires either a discount range pullback or an ATR-expansion deep pullback instead of treating the score threshold alone as sufficient.
