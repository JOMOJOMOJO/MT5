# 2026-06-27 Session Reversal Pullback HTF Alignment Relaxation and Break-Even Diagnostics

## Task

Test whether `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` lost too many trades because H4/H1 confirmed wave3 alignment was too strict, then compare break-even exit management on the broader HTF alignment modes.

This continues:

- `docs/devlog/2026-06-27-session-reversal-pullback-htf-obstacle-diagnostics.md`
- `knowledge/optimizations/2026-06-27-session-reversal-pullback-htf-obstacle-diagnostics.md`

## Implementation

- Added four HTF alignment modes:
  - `strict_h4_h1_alignment`
  - `h4_bias_h1_reversal_alignment`
  - `h1_confirmed_h4_not_opposite`
  - `htf_soft_alignment`
- Kept the modes deliberately coarse. No symbol exclusion, direction exclusion, weekday stop, or fine threshold rescue was added.
- Added four break-even modes:
  - `no_break_even`
  - `break_even_at_1_0R`
  - `break_even_at_1_1R`
  - `time_30min_and_0_5R_break_even`
- Break-even triggers use M15 closed-bar close only. Intrabar high/low is not used to trigger BE.
- Added trade diagnostics for initial/current SL, BE trigger state, BE trigger R/time, bars to BE, MFE/MAE, exit type, full SL/BE/TP/time exit flags, and before/after BE R metrics.
- Added `scripts/analyze-session-reversal-alignment-be.py` to collect 80 MT5 runs and produce comparison and breakdown CSVs.

## Validation

- Compile: `reports/compile/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_compile.txt`
- Compile result: `0 errors, 0 warnings`.
- MT5 2025 shallow BT matrix:
  - 5 scenarios
  - 4 HTF alignment modes
  - 4 break-even modes
  - 80 runs total
  - M15, Model 4, Deposit 10000
  - terminal: `C:\Program Files\XMTrading MT5\terminal64.exe`

## Result

No 2025 shallow gate pass.

The strict H4/H1 alignment was the main trade-count throttle, but not the source of negative expectancy:

| all_symbols no BE alignment | Trades | PF | avg_R |
|---|---:|---:|---:|
| strict | 163 | 0.81 | -0.1008 |
| h4_bias_h1_reversal | 347 | 0.75 | -0.1296 |
| h1_confirmed_h4_not_opposite | 527 | 0.79 | -0.1019 |
| soft | 645 | 0.81 | -0.0982 |

Best all_symbols row with at least 200 trades:

| Run | Trades | PF | avg_R |
|---|---:|---:|---:|
| `all_first120__h4_bias_h1_rev__be_30m_0_5r` | 353 | 0.79 | -0.0954 |

Break-even comparison on all_symbols:

| Mode | avg_R | PF | MaxDD | full SL rate | BE exit rate |
|---|---:|---:|---:|---:|---:|
| no BE | -0.1061 | 0.79 | 4102.66 | 45.54% | 0.00% |
| +1.1R BE | -0.0983 | 0.80 | 3761.59 | 44.35% | 2.38% |
| 30min/+0.5R BE | -0.1048 | 0.77 | 4038.43 | 40.79% | 16.81% |

London first120 remained the best fragment but is still too small to promote:

| Run | Trades | PF | avg_R |
|---|---:|---:|---:|
| `london_first120__strict__no_be` | 26 | 2.40 | +0.4674 |
| `london_first120__strict__be_1_1r` | 26 | 2.70 | +0.5070 |

## Decision

Do not advance any candidate to 3-year fixed BT or OOS.

Reasons:

- Relaxing HTF alignment restored all_symbols trade count above 200, but PF stayed below 1 and avg_R stayed negative.
- Break-even at +1.1R modestly improved all_symbols avg_R/PF/MaxDD, but the system remained negative.
- Time-based BE reduced full SL exits more, but BE exits rose too much and expectancy did not improve.
- London first120 is still an interesting fragment, but 26 trades is not enough and cannot be used as an upgrade basis.
- No prohibited repair was used.

## Evidence

- `reports/backtest/runs/20260627_session_reversal_pullback_htf_alignment_be_diagnostics/summary.md`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_alignment_be_diagnostics/comparison.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_alignment_be_diagnostics/htf_alignment_mode_breakdown.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_alignment_be_diagnostics/break_even_mode_breakdown.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_alignment_be_diagnostics/exit_type_breakdown.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_alignment_be_diagnostics/r_metrics.csv`
