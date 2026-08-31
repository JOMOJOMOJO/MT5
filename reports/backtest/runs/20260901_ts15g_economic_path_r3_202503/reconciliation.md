# Independent reconciliation

The independent Step 15G analyzer read the online `economic_first_touch.csv`; it did not reconstruct arbitrary barriers from checkpoint returns.

- path rows: 430,224
- unique shock subjects: 3,151
- unique matched-control subjects: 5,884
- duplicate `(subject, type, decision, action, RR, horizon)` keys: 0
- `entry_quote_msc <= signal_quote_msc`: 0
- `entry_quote_msc < signal_processing_msc`: 0
- `realized_rr < requested_rr`: 0
- production orders: 0
- feature spec hashes: 1
- label spec hashes: 1
- primary RR1.2 non-GBPUSD valid shock rows: 9,990
- primary subjects: 2,228
- primary market clusters: 2,086

The 9,990 primary rows are subject-decision-horizon observations, not independent trades. Statistical grouping retains the market-cluster identity.

All checks in `reports/analysis/tick_shock/step15g/final_qa.csv` pass.
