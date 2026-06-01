# ExpectedValue LongOnly BucketLab Initial 2025 Backtest

## Scope

- EA: `mql/Experts/ExpectedValue_LongOnly_BucketLab.mq5`
- Preset: `reports/presets/ExpectedValue_LongOnly_BucketLab_usd100_initial_2025.set`
- Symbol: `USDJPY`
- Period: `2025.01.01` to `2025.12.31`
- Tester period: `M1`
- Execution / Quality / Bias / Trend / Avoid: `M1 / M5 / M15 / H1 / H4`
- Deposit: `100 USD`
- OOS `2026 Jan-Apr`: not run.
- Execution environment: isolated portable MT5 under `C:/Users/windows/AppData/Local/CodexMT5BucketLab` because the normal terminals are live-operation terminals.

## Run Status

- Compile: 0 errors / 0 warnings
- Backtest completion: completed, terminal exit code 0.
- Preset loaded: yes. Tester log shows `InpEnableTrading=true` and `InpEventLogFileName=mt5_company_expected_value_long_bucketlab_2025_events.csv`.
- Final balance: `100.78 USD`.
- Ruin / margin failure: not observed.
- Stop-condition events: `0`.
- Tester report: `long_bucketlab_usd100_initial_2025.htm`
- Raw EA CSV: `raw/mt5_company_expected_value_long_bucketlab_2025_events.csv`

## Overall Metrics

| metric | value |
| --- | --- |
| closed_trades | 9 |
| trades_per_day_approx_260d | 0.0346 |
| winrate | 44.44% |
| avg_win_r | 1.3564 |
| avg_loss_r | -0.8452 |
| expectancy_r | 0.1333 |
| profit_factor | 1.2838 |
| total_r | 1.1995 |
| net_money | 0.78 |
| max_dd_percent_ea | 2.9273 |
| max_consecutive_losses | 2 |

## Decision

Do **not** proceed to 2026 Jan-Apr OOS from this initial preset.

Reason: expectancy is positive and PF is above 1.05, but trade count is only `9`, which is lower than the old strict 2025 baseline of `23` trades. The main objective was to preserve strict quality while increasing frequency; this initial BucketLab did not achieve that.

The candidate is not a ruin-risk failure: no DD stop, daily stop, weekly stop, or loss-streak stop fired, MaxDD was low, and the 100 USD fixed-lot path survived. The failure is frequency, not survival.

## Bucket Analysis

| bucket | trades | winrate | avg_win_r | avg_loss_r | expectancy_r | PF | total_r |
| --- | --- | --- | --- | --- | --- | --- | --- |
| BREAKOUT_ACCEPTANCE_RETEST_LONG | 1 | 0.0% | 0.0000 | -0.1871 | -0.1871 | 0.0000 | -0.1871 |
| M1_PULLBACK_EXECUTION_LONG | 8 | 50.0% | 1.3564 | -1.0098 | 0.1733 | 1.3433 | 1.3867 |

Readout:

- `M1_PULLBACK_EXECUTION_LONG` is viable as a quality bucket but too sparse: 8 trades, ExpectancyR `+0.1733`, PF `1.3433`.
- `BREAKOUT_ACCEPTANCE_RETEST_LONG` produced only 1 trade and lost `-0.1871R`. This is not enough evidence, but it did not add useful frequency in this preset.

## Exit Reason Analysis

| exit_reason | trades | winrate | avg_win_r | avg_loss_r | expectancy_r | PF | total_r |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SL | 4 | 0.0% | 0.0000 | -1.0098 | -1.0098 | 0.0000 | -4.0391 |
| TIMEOUT | 2 | 50.0% | 1.1707 | -0.1871 | 0.4918 | 6.2561 | 0.9836 |
| TP | 3 | 100.0% | 1.4183 | 0.0000 | 1.4183 | 0.0000 | 4.2550 |

Readout:

- `TP` exits were strong but only 3 trades.
- `SL` exits averaged about `-1R`, as expected.
- `TIMEOUT` was not the problem in this run: 2 trades, net positive ExpectancyR `+0.4918`.

## SL / TP Mode Analysis

### SL mode

| sl_mode | trades | winrate | avg_win_r | avg_loss_r | expectancy_r | PF | total_r |
| --- | --- | --- | --- | --- | --- | --- | --- |
| HYBRID | 9 | 44.4% | 1.3564 | -0.8452 | 0.1333 | 1.2838 | 1.1995 |

### TP mode

| tp_mode | trades | winrate | avg_win_r | avg_loss_r | expectancy_r | PF | total_r |
| --- | --- | --- | --- | --- | --- | --- | --- |
| FIXED_R | 9 | 44.4% | 1.3564 | -0.8452 | 0.1333 | 1.2838 | 1.1995 |

