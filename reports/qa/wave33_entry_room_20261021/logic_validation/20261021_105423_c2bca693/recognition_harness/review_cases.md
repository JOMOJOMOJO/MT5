# recognition_harness: MQL5決定論テスト

実際のMT5内でエンジンを呼び出し、因果順序とLONG/SHORT分岐を確認する合成入力 120項目。PASS 120 / FAIL 0。市場の売買事例とは区別する。

原本: [harness.csv](harness.csv)。

| テスト | 判定 | 詳細 |
|---|---|---|
| complete_only_no_simple_mode0_PERIOD_M15_PERIOD_M5_LONG | PASS | Modes 0 and 1 retain complete-countertrend requirements for this short reaction |
| complete_only_no_simple_mode1_PERIOD_M15_PERIOD_M5_LONG | PASS | Modes 0 and 1 retain complete-countertrend requirements for this short reaction |
| simple_preknown_PERIOD_M15_PERIOD_M5_LONG | PASS | Confirmed W2 pivot and first reaction line are available one full candle before the eventual cross |
| simple_two_pivots_only_PERIOD_M15_PERIOD_M5_LONG | PASS | No additional retest pivot or strict lower 1->2->3 count is fabricated |
| simple_fresh_cross_signal_PERIOD_M15_PERIOD_M5_LONG | PASS | A fresh closed cross of the pre-known first reaction level can enter before W1 is reached |
| simple_stage_and_binding_PERIOD_M15_PERIOD_M5_LONG | PASS | Signal snapshots identify the separate recognition assumption and its W2 membership |
| simple_no_synthetic_trendline_PERIOD_M15_PERIOD_M5_LONG | PASS | The simple route has one reaction point |
| strict_raw_sequence_control_PERIOD_M15_PERIOD_M5_LONG | PASS | Unchanged mode 0 cannot use the nonalternating latest raw highs and lows |
| normalized_extreme_not_latest_PERIOD_M15_PERIOD_M5_LONG | PASS | Consecutive same-side pivots retain the most extreme confirmed pivot |
| normalized_complete_signal_PERIOD_M15_PERIOD_M5_LONG | PASS | An ordered normalized LH/LL or HH/HL structure can trigger with the same strict W2 membership |
| normalized_raw_events_unchanged_PERIOD_M15_PERIOD_M5_LONG | PASS | Compression is a current recognition view; the discarded same-side raw pivot still exists in causal history |
| ambiguous_samebar_mode1_PERIOD_M15_PERIOD_M5_LONG | PASS | A candle confirmed as both high and low cannot invent intrabar order or a simple W2 anchor |
| ambiguous_no_signal_mode1_PERIOD_M15_PERIOD_M5_LONG | PASS | A later close cannot turn an ambiguous two-sided swing into a historical trigger |
| ambiguous_samebar_mode2_PERIOD_M15_PERIOD_M5_LONG | PASS | A candle confirmed as both high and low cannot invent intrabar order or a simple W2 anchor |
| ambiguous_no_signal_mode2_PERIOD_M15_PERIOD_M5_LONG | PASS | A later close cannot turn an ambiguous two-sided swing into a historical trigger |
| simple_before_new_extreme_PERIOD_M15_PERIOD_M5_LONG | PASS | The old first reaction line genuinely exists before this reset test |
| simple_new_extreme_before_trigger_PERIOD_M15_PERIOD_M5_LONG | PASS | A bar crossing the old reaction while setting a deeper W2 cannot use that stale line |
| simple_old_reaction_not_reused_PERIOD_M15_PERIOD_M5_LONG | PASS | Once the new W2 is confirmed |
| simple_first_reaction_frozen_PERIOD_M15_PERIOD_M5_LONG | PASS | A later confirmed higher/lower reaction does not move the first line; its availability is the delayed W1 confirmation time |
| simple_historical_cross_not_replayed_PERIOD_M15_PERIOD_M5_LONG | PASS | Crosses before W1 and the reaction line were jointly knowable never execute retrospectively |
| simple_new_fresh_cross_after_known_PERIOD_M15_PERIOD_M5_LONG | PASS | A later fresh cross uses the original known first reaction level |
| simple_already_beyond_line_no_entry_PERIOD_M15_PERIOD_M5_LONG | PASS | Price already beyond the reaction when W1 became known is not a new cross on the following candle |
| simple_rearm_by_actual_recross_PERIOD_M15_PERIOD_M5_LONG | PASS | Only an observable return below/above and subsequent fresh cross can enter this still-active candidate |
| simple_tl_mode_explicit_unmet_PERIOD_M15_PERIOD_M5_LONG | PASS | A pivot diagnostic cannot silently substitute for the selected trendline arm |
| simple_tl_mode_no_fake_line_PERIOD_M15_PERIOD_M5_LONG | PASS | No trendline is extrapolated from zero-valued missing anchors |
| complete_structure_priority_PERIOD_M15_PERIOD_M5_LONG | PASS | A complete W2-bound normalized countertrend takes priority over the simple fallback |
| complete_priority_valid_signal_PERIOD_M15_PERIOD_M5_LONG | PASS | The shorter-reaction route preserves the earlier complete-structure valid entry |
| simple_survives_unrelated_complete_PERIOD_M15_PERIOD_M5_LONG | PASS | A later complete countertrend away from the deepest W2 cannot replace the valid original simple reaction |
| simple_no_rejection_churn_PERIOD_M15_PERIOD_M5_LONG | PASS | Repeated rejection of unrelated full structures leaves first-reaction price |
| unrelated_complete_measured_once_per_key_PERIOD_M15_PERIOD_M5_LONG | PASS | Rejected alternative structures remain measured without silently replacing the accepted simple route |
| complete_only_no_simple_mode0_PERIOD_M15_PERIOD_M5_SHORT | PASS | Modes 0 and 1 retain complete-countertrend requirements for this short reaction |
| complete_only_no_simple_mode1_PERIOD_M15_PERIOD_M5_SHORT | PASS | Modes 0 and 1 retain complete-countertrend requirements for this short reaction |
| simple_preknown_PERIOD_M15_PERIOD_M5_SHORT | PASS | Confirmed W2 pivot and first reaction line are available one full candle before the eventual cross |
| simple_two_pivots_only_PERIOD_M15_PERIOD_M5_SHORT | PASS | No additional retest pivot or strict lower 1->2->3 count is fabricated |
| simple_fresh_cross_signal_PERIOD_M15_PERIOD_M5_SHORT | PASS | A fresh closed cross of the pre-known first reaction level can enter before W1 is reached |
| simple_stage_and_binding_PERIOD_M15_PERIOD_M5_SHORT | PASS | Signal snapshots identify the separate recognition assumption and its W2 membership |
| simple_no_synthetic_trendline_PERIOD_M15_PERIOD_M5_SHORT | PASS | The simple route has one reaction point |
| strict_raw_sequence_control_PERIOD_M15_PERIOD_M5_SHORT | PASS | Unchanged mode 0 cannot use the nonalternating latest raw highs and lows |
| normalized_extreme_not_latest_PERIOD_M15_PERIOD_M5_SHORT | PASS | Consecutive same-side pivots retain the most extreme confirmed pivot |
| normalized_complete_signal_PERIOD_M15_PERIOD_M5_SHORT | PASS | An ordered normalized LH/LL or HH/HL structure can trigger with the same strict W2 membership |
| normalized_raw_events_unchanged_PERIOD_M15_PERIOD_M5_SHORT | PASS | Compression is a current recognition view; the discarded same-side raw pivot still exists in causal history |
| ambiguous_samebar_mode1_PERIOD_M15_PERIOD_M5_SHORT | PASS | A candle confirmed as both high and low cannot invent intrabar order or a simple W2 anchor |
| ambiguous_no_signal_mode1_PERIOD_M15_PERIOD_M5_SHORT | PASS | A later close cannot turn an ambiguous two-sided swing into a historical trigger |
| ambiguous_samebar_mode2_PERIOD_M15_PERIOD_M5_SHORT | PASS | A candle confirmed as both high and low cannot invent intrabar order or a simple W2 anchor |
| ambiguous_no_signal_mode2_PERIOD_M15_PERIOD_M5_SHORT | PASS | A later close cannot turn an ambiguous two-sided swing into a historical trigger |
| simple_before_new_extreme_PERIOD_M15_PERIOD_M5_SHORT | PASS | The old first reaction line genuinely exists before this reset test |
| simple_new_extreme_before_trigger_PERIOD_M15_PERIOD_M5_SHORT | PASS | A bar crossing the old reaction while setting a deeper W2 cannot use that stale line |
| simple_old_reaction_not_reused_PERIOD_M15_PERIOD_M5_SHORT | PASS | Once the new W2 is confirmed |
| simple_first_reaction_frozen_PERIOD_M15_PERIOD_M5_SHORT | PASS | A later confirmed higher/lower reaction does not move the first line; its availability is the delayed W1 confirmation time |
| simple_historical_cross_not_replayed_PERIOD_M15_PERIOD_M5_SHORT | PASS | Crosses before W1 and the reaction line were jointly knowable never execute retrospectively |
| simple_new_fresh_cross_after_known_PERIOD_M15_PERIOD_M5_SHORT | PASS | A later fresh cross uses the original known first reaction level |
| simple_already_beyond_line_no_entry_PERIOD_M15_PERIOD_M5_SHORT | PASS | Price already beyond the reaction when W1 became known is not a new cross on the following candle |
| simple_rearm_by_actual_recross_PERIOD_M15_PERIOD_M5_SHORT | PASS | Only an observable return below/above and subsequent fresh cross can enter this still-active candidate |
| simple_tl_mode_explicit_unmet_PERIOD_M15_PERIOD_M5_SHORT | PASS | A pivot diagnostic cannot silently substitute for the selected trendline arm |
| simple_tl_mode_no_fake_line_PERIOD_M15_PERIOD_M5_SHORT | PASS | No trendline is extrapolated from zero-valued missing anchors |
| complete_structure_priority_PERIOD_M15_PERIOD_M5_SHORT | PASS | A complete W2-bound normalized countertrend takes priority over the simple fallback |
| complete_priority_valid_signal_PERIOD_M15_PERIOD_M5_SHORT | PASS | The shorter-reaction route preserves the earlier complete-structure valid entry |
| simple_survives_unrelated_complete_PERIOD_M15_PERIOD_M5_SHORT | PASS | A later complete countertrend away from the deepest W2 cannot replace the valid original simple reaction |
| simple_no_rejection_churn_PERIOD_M15_PERIOD_M5_SHORT | PASS | Repeated rejection of unrelated full structures leaves first-reaction price |
| unrelated_complete_measured_once_per_key_PERIOD_M15_PERIOD_M5_SHORT | PASS | Rejected alternative structures remain measured without silently replacing the accepted simple route |
| complete_only_no_simple_mode0_PERIOD_M5_PERIOD_M1_LONG | PASS | Modes 0 and 1 retain complete-countertrend requirements for this short reaction |
| complete_only_no_simple_mode1_PERIOD_M5_PERIOD_M1_LONG | PASS | Modes 0 and 1 retain complete-countertrend requirements for this short reaction |
| simple_preknown_PERIOD_M5_PERIOD_M1_LONG | PASS | Confirmed W2 pivot and first reaction line are available one full candle before the eventual cross |
| simple_two_pivots_only_PERIOD_M5_PERIOD_M1_LONG | PASS | No additional retest pivot or strict lower 1->2->3 count is fabricated |
| simple_fresh_cross_signal_PERIOD_M5_PERIOD_M1_LONG | PASS | A fresh closed cross of the pre-known first reaction level can enter before W1 is reached |
| simple_stage_and_binding_PERIOD_M5_PERIOD_M1_LONG | PASS | Signal snapshots identify the separate recognition assumption and its W2 membership |
| simple_no_synthetic_trendline_PERIOD_M5_PERIOD_M1_LONG | PASS | The simple route has one reaction point |
| strict_raw_sequence_control_PERIOD_M5_PERIOD_M1_LONG | PASS | Unchanged mode 0 cannot use the nonalternating latest raw highs and lows |
| normalized_extreme_not_latest_PERIOD_M5_PERIOD_M1_LONG | PASS | Consecutive same-side pivots retain the most extreme confirmed pivot |
| normalized_complete_signal_PERIOD_M5_PERIOD_M1_LONG | PASS | An ordered normalized LH/LL or HH/HL structure can trigger with the same strict W2 membership |
| normalized_raw_events_unchanged_PERIOD_M5_PERIOD_M1_LONG | PASS | Compression is a current recognition view; the discarded same-side raw pivot still exists in causal history |
| ambiguous_samebar_mode1_PERIOD_M5_PERIOD_M1_LONG | PASS | A candle confirmed as both high and low cannot invent intrabar order or a simple W2 anchor |
| ambiguous_no_signal_mode1_PERIOD_M5_PERIOD_M1_LONG | PASS | A later close cannot turn an ambiguous two-sided swing into a historical trigger |
| ambiguous_samebar_mode2_PERIOD_M5_PERIOD_M1_LONG | PASS | A candle confirmed as both high and low cannot invent intrabar order or a simple W2 anchor |
| ambiguous_no_signal_mode2_PERIOD_M5_PERIOD_M1_LONG | PASS | A later close cannot turn an ambiguous two-sided swing into a historical trigger |
| simple_before_new_extreme_PERIOD_M5_PERIOD_M1_LONG | PASS | The old first reaction line genuinely exists before this reset test |
| simple_new_extreme_before_trigger_PERIOD_M5_PERIOD_M1_LONG | PASS | A bar crossing the old reaction while setting a deeper W2 cannot use that stale line |
| simple_old_reaction_not_reused_PERIOD_M5_PERIOD_M1_LONG | PASS | Once the new W2 is confirmed |
| simple_first_reaction_frozen_PERIOD_M5_PERIOD_M1_LONG | PASS | A later confirmed higher/lower reaction does not move the first line; its availability is the delayed W1 confirmation time |
| simple_historical_cross_not_replayed_PERIOD_M5_PERIOD_M1_LONG | PASS | Crosses before W1 and the reaction line were jointly knowable never execute retrospectively |
| simple_new_fresh_cross_after_known_PERIOD_M5_PERIOD_M1_LONG | PASS | A later fresh cross uses the original known first reaction level |
| simple_already_beyond_line_no_entry_PERIOD_M5_PERIOD_M1_LONG | PASS | Price already beyond the reaction when W1 became known is not a new cross on the following candle |
| simple_rearm_by_actual_recross_PERIOD_M5_PERIOD_M1_LONG | PASS | Only an observable return below/above and subsequent fresh cross can enter this still-active candidate |
| simple_tl_mode_explicit_unmet_PERIOD_M5_PERIOD_M1_LONG | PASS | A pivot diagnostic cannot silently substitute for the selected trendline arm |
| simple_tl_mode_no_fake_line_PERIOD_M5_PERIOD_M1_LONG | PASS | No trendline is extrapolated from zero-valued missing anchors |
| complete_structure_priority_PERIOD_M5_PERIOD_M1_LONG | PASS | A complete W2-bound normalized countertrend takes priority over the simple fallback |
| complete_priority_valid_signal_PERIOD_M5_PERIOD_M1_LONG | PASS | The shorter-reaction route preserves the earlier complete-structure valid entry |
| simple_survives_unrelated_complete_PERIOD_M5_PERIOD_M1_LONG | PASS | A later complete countertrend away from the deepest W2 cannot replace the valid original simple reaction |
| simple_no_rejection_churn_PERIOD_M5_PERIOD_M1_LONG | PASS | Repeated rejection of unrelated full structures leaves first-reaction price |
| unrelated_complete_measured_once_per_key_PERIOD_M5_PERIOD_M1_LONG | PASS | Rejected alternative structures remain measured without silently replacing the accepted simple route |
| complete_only_no_simple_mode0_PERIOD_M5_PERIOD_M1_SHORT | PASS | Modes 0 and 1 retain complete-countertrend requirements for this short reaction |
| complete_only_no_simple_mode1_PERIOD_M5_PERIOD_M1_SHORT | PASS | Modes 0 and 1 retain complete-countertrend requirements for this short reaction |
| simple_preknown_PERIOD_M5_PERIOD_M1_SHORT | PASS | Confirmed W2 pivot and first reaction line are available one full candle before the eventual cross |
| simple_two_pivots_only_PERIOD_M5_PERIOD_M1_SHORT | PASS | No additional retest pivot or strict lower 1->2->3 count is fabricated |
| simple_fresh_cross_signal_PERIOD_M5_PERIOD_M1_SHORT | PASS | A fresh closed cross of the pre-known first reaction level can enter before W1 is reached |
| simple_stage_and_binding_PERIOD_M5_PERIOD_M1_SHORT | PASS | Signal snapshots identify the separate recognition assumption and its W2 membership |
| simple_no_synthetic_trendline_PERIOD_M5_PERIOD_M1_SHORT | PASS | The simple route has one reaction point |
| strict_raw_sequence_control_PERIOD_M5_PERIOD_M1_SHORT | PASS | Unchanged mode 0 cannot use the nonalternating latest raw highs and lows |
| normalized_extreme_not_latest_PERIOD_M5_PERIOD_M1_SHORT | PASS | Consecutive same-side pivots retain the most extreme confirmed pivot |
| normalized_complete_signal_PERIOD_M5_PERIOD_M1_SHORT | PASS | An ordered normalized LH/LL or HH/HL structure can trigger with the same strict W2 membership |
| normalized_raw_events_unchanged_PERIOD_M5_PERIOD_M1_SHORT | PASS | Compression is a current recognition view; the discarded same-side raw pivot still exists in causal history |
| ambiguous_samebar_mode1_PERIOD_M5_PERIOD_M1_SHORT | PASS | A candle confirmed as both high and low cannot invent intrabar order or a simple W2 anchor |
| ambiguous_no_signal_mode1_PERIOD_M5_PERIOD_M1_SHORT | PASS | A later close cannot turn an ambiguous two-sided swing into a historical trigger |
| ambiguous_samebar_mode2_PERIOD_M5_PERIOD_M1_SHORT | PASS | A candle confirmed as both high and low cannot invent intrabar order or a simple W2 anchor |
| ambiguous_no_signal_mode2_PERIOD_M5_PERIOD_M1_SHORT | PASS | A later close cannot turn an ambiguous two-sided swing into a historical trigger |
| simple_before_new_extreme_PERIOD_M5_PERIOD_M1_SHORT | PASS | The old first reaction line genuinely exists before this reset test |
| simple_new_extreme_before_trigger_PERIOD_M5_PERIOD_M1_SHORT | PASS | A bar crossing the old reaction while setting a deeper W2 cannot use that stale line |
| simple_old_reaction_not_reused_PERIOD_M5_PERIOD_M1_SHORT | PASS | Once the new W2 is confirmed |
| simple_first_reaction_frozen_PERIOD_M5_PERIOD_M1_SHORT | PASS | A later confirmed higher/lower reaction does not move the first line; its availability is the delayed W1 confirmation time |
| simple_historical_cross_not_replayed_PERIOD_M5_PERIOD_M1_SHORT | PASS | Crosses before W1 and the reaction line were jointly knowable never execute retrospectively |
| simple_new_fresh_cross_after_known_PERIOD_M5_PERIOD_M1_SHORT | PASS | A later fresh cross uses the original known first reaction level |
| simple_already_beyond_line_no_entry_PERIOD_M5_PERIOD_M1_SHORT | PASS | Price already beyond the reaction when W1 became known is not a new cross on the following candle |
| simple_rearm_by_actual_recross_PERIOD_M5_PERIOD_M1_SHORT | PASS | Only an observable return below/above and subsequent fresh cross can enter this still-active candidate |
| simple_tl_mode_explicit_unmet_PERIOD_M5_PERIOD_M1_SHORT | PASS | A pivot diagnostic cannot silently substitute for the selected trendline arm |
| simple_tl_mode_no_fake_line_PERIOD_M5_PERIOD_M1_SHORT | PASS | No trendline is extrapolated from zero-valued missing anchors |
| complete_structure_priority_PERIOD_M5_PERIOD_M1_SHORT | PASS | A complete W2-bound normalized countertrend takes priority over the simple fallback |
| complete_priority_valid_signal_PERIOD_M5_PERIOD_M1_SHORT | PASS | The shorter-reaction route preserves the earlier complete-structure valid entry |
| simple_survives_unrelated_complete_PERIOD_M5_PERIOD_M1_SHORT | PASS | A later complete countertrend away from the deepest W2 cannot replace the valid original simple reaction |
| simple_no_rejection_churn_PERIOD_M5_PERIOD_M1_SHORT | PASS | Repeated rejection of unrelated full structures leaves first-reaction price |
| unrelated_complete_measured_once_per_key_PERIOD_M5_PERIOD_M1_SHORT | PASS | Rejected alternative structures remain measured without silently replacing the accepted simple route |
