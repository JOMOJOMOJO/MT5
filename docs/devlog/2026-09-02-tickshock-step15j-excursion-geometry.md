# Tick-shock Step 15J: excursion before barrier design

Step 15J added a bounded research-only recorder to measure executable Bid/Ask excursion for 60 minutes after the existing persistent-shock decision clock. It did not change detector, episode, strategy, RR, watermark, or order behavior.

The March run preserved 21,799 detector events and 3,151 episodes. The key finding is structural: the existing `max(0.25 ATR, 4 spread, broker minimum)` stop was spread-dominated in every one of 2,732 analysis-ready episodes, producing a median 1.626 ATR stop and 1.957 ATR target. Meanwhile, coarse 0.20-0.50 ATR moves were commonly reached, but often only after 0.85-0.95 ATR median adverse excursion. This does not yield a clean 1.2R geometry without a direction/entry condition.

Evidence:

- [formal run](../../reports/backtest/runs/20260902_ts15j_post_shock_excursion_r2_202503/summary.md)
- [research result](../research/tick_shock/15j_post_shock_excursion_tp_sl_holding_results.md)
- [horizon summary](../../reports/analysis/tick_shock/step15j/horizon_excursion_summary.csv)
- [pre-TP MAE](../../reports/analysis/tick_shock/step15j/pre_tp_mae_summary.csv)

Decision: keep production unchanged. A later study must preregister direction-conditioned conversion and complete commission/tick-quality evidence before freezing TP, SL, or holding time.