Only `HYBRID` SL and `FIXED_R` TP were used in this initial preset, so this run does not compare SL/TP modes yet.

## Monthly Analysis

| month | trades | net_money | total_r | expectancy_r | PF |
| --- | --- | --- | --- | --- | --- |
| 202501 | 1 | 1.08 | 1.3500 | 1.3500 | 0.0000 |
| 202505 | 3 | -1.29 | -0.5965 | -0.1988 | 0.7057 |
| 202507 | 2 | 0.62 | 0.1584 | 0.0792 | 1.1565 |
| 202508 | 1 | -0.77 | -1.0000 | -1.0000 | 0.0000 |
| 202509 | 1 | -0.32 | -0.1871 | -0.1871 | 0.0000 |
| 202510 | 1 | 1.46 | 1.4747 | 1.4747 | 0.0000 |

Readout:

- The result is not concentrated in only one winning month, but the sample is too small to judge monthly robustness.
- Active months were sparse: only 6 months had trades.
- May had 3 trades and was negative; Jan and Oct each had one profitable trade.

## Relative Metrics Analysis

### spread_atr
| bin | trades | winrate | expectancy_r | PF |
| --- | --- | --- | --- | --- |
| 0.10-0.12 | 9 | 44.4% | 0.1333 | 1.2838 |

### atr_ratio
| bin | trades | winrate | expectancy_r | PF |
| --- | --- | --- | --- | --- |
| 1.10-1.50 | 6 | 66.7% | 0.5689 | 2.6962 |
| 1.50-inf | 3 | 0.0% | -0.7379 | 0.0000 |

### range_position
| bin | trades | winrate | expectancy_r | PF |
| --- | --- | --- | --- | --- |
| 0.55-0.75 | 1 | 100.0% | 1.1707 | 0.0000 |
| 0.75-0.92 | 8 | 37.5% | 0.0036 | 1.0068 |

### body_atr
| bin | trades | winrate | expectancy_r | PF |
| --- | --- | --- | --- | --- |
| -inf-0.15 | 3 | 33.3% | -0.1792 | 0.7328 |
| 0.15-0.35 | 2 | 50.0% | 0.1650 | 1.3235 |
| 0.35-0.70 | 3 | 66.7% | 0.5314 | 2.5836 |
| 0.70-inf | 1 | 0.0% | -0.1871 | 0.0000 |

### wick_atr
| bin | trades | winrate | expectancy_r | PF |
| --- | --- | --- | --- | --- |
| -inf-0.03 | 1 | 0.0% | -0.1871 | 0.0000 |
| 0.03-0.08 | 2 | 50.0% | 0.0754 | 1.1478 |
| 0.08-0.15 | 4 | 25.0% | -0.3861 | 0.4885 |
| 0.15-inf | 2 | 100.0% | 1.3901 | 0.0000 |

### ema_deviation_atr
| bin | trades | winrate | expectancy_r | PF |
| --- | --- | --- | --- | --- |
| 0.25-0.50 | 2 | 0.0% | -0.5969 | 0.0000 |
| 0.50-0.80 | 4 | 75.0% | 0.7489 | 3.9955 |
| 0.80-1.20 | 3 | 33.3% | -0.2007 | 0.7037 |

### distance_recent_high_atr
| bin | trades | winrate | expectancy_r | PF |
| --- | --- | --- | --- | --- |
| 0.25-0.75 | 4 | 25.0% | -0.4206 | 0.4452 |
| 0.75-1.50 | 3 | 66.7% | 0.9059 | 15.5234 |
| 1.50-inf | 2 | 50.0% | 0.0820 | 1.1629 |

### distance_recent_low_atr
| bin | trades | winrate | expectancy_r | PF |
| --- | --- | --- | --- | --- |
| 1.50-3.00 | 3 | 0.0% | -0.7313 | 0.0000 |
| 3.00-inf | 6 | 66.7% | 0.5656 | 2.6697 |

### recent_range_atr
| bin | trades | winrate | expectancy_r | PF |
| --- | --- | --- | --- | --- |
| 2.00-4.00 | 4 | 25.0% | -0.2124 | 0.6138 |
| 4.00-inf | 5 | 60.0% | 0.4098 | 2.0110 |

### pullback_depth_atr
| bin | trades | winrate | expectancy_r | PF |
| --- | --- | --- | --- | --- |
| 0.00-0.40 | 6 | 33.3% | -0.0968 | 0.8200 |
| 0.40-0.80 | 2 | 50.0% | 0.1750 | 1.3500 |
| 0.80-1.20 | 1 | 100.0% | 1.4302 | 0.0000 |

