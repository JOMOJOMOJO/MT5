# Session Reversal Pullback HTF Alignment and Break-Even Exit Diagnostics

## Hypothesis

The latest Session Reversal Pullback EA may have failed the 2025 shallow gate because H4/H1 confirmed wave3 alignment was too strict. If trade count can be recovered without destroying expectancy, break-even exit management may reduce full SL exits and improve drawdown.

## Tested Matrix

- Scenarios:
  - `all_symbols_first120`
  - `one_symbol_first120`
  - `clean_target_path_first120`
  - `london_first120_reference`
  - `tokyo_first120_reference`
- HTF alignment modes:
  - strict H4/H1 both aligned
  - H4 bias with H1 reversal/first-pullback allowance
  - H1 confirmed with H4 not clearly opposite
  - soft HTF scoring, rejecting only both clearly opposite
- Break-even modes:
  - disabled
  - +1.0R
  - +1.1R
  - 30min and +0.5R, or +1.0R

## Outcome

Strict H4/H1 confirmed alignment was the main trade-count throttle:

- all_symbols strict no BE: 163 trades
- all_symbols h4_bias_h1_reversal no BE: 347 trades
- all_symbols h1_confirmed_h4_not_opposite no BE: 527 trades
- all_symbols soft no BE: 645 trades

Relaxing alignment recovered trade count, but did not recover edge:

- all recovered all_symbols no-BE rows stayed below PF 1.0.
- best all_symbols row with at least 200 trades was `all_first120__h4_bias_h1_rev__be_30m_0_5r`, 353 trades, PF 0.79, avg_R -0.0954.
- therefore the hard alignment explains under-trading, but the underlying setup pool remains negative.

Break-even management:

- +1.1R BE was the best all_symbols BE mode by avg_R/PF, improving avg_R from -0.1061 to -0.0983 and MaxDD from 4102.66 to 3761.59.
- The improvement was not enough to make the system viable.
- 30min/+0.5R BE reduced full SL rate from 45.54% to 40.79%, but BE exits rose to 16.81% and expectancy did not improve. It likely cuts too many potential winners.
- +1.0R BE was not better than +1.1R in the integrated pool.

London first120:

- London strict no BE remained strong: 26 trades, PF 2.40, avg_R +0.4674.
- London strict +1.1R BE improved to PF 2.70 and avg_R +0.5070.
- This is retained as a research fragment only; 26 trades is far below the promotion threshold and cannot justify fixed BT or live work.

## Decision

No candidate advances to 3-year fixed BT or OOS.

Reasons:

- No 2025 shallow gate pass.
- Trade-count recovery did not produce positive expectancy in the integrated all_symbols pool.
- Break-even exits improved damage control slightly but did not turn the system positive.
- Sparse London and clean-path fragments remain diagnostics, not operating candidates.

## Rejection Rule Applied

No post-hoc repair was attempted through:

- symbol exclusion;
- direction exclusion;
- Friday/weekday stopping;
- fine HTF alignment threshold tuning;
- fine break-even threshold tuning;
- extra wave-count narrowing.

## Evidence

- `reports/backtest/runs/20260627_session_reversal_pullback_htf_alignment_be_diagnostics/summary.md`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_alignment_be_diagnostics/comparison.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_alignment_be_diagnostics/break_even_mode_breakdown.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_alignment_be_diagnostics/exit_type_breakdown.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_alignment_be_diagnostics/mfe_mae_breakdown.csv`
