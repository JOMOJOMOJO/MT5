# Tick-shock Step 15G economic paths

Step 15G replaced fixed-horizon directional return as the economic label with online actual-Bid/Ask first-touch paths. Two discarded engineering runs exposed merge-lag invalidation, duplicate finalization and completed-subject re-arm; each is now protected by a production-domain regression.

The accepted March run and independent analysis are linked from:

- `reports/backtest/runs/20260901_ts15g_economic_path_r3_202503/summary.md`
- `docs/research/tick_shock/15g_economic_path_results.md`
- `reports/qa/tick_shock/step15g_final_qa.md`

The useful research lesson is that classification AUC is not an economic gate. Although success/failure is distinguishable in development data, every OOF stress policy is non-positive and commission/control evidence is incomplete. No hypothesis was frozen.
