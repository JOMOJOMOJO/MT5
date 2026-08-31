# Step 15G recorder r2 failure

Run `20260901_ts15g_economic_path_r2_202503` is retained as failed engineering evidence and is excluded from economic analysis.

- causal entry violations: 0
- duplicate path rows: 384
- missing shock subjects relative to Step 15F episodes: 8
- valid first-touch outcomes were observed, but the identity gate failed

Root cause: after a completed episode was written, the medium-horizon context remained in cooldown briefly. The empty economic-path context could re-arm the already-written subject from the still-present decision snapshots. That stale subject then blocked the next subject and was written a second time.

`TS15GResetAfterWrite` now retains the completed subject ID solely as a dedup tombstone. `TS15GArmDecision` rejects that same subject during cooldown. Regression `TS15G-INTEGRITY-012` covers the production-domain behavior. r2 is not used for labels, models, or candidate conclusions.
