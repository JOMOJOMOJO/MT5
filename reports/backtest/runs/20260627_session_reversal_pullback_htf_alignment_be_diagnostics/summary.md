# Session Reversal Pullback HTF Alignment and Break-Even Diagnostics

## Implementation
- Compared four coarse HTF alignment modes without symbol, direction, weekday, or fine threshold rescue.
- Compared four break-even modes: no BE, +1.0R close, +1.1R close, and 30min/+0.5R or +1.0R close.
- Break-even triggers use M15 closed-bar close only; intrabar high/low is not used to trigger BE.
- MFE/MAE are diagnostic values from closed bars and exit price.

## Required Answers
1. Trade-count drop cause: yes for trade count. all_symbols no_BE was strict=163 trades PF=0.81 avg_R=-0.1008; h4_bias_h1_rev=347 trades PF=0.75 avg_R=-0.1296; h1_conf_h4_notopp=527 trades PF=0.79 avg_R=-0.1019; soft=645 trades PF=0.81 avg_R=-0.0982. Strict H4/H1 hard alignment was the main throttle, but not the reason expectancy was negative.
2. Relaxed alignment recovery: yes, all_symbols no_BE recovered beyond 200 trades under relaxed modes; best recovered no_BE row was `all_first120__soft__no_be` with 645 trades, PF=0.81, avg_R=-0.0982.
3. Expectancy-preserving alignment relaxation: none. Best all_symbols row with >=200 trades was `all_first120__h4_bias_h1_rev__be_30m_0_5r` trades=353 PF=0.79 avg_R=-0.0954, still negative.
4. Full SL reduction: all_symbols no_BE full_sl_rate=45.54%; best all_symbols BE mode `break_even_at_1_1r` full_sl_rate=44.35%. Time-based BE reduced full SL most but increased BE exits and did not improve expectancy.
5. BE effect: best all_symbols BE by avg_R/PF was `break_even_at_1_1r` avg_R=-0.0983, PF=0.80, MaxDD=3761.59; all_symbols no_BE avg_R=-0.1061, PF=0.79, MaxDD=4102.66.
6. BE exits: best all_symbols BE break_even_exit_rate=2.38%. Time-based BE had 16.81% BE exits and lower TP rate, so it likely cut winners too often.
7. Best BE mode by all_symbols avg_R/PF: `break_even_at_1_1r`. Across all scenarios, best aggregate BE bucket was `break_even_at_1_1r`.
8. London first120: best no_BE `london_first120__strict__no_be` avg_R=0.4674, PF=2.40, trades=26; best BE `london_first120__strict__be_1_1r` avg_R=0.5070, PF=2.70, trades=26.
9. 2025 shallow gate pass candidates: none.
10. 3-year fixed BT/OOS: no candidate advances.

## Best Gate-Scope Row Before Trade-Count Gate
- `clean_first120__h4_bias_h1_rev__be_30m_0_5r` trades=27 PF=1.23 avg_R=0.0725 net=49.71 MaxDD=119.91. This is not a live/fixed-BT candidate when trades are below 200.

## Evidence
- `comparison.csv`
- `htf_alignment_mode_breakdown.csv`
- `break_even_mode_breakdown.csv`
- `exit_type_breakdown.csv`
- `mfe_mae_breakdown.csv`
- `session_break_even_breakdown.csv`
- `symbol_break_even_breakdown.csv`
- `entry_pattern_break_even_breakdown.csv`
