# Step 15B direction schema contract

- Schema: `tickshock-detector-feature-v2`
- Column: `direction`
- Domain: `LONG`, `SHORT`, `INVALID`
- Source: the signed triggering return at candidate time.
- Multi-horizon tie: the minimum Holm-adjusted p-value; equal p-values use the shorter horizon.
- `TAIL_V1_PERSISTENT`: retain the candidate-time direction through confirmation.
- Prohibited: inference from forward returns, strategy outcomes, or post-confirmation prices.
- No pre-existing detector feature column was removed or redefined.

The production-path contract is covered by `TS15B-DIR-*` in
`reports/tests/tick_shock/step15b_green/step15b_green_results.csv`.