### breakout_acceptance_atr
| bin | trades | winrate | expectancy_r | PF |
| --- | --- | --- | --- | --- |
| -inf-0.00 | 6 | 66.7% | 0.5689 | 2.6962 |
| 0.00-0.10 | 1 | 0.0% | -1.0067 | 0.0000 |
| 0.10-0.30 | 1 | 0.0% | -1.0200 | 0.0000 |
| 0.30-inf | 1 | 0.0% | -0.1871 | 0.0000 |

### up_pressure
| bin | trades | winrate | expectancy_r | PF |
| --- | --- | --- | --- | --- |
| 0.52-0.65 | 5 | 20.0% | -0.3712 | 0.4211 |
| 0.65-inf | 4 | 75.0% | 0.7639 | 3.9958 |

### down_pressure
| bin | trades | winrate | expectancy_r | PF |
| --- | --- | --- | --- | --- |
| -inf-0.35 | 4 | 75.0% | 0.7639 | 3.9958 |
| 0.35-0.48 | 5 | 20.0% | -0.3712 | 0.4211 |


## Time Diagnostics

### Hour

| hour | trades | winrate | avg_win_r | avg_loss_r | expectancy_r | PF | total_r |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 10 | 2 | 50.0% | 1.4747 | -0.1871 | 0.6438 | 7.8807 | 1.2876 |
| 11 | 1 | 100.0% | 1.1707 | 0.0000 | 1.1707 | 0.0000 | 1.1707 |
| 12 | 1 | 0.0% | 0.0000 | -1.0067 | -1.0067 | 0.0000 | -1.0067 |
| 17 | 3 | 33.3% | 1.3500 | -1.0062 | -0.2208 | 0.6709 | -0.6623 |
| 18 | 1 | 100.0% | 1.4302 | 0.0000 | 1.4302 | 0.0000 | 1.4302 |
| 23 | 1 | 0.0% | 0.0000 | -1.0200 | -1.0200 | 0.0000 | -1.0200 |

### Day Of Week

| day_of_week | trades | winrate | avg_win_r | avg_loss_r | expectancy_r | PF | total_r |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 1 | 0.0% | 0.0000 | -1.0067 | -1.0067 | 0.0000 | -1.0067 |
| 3 | 1 | 0.0% | 0.0000 | -1.0200 | -1.0200 | 0.0000 | -1.0200 |
| 4 | 6 | 66.7% | 1.3564 | -1.0062 | 0.5689 | 2.6962 | 3.4134 |
| 5 | 1 | 0.0% | 0.0000 | -0.1871 | -0.1871 | 0.0000 | -0.1871 |

These are diagnostics only. No hour/day filter should be promoted from this sample because there are only 9 trades.

## Stop Condition Log Check

No stop-condition events were logged.

## Candidate Reject Top Reasons

| reason | count |
| --- | --- |
| spread_atr_too_wide | 357317 |
| atr_ratio_too_high | 7031 |
| ema_trend_filter_failed | 4340 |
| h4_strong_bear_avoid | 700 |
| ema_deviation_atr_too_large | 483 |
| body_atr_too_large | 212 |
| adx_too_high | 180 |
| price_below_slow_ema | 152 |
| bucket_setup_failed | 130 |
| range_position_too_high | 128 |
| range_position_too_low | 113 |
| bias_score_too_low | 46 |

The reject distribution confirms that the quality gates are very tight. The main blockers are `spread_atr_too_wide`, `range_position_too_low`, and `h4_strong_bear_avoid`. This explains why M1 execution did not increase frequency enough.

## Next Action

Do not run OOS yet. Review 2025 design first.

Recommended next 2025-only revisions:

1. Keep `M1_PULLBACK_EXECUTION_LONG`, but loosen only non-spread frequency bottlenecks in a controlled way: `range_position`, `H4 avoid`, and `bias_score` should be examined one at a time.
2. Disable or redesign `BREAKOUT_ACCEPTANCE_RETEST_LONG` until it produces enough 2025 trades to evaluate; current evidence is one losing trade.
3. Keep `InpMaxSpreadATR=0.12` for the next probe. Do not use spread loosening as the frequency lever.
4. Run a small 2025-only matrix across SL modes: `HYBRID` vs `M1_SWING` vs `M5_SWING`, because the current result is positive but too sparse and only one SL design has been tested.
5. Consider setting `InpLogNoSignalDiagnostics=false` for future full-year speed runs after reject bottlenecks are known; keep it on for diagnostic probes.
