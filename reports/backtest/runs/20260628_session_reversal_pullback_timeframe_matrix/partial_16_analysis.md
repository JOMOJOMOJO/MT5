# Partial 16-Run Analysis: Session Reversal Pullback Timeframe Matrix

Date: 2026-07-01

## Scope

This note covers only the first 16 attempted rows from
`batch_status.csv` in the 72-run timeframe matrix.

The batch was intentionally stopped during row 17. This is a partial
execution checkpoint, not a final strategy verdict for the full matrix.

## Execution Status

- Rows 1-12: London first120 variants completed or were already complete.
- Row 13: `all_first120__current__no_be` produced a usable EA summary under
  the MT5 Common Files folder, but the batch runner marked it
  `completed_missing_artifacts` because the expected summary filename did not
  match the EA output filename.
- Row 14: `all_first120__current__be_1_1r` failed.
- Rows 15-16: `all_first120__h1_m15_m5_strict` variants were marked
  `completed_missing_artifacts` and are not usable for strategy analysis yet.

The EA summary CSV embeds the symbol list as an unquoted comma-separated field,
so normal CSV parsing shifts columns. Metrics below use corrected field
alignment and trade CSV evidence where available.

## Tradeful Runs

Only the `london_first120__h1_m15_m5_top_notopp` variants generated usable
closed trades in this partial set.

| run_id | trades | PF | avg_R | net | full_sl | tp | time_exit | be_triggered | be_exit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| london_first120__h1_m15_m5_top_notopp__no_be | 46 | 0.68 | -0.173 | -189.23 | 21 | 6 | 19 | 0 | 0 |
| london_first120__h1_m15_m5_top_notopp__be_1_1r | 46 | 0.70 | -0.160 | -176.14 | 21 | 6 | 18 | 5 | 1 |

Break-even at 1.1R slightly improved net and avg_R, but did not reduce full
SL count and did not materially improve drawdown. It is not a promotion reason.

## Main Findings

- The main reason trade count collapsed remains the HTF permission gate.
  Zero-trade London rows show large HTF rejection counts, and the all-symbol
  current/no-BE row had 45,408 HTF permission rejections with zero trades.
- Relaxing the top timeframe to opposite-filter-only can restore trades, but
  the first tradeful London result is negative.
- The prior small-sample London first120 result was not reproduced here.
  The reproduced London tradeful variants had 46 trades and PF below 0.70.
- No row in this 16-run partial set passes the 2025 shallow gate.
- No candidate should proceed to 3-year fixed BT or recent OOS from this partial
  evidence.

## Diagnostic Notes

- Symbol and direction differences are diagnostic only. They should not be used
  to repair the system by excluding symbols or directions.
- Pattern-level results suggest that some reversal patterns perform much worse
  than others, but pattern-only filtering would require a new validation cycle.
- Time-bucket results showed better outcomes later in the London first120
  window, but the sample is too small to promote a time-only rule.

## Next Step

Fix the artifact collection mismatch before continuing the long batch. The
priority is to determine whether the all-symbol rows are truly zero-trade or
whether the batch runner is failing to collect the EA output folder correctly.
