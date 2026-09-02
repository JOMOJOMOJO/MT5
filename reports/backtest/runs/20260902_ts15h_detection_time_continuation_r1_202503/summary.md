# Step 15H formal March development run

- Source commit: `a12e72ade081a544fe02f417009fbf499503ca8b`
- Source SHA-256: `5CB3D3ED0A8B0097BFC3F1284AB511B29CE05793D902DC7F4A937A14ECE9FA73`
- EX5 SHA-256: `E2DA06EEDDC2119C7B52CA539CB0917A76553BAE443F4BD5FC8CE94A6F7878E9`
- Period/model: 2025-03-01 to 2025-04-01, real ticks, EURUSD M1 driver
- Symbols: EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF
- Detection snapshots: 3,151
- Detection first-touch paths: 28,359
- Primary eligible: 1,818 episodes / 1,709 market clusters
- Primary first touch: TP 277 / SL 743 / TIMEOUT 798
- Unfiltered policy value: C0 -0.2964 / C2 -0.3834 R per eligible episode
- Orders/trades: 0
- Causal QA violations: 0
- Verdict: `NO_DETECTION_TIME_CONTINUATION_FILTER_SUPPORTED`

GBPUSD is excluded from primary because its fallback interval map is unavailable. March 2025 is reused development data and is not OOS. Large raw artifacts over 50 MB remain in the run directory and are indexed by `reports/analysis/tick_shock/step15h/run_artifact_inventory.csv`; they are intentionally not committed.
