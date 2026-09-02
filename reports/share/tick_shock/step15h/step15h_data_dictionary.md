# Step 15H compact data dictionary

- One row in `step15h_detection_time_episodes_compact.csv` is one causal 15-minute episode representative.
- `t0_msc` is the processing clock at which persistent confirmation was usable.
- `c0_r` uses observed Bid/Ask; `c2_r` uses 1.25x spread and one tick adverse entry and exit stress.
- `primary_eligible` excludes GBPUSD, unavailable causal features, fallback paths and invalid outcomes.
- March 2025 is reused development data, not OOS.
- `step15h_filter_policy_comparison.csv` reports policy value as selected return sum divided by all eligible episodes.
