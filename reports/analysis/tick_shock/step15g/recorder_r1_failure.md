# Step 15G recorder r1 failure

Run `20260901_ts15g_economic_path_r1_202503` is retained as failed engineering evidence and is excluded from economic analysis.

- causal entry violations: 0
- duplicate path rows: 576
- shock TP/SL outcomes: 0
- dominant invalid reasons: `STALE_PATH_QUOTE`, `STALE_ENTRY_QUOTE`, and `INVALID_RISK`

Root causes:

1. Post-entry quotes were invalidated merely because global-merge processing lag exceeded one second. Once a causal executable entry exists, a server-side barrier path is defined by later same-symbol market quotes; processing lag remains a diagnostic and must not erase the path.
2. `OnDeinit` explicitly finalized contexts immediately before the normal episode/control writer finalized them again, creating duplicate end-of-data rows.

The fix removes processing-age invalidation from post-entry path observation, retains decision-snapshot validity as the stale/fallback gate, and uses one finalization path at end of data. Regression `TS15G-INTEGRITY-011` protects the lag behavior. r1 is not used for model, label, or candidate results.
