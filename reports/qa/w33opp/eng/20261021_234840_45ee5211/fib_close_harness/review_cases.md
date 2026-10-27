# fib_close_harness: MQL5決定論テスト

実際のMT5内でエンジンを呼び出し、因果順序とLONG/SHORT分岐を確認する合成入力 128項目。PASS 128 / FAIL 0。市場の売買事例とは区別する。

原本: [harness.csv](harness.csv)。

| テスト | 判定 | 詳細 |
|---|---|---|
| backlog_old_sort_tie_regression | PASS | The actual two-hour grouped H1/M15/M5/M1 backlog reproduces the former M5-before-upper tie defect at minute 120 |
| backlog_shared_sort_chronological | PASS | The shared main/harness sorter processes all two-hour backlog bars by ascending close time |
| backlog_shared_sort_upper_priority | PASS | Every simultaneous close in the backlog is processed by descending timeframe duration |
| backlog_shared_sort_minute120_exact | PASS | At minute 120 the shared function returns H1 -> M15 -> M5 -> M1 |
| wick_without_deep_close_policy0_PERIOD_M15_PERIOD_M5_LONG | PASS | A wick beyond 61.8% with the upper close inside is not a close-policy exclusion |
| exact_boundary_allowed_policy0_PERIOD_M15_PERIOD_M5_LONG | PASS | An upper close exactly on the fixed boundary remains eligible |
| strict_close_policy0_PERIOD_M15_PERIOD_M5_LONG | PASS | One tradable point beyond the upper close boundary measures in control and excludes only with the new policy |
| close_evidence_policy0_PERIOD_M15_PERIOD_M5_LONG | PASS | The first violating upper candle |
| duplicate_close_no_repeat_policy0_PERIOD_M15_PERIOD_M5_LONG | PASS | A duplicate upper input cannot repeat or backdate the first close observation |
| wick_without_deep_close_policy1_PERIOD_M15_PERIOD_M5_LONG | PASS | A wick beyond 61.8% with the upper close inside is not a close-policy exclusion |
| exact_boundary_allowed_policy1_PERIOD_M15_PERIOD_M5_LONG | PASS | An upper close exactly on the fixed boundary remains eligible |
| strict_close_policy1_PERIOD_M15_PERIOD_M5_LONG | PASS | One tradable point beyond the upper close boundary measures in control and excludes only with the new policy |
| close_evidence_policy1_PERIOD_M15_PERIOD_M5_LONG | PASS | The first violating upper candle |
| duplicate_close_no_repeat_policy1_PERIOD_M15_PERIOD_M5_LONG | PASS | A duplicate upper input cannot repeat or backdate the first close observation |
| lower_close_not_upper_rule_PERIOD_M15_PERIOD_M5_LONG | PASS | A lower-timeframe close deeper than 61.8% does not substitute for the selected upper close rule |
| legacy_wick_policy_unchanged_PERIOD_M15_PERIOD_M5_LONG | PASS | The existing rejectDeep=true still excludes lower-observed W2 wick depth independently of the new close policy |
| provisional_no_fixed_fib_policy0_PERIOD_M15_PERIOD_M5_LONG | PASS | A deep close cannot be classified against a future W1 endpoint while that endpoint remains provisional |
| historical_close_known_now_policy0_PERIOD_M15_PERIOD_M5_LONG | PASS | The earlier close breach is classified only now at peak confirmation |
| historical_event_order_policy0_PERIOD_M15_PERIOD_M5_LONG | PASS | Fixed-peak availability precedes measurement/exclusion; historical candles never emit a retrospective signal |
| provisional_no_fixed_fib_policy1_PERIOD_M15_PERIOD_M5_LONG | PASS | A deep close cannot be classified against a future W1 endpoint while that endpoint remains provisional |
| historical_close_known_now_policy1_PERIOD_M15_PERIOD_M5_LONG | PASS | The earlier close breach is classified only now at peak confirmation |
| historical_event_order_policy1_PERIOD_M15_PERIOD_M5_LONG | PASS | Fixed-peak availability precedes measurement/exclusion; historical candles never emit a retrospective signal |
| peak_candle_not_w2_close_PERIOD_M15_PERIOD_M5_LONG | PASS | The W1 peak candle's own deep body is not treated as a W2 close; W2 sources start one upper period later |
| forming_upper_rejected_PERIOD_M15_PERIOD_M5_LONG | PASS | The new condition cannot consume a forming or future upper candle |
| delayed_close_not_backdated_PERIOD_M15_PERIOD_M5_LONG | PASS | A delayed upper observation stores its original close time but publishes only at actual availability |
| deep_close_never_revives_PERIOD_M15_PERIOD_M5_LONG | PASS | Later lower reactions cannot revive a candidate terminated by the fixed upper close condition |
| same_time_trigger_preknown_policy0_PERIOD_M15_PERIOD_M5_LONG | PASS | The synthetic same-availability scheduling test has a real pre-known lower reaction trigger |
| same_time_upper_close_priority_policy0_PERIOD_M15_PERIOD_M5_LONG | PASS | When upper and lower closes become available together |
| same_time_trigger_preknown_policy1_PERIOD_M15_PERIOD_M5_LONG | PASS | The synthetic same-availability scheduling test has a real pre-known lower reaction trigger |
| same_time_upper_close_priority_policy1_PERIOD_M15_PERIOD_M5_LONG | PASS | When upper and lower closes become available together |
| postsignal_fib_frozen_position0_PERIOD_M15_PERIOD_M5_LONG | PASS | A later deep upper close neither measures nor retroactively invalidates an existing signal or open position |
| postsignal_fib_frozen_position1_PERIOD_M15_PERIOD_M5_LONG | PASS | A later deep upper close neither measures nor retroactively invalidates an existing signal or open position |
| decimal_equality_no_ulp_exclusion_PERIOD_M15_PERIOD_M5_LONG | PASS | Decimal 61.8% equality is allowed even if floating-point multiplication differs by one binary unit |
| decimal_real_breach_excluded_PERIOD_M15_PERIOD_M5_LONG | PASS | Arithmetic equality tolerance does not grant a tradable-point allowance beyond 61.8% |
| constructor_close_policy_default_off_PERIOD_M15_PERIOD_M5_LONG | PASS | Old callers that never set the new policy retain eligibility; the close breach is measurement only |
| wick_without_deep_close_policy0_PERIOD_M15_PERIOD_M5_SHORT | PASS | A wick beyond 61.8% with the upper close inside is not a close-policy exclusion |
| exact_boundary_allowed_policy0_PERIOD_M15_PERIOD_M5_SHORT | PASS | An upper close exactly on the fixed boundary remains eligible |
| strict_close_policy0_PERIOD_M15_PERIOD_M5_SHORT | PASS | One tradable point beyond the upper close boundary measures in control and excludes only with the new policy |
| close_evidence_policy0_PERIOD_M15_PERIOD_M5_SHORT | PASS | The first violating upper candle |
| duplicate_close_no_repeat_policy0_PERIOD_M15_PERIOD_M5_SHORT | PASS | A duplicate upper input cannot repeat or backdate the first close observation |
| wick_without_deep_close_policy1_PERIOD_M15_PERIOD_M5_SHORT | PASS | A wick beyond 61.8% with the upper close inside is not a close-policy exclusion |
| exact_boundary_allowed_policy1_PERIOD_M15_PERIOD_M5_SHORT | PASS | An upper close exactly on the fixed boundary remains eligible |
| strict_close_policy1_PERIOD_M15_PERIOD_M5_SHORT | PASS | One tradable point beyond the upper close boundary measures in control and excludes only with the new policy |
| close_evidence_policy1_PERIOD_M15_PERIOD_M5_SHORT | PASS | The first violating upper candle |
| duplicate_close_no_repeat_policy1_PERIOD_M15_PERIOD_M5_SHORT | PASS | A duplicate upper input cannot repeat or backdate the first close observation |
| lower_close_not_upper_rule_PERIOD_M15_PERIOD_M5_SHORT | PASS | A lower-timeframe close deeper than 61.8% does not substitute for the selected upper close rule |
| legacy_wick_policy_unchanged_PERIOD_M15_PERIOD_M5_SHORT | PASS | The existing rejectDeep=true still excludes lower-observed W2 wick depth independently of the new close policy |
| provisional_no_fixed_fib_policy0_PERIOD_M15_PERIOD_M5_SHORT | PASS | A deep close cannot be classified against a future W1 endpoint while that endpoint remains provisional |
| historical_close_known_now_policy0_PERIOD_M15_PERIOD_M5_SHORT | PASS | The earlier close breach is classified only now at peak confirmation |
| historical_event_order_policy0_PERIOD_M15_PERIOD_M5_SHORT | PASS | Fixed-peak availability precedes measurement/exclusion; historical candles never emit a retrospective signal |
| provisional_no_fixed_fib_policy1_PERIOD_M15_PERIOD_M5_SHORT | PASS | A deep close cannot be classified against a future W1 endpoint while that endpoint remains provisional |
| historical_close_known_now_policy1_PERIOD_M15_PERIOD_M5_SHORT | PASS | The earlier close breach is classified only now at peak confirmation |
| historical_event_order_policy1_PERIOD_M15_PERIOD_M5_SHORT | PASS | Fixed-peak availability precedes measurement/exclusion; historical candles never emit a retrospective signal |
| peak_candle_not_w2_close_PERIOD_M15_PERIOD_M5_SHORT | PASS | The W1 peak candle's own deep body is not treated as a W2 close; W2 sources start one upper period later |
| forming_upper_rejected_PERIOD_M15_PERIOD_M5_SHORT | PASS | The new condition cannot consume a forming or future upper candle |
| delayed_close_not_backdated_PERIOD_M15_PERIOD_M5_SHORT | PASS | A delayed upper observation stores its original close time but publishes only at actual availability |
| deep_close_never_revives_PERIOD_M15_PERIOD_M5_SHORT | PASS | Later lower reactions cannot revive a candidate terminated by the fixed upper close condition |
| same_time_trigger_preknown_policy0_PERIOD_M15_PERIOD_M5_SHORT | PASS | The synthetic same-availability scheduling test has a real pre-known lower reaction trigger |
| same_time_upper_close_priority_policy0_PERIOD_M15_PERIOD_M5_SHORT | PASS | When upper and lower closes become available together |
| same_time_trigger_preknown_policy1_PERIOD_M15_PERIOD_M5_SHORT | PASS | The synthetic same-availability scheduling test has a real pre-known lower reaction trigger |
| same_time_upper_close_priority_policy1_PERIOD_M15_PERIOD_M5_SHORT | PASS | When upper and lower closes become available together |
| postsignal_fib_frozen_position0_PERIOD_M15_PERIOD_M5_SHORT | PASS | A later deep upper close neither measures nor retroactively invalidates an existing signal or open position |
| postsignal_fib_frozen_position1_PERIOD_M15_PERIOD_M5_SHORT | PASS | A later deep upper close neither measures nor retroactively invalidates an existing signal or open position |
| decimal_equality_no_ulp_exclusion_PERIOD_M15_PERIOD_M5_SHORT | PASS | Decimal 61.8% equality is allowed even if floating-point multiplication differs by one binary unit |
| decimal_real_breach_excluded_PERIOD_M15_PERIOD_M5_SHORT | PASS | Arithmetic equality tolerance does not grant a tradable-point allowance beyond 61.8% |
| constructor_close_policy_default_off_PERIOD_M15_PERIOD_M5_SHORT | PASS | Old callers that never set the new policy retain eligibility; the close breach is measurement only |
| wick_without_deep_close_policy0_PERIOD_M5_PERIOD_M1_LONG | PASS | A wick beyond 61.8% with the upper close inside is not a close-policy exclusion |
| exact_boundary_allowed_policy0_PERIOD_M5_PERIOD_M1_LONG | PASS | An upper close exactly on the fixed boundary remains eligible |
| strict_close_policy0_PERIOD_M5_PERIOD_M1_LONG | PASS | One tradable point beyond the upper close boundary measures in control and excludes only with the new policy |
| close_evidence_policy0_PERIOD_M5_PERIOD_M1_LONG | PASS | The first violating upper candle |
| duplicate_close_no_repeat_policy0_PERIOD_M5_PERIOD_M1_LONG | PASS | A duplicate upper input cannot repeat or backdate the first close observation |
| wick_without_deep_close_policy1_PERIOD_M5_PERIOD_M1_LONG | PASS | A wick beyond 61.8% with the upper close inside is not a close-policy exclusion |
| exact_boundary_allowed_policy1_PERIOD_M5_PERIOD_M1_LONG | PASS | An upper close exactly on the fixed boundary remains eligible |
| strict_close_policy1_PERIOD_M5_PERIOD_M1_LONG | PASS | One tradable point beyond the upper close boundary measures in control and excludes only with the new policy |
| close_evidence_policy1_PERIOD_M5_PERIOD_M1_LONG | PASS | The first violating upper candle |
| duplicate_close_no_repeat_policy1_PERIOD_M5_PERIOD_M1_LONG | PASS | A duplicate upper input cannot repeat or backdate the first close observation |
| lower_close_not_upper_rule_PERIOD_M5_PERIOD_M1_LONG | PASS | A lower-timeframe close deeper than 61.8% does not substitute for the selected upper close rule |
| legacy_wick_policy_unchanged_PERIOD_M5_PERIOD_M1_LONG | PASS | The existing rejectDeep=true still excludes lower-observed W2 wick depth independently of the new close policy |
| provisional_no_fixed_fib_policy0_PERIOD_M5_PERIOD_M1_LONG | PASS | A deep close cannot be classified against a future W1 endpoint while that endpoint remains provisional |
| historical_close_known_now_policy0_PERIOD_M5_PERIOD_M1_LONG | PASS | The earlier close breach is classified only now at peak confirmation |
| historical_event_order_policy0_PERIOD_M5_PERIOD_M1_LONG | PASS | Fixed-peak availability precedes measurement/exclusion; historical candles never emit a retrospective signal |
| provisional_no_fixed_fib_policy1_PERIOD_M5_PERIOD_M1_LONG | PASS | A deep close cannot be classified against a future W1 endpoint while that endpoint remains provisional |
| historical_close_known_now_policy1_PERIOD_M5_PERIOD_M1_LONG | PASS | The earlier close breach is classified only now at peak confirmation |
| historical_event_order_policy1_PERIOD_M5_PERIOD_M1_LONG | PASS | Fixed-peak availability precedes measurement/exclusion; historical candles never emit a retrospective signal |
| peak_candle_not_w2_close_PERIOD_M5_PERIOD_M1_LONG | PASS | The W1 peak candle's own deep body is not treated as a W2 close; W2 sources start one upper period later |
| forming_upper_rejected_PERIOD_M5_PERIOD_M1_LONG | PASS | The new condition cannot consume a forming or future upper candle |
| delayed_close_not_backdated_PERIOD_M5_PERIOD_M1_LONG | PASS | A delayed upper observation stores its original close time but publishes only at actual availability |
| deep_close_never_revives_PERIOD_M5_PERIOD_M1_LONG | PASS | Later lower reactions cannot revive a candidate terminated by the fixed upper close condition |
| same_time_trigger_preknown_policy0_PERIOD_M5_PERIOD_M1_LONG | PASS | The synthetic same-availability scheduling test has a real pre-known lower reaction trigger |
| same_time_upper_close_priority_policy0_PERIOD_M5_PERIOD_M1_LONG | PASS | When upper and lower closes become available together |
| same_time_trigger_preknown_policy1_PERIOD_M5_PERIOD_M1_LONG | PASS | The synthetic same-availability scheduling test has a real pre-known lower reaction trigger |
| same_time_upper_close_priority_policy1_PERIOD_M5_PERIOD_M1_LONG | PASS | When upper and lower closes become available together |
| postsignal_fib_frozen_position0_PERIOD_M5_PERIOD_M1_LONG | PASS | A later deep upper close neither measures nor retroactively invalidates an existing signal or open position |
| postsignal_fib_frozen_position1_PERIOD_M5_PERIOD_M1_LONG | PASS | A later deep upper close neither measures nor retroactively invalidates an existing signal or open position |
| decimal_equality_no_ulp_exclusion_PERIOD_M5_PERIOD_M1_LONG | PASS | Decimal 61.8% equality is allowed even if floating-point multiplication differs by one binary unit |
| decimal_real_breach_excluded_PERIOD_M5_PERIOD_M1_LONG | PASS | Arithmetic equality tolerance does not grant a tradable-point allowance beyond 61.8% |
| constructor_close_policy_default_off_PERIOD_M5_PERIOD_M1_LONG | PASS | Old callers that never set the new policy retain eligibility; the close breach is measurement only |
| wick_without_deep_close_policy0_PERIOD_M5_PERIOD_M1_SHORT | PASS | A wick beyond 61.8% with the upper close inside is not a close-policy exclusion |
| exact_boundary_allowed_policy0_PERIOD_M5_PERIOD_M1_SHORT | PASS | An upper close exactly on the fixed boundary remains eligible |
| strict_close_policy0_PERIOD_M5_PERIOD_M1_SHORT | PASS | One tradable point beyond the upper close boundary measures in control and excludes only with the new policy |
| close_evidence_policy0_PERIOD_M5_PERIOD_M1_SHORT | PASS | The first violating upper candle |
| duplicate_close_no_repeat_policy0_PERIOD_M5_PERIOD_M1_SHORT | PASS | A duplicate upper input cannot repeat or backdate the first close observation |
| wick_without_deep_close_policy1_PERIOD_M5_PERIOD_M1_SHORT | PASS | A wick beyond 61.8% with the upper close inside is not a close-policy exclusion |
| exact_boundary_allowed_policy1_PERIOD_M5_PERIOD_M1_SHORT | PASS | An upper close exactly on the fixed boundary remains eligible |
| strict_close_policy1_PERIOD_M5_PERIOD_M1_SHORT | PASS | One tradable point beyond the upper close boundary measures in control and excludes only with the new policy |
| close_evidence_policy1_PERIOD_M5_PERIOD_M1_SHORT | PASS | The first violating upper candle |
| duplicate_close_no_repeat_policy1_PERIOD_M5_PERIOD_M1_SHORT | PASS | A duplicate upper input cannot repeat or backdate the first close observation |
| lower_close_not_upper_rule_PERIOD_M5_PERIOD_M1_SHORT | PASS | A lower-timeframe close deeper than 61.8% does not substitute for the selected upper close rule |
| legacy_wick_policy_unchanged_PERIOD_M5_PERIOD_M1_SHORT | PASS | The existing rejectDeep=true still excludes lower-observed W2 wick depth independently of the new close policy |
| provisional_no_fixed_fib_policy0_PERIOD_M5_PERIOD_M1_SHORT | PASS | A deep close cannot be classified against a future W1 endpoint while that endpoint remains provisional |
| historical_close_known_now_policy0_PERIOD_M5_PERIOD_M1_SHORT | PASS | The earlier close breach is classified only now at peak confirmation |
| historical_event_order_policy0_PERIOD_M5_PERIOD_M1_SHORT | PASS | Fixed-peak availability precedes measurement/exclusion; historical candles never emit a retrospective signal |
| provisional_no_fixed_fib_policy1_PERIOD_M5_PERIOD_M1_SHORT | PASS | A deep close cannot be classified against a future W1 endpoint while that endpoint remains provisional |
| historical_close_known_now_policy1_PERIOD_M5_PERIOD_M1_SHORT | PASS | The earlier close breach is classified only now at peak confirmation |
| historical_event_order_policy1_PERIOD_M5_PERIOD_M1_SHORT | PASS | Fixed-peak availability precedes measurement/exclusion; historical candles never emit a retrospective signal |
| peak_candle_not_w2_close_PERIOD_M5_PERIOD_M1_SHORT | PASS | The W1 peak candle's own deep body is not treated as a W2 close; W2 sources start one upper period later |
| forming_upper_rejected_PERIOD_M5_PERIOD_M1_SHORT | PASS | The new condition cannot consume a forming or future upper candle |
| delayed_close_not_backdated_PERIOD_M5_PERIOD_M1_SHORT | PASS | A delayed upper observation stores its original close time but publishes only at actual availability |
| deep_close_never_revives_PERIOD_M5_PERIOD_M1_SHORT | PASS | Later lower reactions cannot revive a candidate terminated by the fixed upper close condition |
| same_time_trigger_preknown_policy0_PERIOD_M5_PERIOD_M1_SHORT | PASS | The synthetic same-availability scheduling test has a real pre-known lower reaction trigger |
| same_time_upper_close_priority_policy0_PERIOD_M5_PERIOD_M1_SHORT | PASS | When upper and lower closes become available together |
| same_time_trigger_preknown_policy1_PERIOD_M5_PERIOD_M1_SHORT | PASS | The synthetic same-availability scheduling test has a real pre-known lower reaction trigger |
| same_time_upper_close_priority_policy1_PERIOD_M5_PERIOD_M1_SHORT | PASS | When upper and lower closes become available together |
| postsignal_fib_frozen_position0_PERIOD_M5_PERIOD_M1_SHORT | PASS | A later deep upper close neither measures nor retroactively invalidates an existing signal or open position |
| postsignal_fib_frozen_position1_PERIOD_M5_PERIOD_M1_SHORT | PASS | A later deep upper close neither measures nor retroactively invalidates an existing signal or open position |
| decimal_equality_no_ulp_exclusion_PERIOD_M5_PERIOD_M1_SHORT | PASS | Decimal 61.8% equality is allowed even if floating-point multiplication differs by one binary unit |
| decimal_real_breach_excluded_PERIOD_M5_PERIOD_M1_SHORT | PASS | Arithmetic equality tolerance does not grant a tradable-point allowance beyond 61.8% |
| constructor_close_policy_default_off_PERIOD_M5_PERIOD_M1_SHORT | PASS | Old callers that never set the new policy retain eligibility; the close breach is measurement only |
