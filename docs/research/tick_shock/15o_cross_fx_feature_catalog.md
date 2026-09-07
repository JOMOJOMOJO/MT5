# Step 15O Cross-FX Feature Catalog

All values are computed as of the confirmed episode `t0`; blank means
unavailable and is never coerced to zero. Windows are fixed at 1, 3, 5 and 10
seconds. `_w` below expands to each window.

| Family | Field | Definition | Unit | Causal source |
|---|---|---|---|---|
| identity | episode/event/cluster/symbol/direction | Existing TAIL_V1_PERSISTENT identity | id | confirmed episode |
| clock | t0_msc, t0_processing_msc | event and realizable processing clocks | ms | episode arm |
| sign | target_usd_sign | shock direction converted to USD-strength sign | {-1,+1} | symbol orientation and shock |
| target | target_usd_return_atr_w | target raw return, USD signed, divided by completed M5 ATR14 | ATR | target as-of quotes |
| breadth | usd_breadth_count_w | other pairs agreeing with target USD sign | count 0..5 | five as-of joins |
| breadth | usd_breadth_w | agreeing count / valid count | ratio | five as-of joins |
| consensus | usd_consensus_median_w | median other USD return / ATR | ATR | valid other pairs |
| consensus | shock_aligned_usd_consensus_w | consensus x target USD sign | ATR | valid other pairs |
| residual | target_residual_w | target USD return / ATR minus other median | ATR | target and consensus |
| residual | shock_aligned_target_residual_w | residual x target USD sign | ATR | target and consensus |
| availability | valid_cross_symbols_w | valid other-pair return count | count | source validation |
| freshness | max/median_cross_quote_age_ms | t0 processing minus latest source quote | ms | as-of joins |
| lead | num_prior_cross_fx_movers | other pairs with aligned 5s return >=0.10 ATR before/by t0 | count | causal crossings |
| lead | first/median_cross_fx_lead_ms | target t0 minus other crossing times | ms | causal crossings |
| lead | target_leader_rank | target crossing order among six; ties by configured order | rank | causal crossings only |
| lead | target_lead_bucket | EARLY 1-2, MIDDLE 3-4, LATE 5-6, NO_CROSSING | label | fixed rank boundaries |
| status | feature_status | ELIGIBLE, TARGET_STALE, CROSS_SYMBOL_STALE, CROSS_SYMBOL_MISSING, DATA_INTEGRITY_INVALID | enum | integrity checks |

The long-form freshness evidence contains one row per episode x source symbol x
window with current quote time, anchor quote time, processing time, both ages,
ATR source time, USD return and availability reason. This is event-level
diagnostic output, not a tick log.

H1-H4 use only the frozen 5-second values documented in
`15o_cross_fx_lead_lag_preanalysis.md`. Other windows remain prespecified
diagnostics and cannot be selected from April performance.

