# opposite_exit_harness: MQL5決定論テスト

実際のMT5内でエンジンを呼び出し、因果順序とLONG/SHORT分岐を確認する合成入力 91項目。PASS 87 / FAIL 4。市場の売買事例とは区別する。

原本: [harness.csv](harness.csv)。

| テスト | 判定 | 詳細 |
|---|---|---|
| net_zero_after_cost_waits | PASS | Quote profit exactly covering booked entry cost and estimated exit cost is not positive net |
| net_first_positive_after_cost | PASS | The first quote estimate strictly above both known and estimated costs requests an exit |
| gross_positive_net_negative_waits | PASS | A positive quote result is insufficient while total estimated net remains negative |
| net_remaining_swap_included | PASS | Open-volume swap and all booked cash are included once in total estimated net |
| net_realized_partial_cash_included | PASS | Booked partial-exit cash participates in the remaining position's total scenario result |
| net_remaining_volume_cost | PASS | Estimated exit cost scales with residual volume rather than original filled volume |
| net_negative_cost_clamped | PASS | A negative estimated fee cannot manufacture extra profit by extrapolating rebates |
| net_zero_volume_allowed | PASS | Zero residual volume has no closing cost; the independent own-position guard prevents an order |
| net_negative_volume_invalid | PASS | Negative residual volume is invalid rather than an artificial profit rebate |
| net_invalid_quote_rejected | PASS | Invalid quote profit propagates as unavailable net |
| net_invalid_cash_rejected | PASS | Invalid booked cash propagates as unavailable net |
| net_invalid_swap_rejected | PASS | Invalid open swap propagates as unavailable net |
| net_invalid_cost_rejected | PASS | Invalid fee estimate propagates as unavailable net |
| net_invalid_volume_rejected | PASS | Invalid residual volume propagates as unavailable net |
| net_overflow_rejected | PASS | Overflowing closing-cost arithmetic cannot authorize an exit |
| net_sum_overflow_rejected | PASS | Overflowing total profit arithmetic cannot authorize an exit |
| net_no_cost_exact | PASS | No observed commission or fee adds no invented fee estimate |
| reset_LONG | FAIL | Fresh actual fill starts without an opposite-wave exit request |
| no_actual_fill_LONG | PASS | A signal without an actual fill cannot arm the exit |
| no_fill_order_key_LONG | PASS | Missing causal fill order is rejected |
| prefill_time_LONG | PASS | A source known before fill is rejected even if delivered in a later processing step |
| prefill_order_LONG | PASS | An event consumed before actual fill cannot be replayed into an armed exit |
| same_fill_order_LONG | PASS | The fill event itself is not a later opposite observation |
| same_direction_LONG | PASS | A new first wave in the position direction cannot arm this exit |
| missing_source_LONG | PASS | An unidentified source cannot arm the exit |
| invalid_source_direction_LONG | PASS | A non-directional event is rejected |
| invalid_position_direction_LONG | PASS | A malformed position direction is rejected |
| same_second_later_observation_LONG | PASS | A causally later opposite observation can arm within the same datetime second |
| duplicate_does_not_rearm_LONG | PASS | A duplicate source leaves the first observation unchanged |
| first_source_preserved_LONG | PASS | Later opposite setups cannot replace the latched cause |
| later_second_observation_LONG | PASS | A source is dated at actual observation availability |
| not_armed_LONG | PASS | Positive floating net alone is insufficient before an opposite observation |
| disabled_LONG | PASS | Disabled policy never requests an exit |
| tester_only_LONG | PASS | A normal chart cannot request an exit |
| no_owned_position_LONG | PASS | Missing |
| negative_net_waits_LONG | PASS | A loss waits with the original protective exit levels managed by the caller |
| zero_net_waits_LONG | PASS | Exactly zero is not strictly profitable |
| first_positive_requests_LONG | PASS | The first positive executable net estimate becomes eligible immediately |
| positive_at_observation_LONG | PASS | Already profitable at opposite recognition requires no extra candle or target |
| invalid_net_waits_LONG | PASS | An invalid profit estimate never becomes an exit permission |
| positive_infinity_waits_LONG | PASS | Positive infinity is not an executable profit estimate |
| negative_infinity_waits_LONG | PASS | Negative infinity cannot trigger an exit |
| source_invalidation_sticky_LONG | PASS | An unrelated engine source lifecycle change has no policy reset; arming survives until the position closes |
| unarmed_request_denied_LONG | PASS | No request can be marked without a cause |
| backdated_request_denied_LONG | PASS | A close request cannot precede its observed cause |
| earlier_order_request_denied_LONG | PASS | A request cannot use a processing order older than its cause |
| immediate_request_LONG | PASS | The observation tick may also submit the first profitable close request |
| pending_blocks_duplicate_LONG | PASS | An outstanding request suppresses duplicate close submission |
| rejection_reopens_retry_LONG | PASS | A rejected request retains the original source and permits a profitable retry |
| retry_waits_if_negative_LONG | PASS | A rejected request cannot force a later loss-taking retry |
| retry_marked_LONG | PASS | The retry has its own observable request time and attempt count |
| partial_fill_residual_LONG | PASS | A partially closed residual remains eligible at its next positive net estimate |
| flat_clears_all_LONG | FAIL | Flat resets the cause |
| new_position_not_prearmed_LONG | PASS | A later position cannot inherit the previous position's exit cause |
| reset_SHORT | FAIL | Fresh actual fill starts without an opposite-wave exit request |
| no_actual_fill_SHORT | PASS | A signal without an actual fill cannot arm the exit |
| no_fill_order_key_SHORT | PASS | Missing causal fill order is rejected |
| prefill_time_SHORT | PASS | A source known before fill is rejected even if delivered in a later processing step |
| prefill_order_SHORT | PASS | An event consumed before actual fill cannot be replayed into an armed exit |
| same_fill_order_SHORT | PASS | The fill event itself is not a later opposite observation |
| same_direction_SHORT | PASS | A new first wave in the position direction cannot arm this exit |
| missing_source_SHORT | PASS | An unidentified source cannot arm the exit |
| invalid_source_direction_SHORT | PASS | A non-directional event is rejected |
| invalid_position_direction_SHORT | PASS | A malformed position direction is rejected |
| same_second_later_observation_SHORT | PASS | A causally later opposite observation can arm within the same datetime second |
| duplicate_does_not_rearm_SHORT | PASS | A duplicate source leaves the first observation unchanged |
| first_source_preserved_SHORT | PASS | Later opposite setups cannot replace the latched cause |
| later_second_observation_SHORT | PASS | A source is dated at actual observation availability |
| not_armed_SHORT | PASS | Positive floating net alone is insufficient before an opposite observation |
| disabled_SHORT | PASS | Disabled policy never requests an exit |
| tester_only_SHORT | PASS | A normal chart cannot request an exit |
| no_owned_position_SHORT | PASS | Missing |
| negative_net_waits_SHORT | PASS | A loss waits with the original protective exit levels managed by the caller |
| zero_net_waits_SHORT | PASS | Exactly zero is not strictly profitable |
| first_positive_requests_SHORT | PASS | The first positive executable net estimate becomes eligible immediately |
| positive_at_observation_SHORT | PASS | Already profitable at opposite recognition requires no extra candle or target |
| invalid_net_waits_SHORT | PASS | An invalid profit estimate never becomes an exit permission |
| positive_infinity_waits_SHORT | PASS | Positive infinity is not an executable profit estimate |
| negative_infinity_waits_SHORT | PASS | Negative infinity cannot trigger an exit |
| source_invalidation_sticky_SHORT | PASS | An unrelated engine source lifecycle change has no policy reset; arming survives until the position closes |
| unarmed_request_denied_SHORT | PASS | No request can be marked without a cause |
| backdated_request_denied_SHORT | PASS | A close request cannot precede its observed cause |
| earlier_order_request_denied_SHORT | PASS | A request cannot use a processing order older than its cause |
| immediate_request_SHORT | PASS | The observation tick may also submit the first profitable close request |
| pending_blocks_duplicate_SHORT | PASS | An outstanding request suppresses duplicate close submission |
| rejection_reopens_retry_SHORT | PASS | A rejected request retains the original source and permits a profitable retry |
| retry_waits_if_negative_SHORT | PASS | A rejected request cannot force a later loss-taking retry |
| retry_marked_SHORT | PASS | The retry has its own observable request time and attempt count |
| partial_fill_residual_SHORT | PASS | A partially closed residual remains eligible at its next positive net estimate |
| flat_clears_all_SHORT | FAIL | Flat resets the cause |
| new_position_not_prearmed_SHORT | PASS | A later position cannot inherit the previous position's exit cause |
