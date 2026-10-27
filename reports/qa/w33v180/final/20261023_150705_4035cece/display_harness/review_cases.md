# display_harness: MQL5決定論テスト

実際のMT5内で描画を呼び出し、線の終端と候補別の保持を確認する合成イベント 101項目。PASS 101 / FAIL 0 / UNAVAILABLE 10。未取得をPASSへ算入しない。市場の売買事例とは区別する。

原本: [harness.csv](harness.csv)。

| テスト | 判定 | 詳細 |
|---|---|---|
| known_time_start | PASS | Decision line starts when first observed |
| live_line_finite | PASS | Candidate extends only through known event time |
| invalidated_candidate_stops | PASS | Past decision evidence remains finite |
| other_candidate_independent | PASS | Closing A leaves B tracking normally |
| signal_stops_structure | PASS | Signal closes upper and lower decision lines |
| signal_stops_fib | PASS | Fib band stops at entry decision |
| diagnostic_sltp_short | PASS | Unordered SL stays one chart bar wide |
| diagnostic_obstacle_short | PASS | Unordered resistance stays a short marker |
| ordered_sltp_track | PASS | Actual position risk lines follow known market time |
| monitor_end_keeps_position | PASS | Setup monitor ending cannot truncate an open position |
| exit_stops_sltp | PASS | SL and TP end at the observed exit |
| exit_stops_obstacle | PASS | Position resistance ends together with risk lines |
| risk_color_retained | PASS | Historical stop and target keep their meaning |
| late_terminal_cannot_reextend | PASS | Repeated terminal observations preserve the original exit end |
| deferred_tracking_cannot_reopen | PASS | Delayed engine position acknowledgement after EXIT cannot reopen closed risk lines |
| trendline_finite | PASS | Projected diagonal is finite |
| lost_trend_stops | PASS | Replaced or lost trigger stops at its last valid time |
| test_end_stops_all | PASS | Tester stop closes remaining live drawings |
| all_lines_no_infinite_rays | PASS | No candidate |
| rejected_signal_no_green_entry | PASS | Room rejection is not drawn as an executed entry |
| source_trace_marker_exists | PASS | Selected native source is marked separately |
| ancient_source_line_adoption_start | PASS | Old source does not extend through the entire history |
| past_low_labeled_reference | PASS | An old low above price is not asserted to be important resistance |
| wave1_room_separate | PASS | Fixed W1 boundary has its own room display |
| rejected_references_finite | PASS | Unordered references stay finite |
| future_obstacle_not_drawn | PASS | Unknown future source is not drawn |
| wave1_not_duplicated | PASS | W1 is not repeated as unrelated purple resistance |
| wave1_reference_stops_at_exit | PASS | W1 reference follows and ends with the real position |
| no_opposite_cause_before_observation_LONG | PASS | An ordinary fill alone does not claim an opposite-wave decision existed |
| opposite_wait_at_known_time_LONG | PASS | The warning is placed when the opposite first wave became known |
| opposite_observation_point_at_known_time_LONG | PASS | The knowledge-time marker identifies the existing position's entry level without backdating |
| opposite_wait_caption_explains_pending_profit_LONG | PASS | Gold identifies a pending positive-net exit and is distinct from a new green entry |
| opposite_wait_source_and_known_tooltip_LONG | UNAVAILABLE | This tester cannot read even a short TOOLTIP probe; verify source and full known time in normal-chart replay inventory |
| opposite_wait_keeps_original_protection_LONG | PASS | Arming leaves original stop/target prices active and creates no premature exit marker |
| partial_exit_does_not_claim_flat_LONG | PASS | A partial close does not draw the completed-position exit or end residual risk lines |
| opposite_exit_at_actual_fill_LONG | PASS | The exit point uses the actual close fill time and price rather than request time |
| opposite_exit_caption_causal_reason_LONG | PASS | The close caption explicitly gives the opposite-first-wave profit reason at the fill location |
| opposite_exit_tooltip_execution_trace_LONG | UNAVAILABLE | This tester cannot read TOOLTIP; verify source |
| opposite_exit_stops_risk_at_actual_fill_LONG | PASS | All position risk/reference lines stop at the actual close and remain finite after later observations |
| no_opposite_cause_before_observation_SHORT | PASS | An ordinary fill alone does not claim an opposite-wave decision existed |
| opposite_wait_at_known_time_SHORT | PASS | The warning is placed when the opposite first wave became known |
| opposite_observation_point_at_known_time_SHORT | PASS | The knowledge-time marker identifies the existing position's entry level without backdating |
| opposite_wait_caption_explains_pending_profit_SHORT | PASS | Gold identifies a pending positive-net exit and is distinct from a new green entry |
| opposite_wait_source_and_known_tooltip_SHORT | UNAVAILABLE | This tester cannot read even a short TOOLTIP probe; verify source and full known time in normal-chart replay inventory |
| opposite_wait_keeps_original_protection_SHORT | PASS | Arming leaves original stop/target prices active and creates no premature exit marker |
| partial_exit_does_not_claim_flat_SHORT | PASS | A partial close does not draw the completed-position exit or end residual risk lines |
| opposite_exit_at_actual_fill_SHORT | PASS | The exit point uses the actual close fill time and price rather than request time |
| opposite_exit_caption_causal_reason_SHORT | PASS | The close caption explicitly gives the opposite-first-wave profit reason at the fill location |
| opposite_exit_tooltip_execution_trace_SHORT | UNAVAILABLE | This tester cannot read TOOLTIP; verify source |
| opposite_exit_stops_risk_at_actual_fill_SHORT | PASS | All position risk/reference lines stop at the actual close and remain finite after later observations |
| ordinary_tp_not_labeled_opposite_exit | PASS | A broker target close is not mislabeled as the new opposite-wave policy |
| extension_archives_old_wave_LONG | PASS | The original endpoint remains at its original time/price as gray dashed history |
| extension_closes_old_fib_at_observation_LONG | PASS | The previous band preserves its first availability and stops when the extension became known |
| extension_archives_old_pullback_LONG | PASS | The abandoned W2 remains separate gray evidence rather than an orange current pullback |
| extension_closes_old_lower_trigger_LONG | PASS | A trigger derived from the old W2 stops at re-anchoring |
| extension_pending_has_no_fixed_anchors_LONG | PASS | A newly observed extension is visibly provisional and cannot imply confirmed W1 |
| extension_provisional_updates_without_rewriting_history_LONG | PASS | Only the current provisional leg moves; old anchors and retired bands remain unchanged |
| extension_confirmed_owns_new_blue_leg_LONG | PASS | Only after confirmation is a new blue revision created and its temporary tracking caption removed |
| extension_new_fib_starts_when_confirmed_LONG | PASS | The recomputed band begins at the new knowledge time and does not fill the intervening unknown history |
| extension_confirmation_has_separate_known_marker_LONG | PASS | Retrospective swing location and actual confirmation availability are marked separately |
| extension_tooltip_retains_provenance_LONG | UNAVAILABLE | This tester cannot read TOOLTIP; old and revised confirmation timestamps require recorded normal-chart inventory |
| extension_new_pullback_is_distinct_LONG | PASS | A correction under the new anchors cannot overwrite the retired correction |
| multiple_extensions_keep_each_revision_finite_LONG | PASS | Repeated re-anchoring preserves separately dated finite revisions instead of rewriting one continuous band |
| extension_events_cannot_create_trade_LONG | PASS | Display-only extension events do not imply a signal |
| extended_candidate_terminal_stops_current_band_LONG | PASS | Ending the setup stops only its current revision and cannot reopen any older Fib band |
| extension_archives_old_wave_SHORT | PASS | The original endpoint remains at its original time/price as gray dashed history |
| extension_closes_old_fib_at_observation_SHORT | PASS | The previous band preserves its first availability and stops when the extension became known |
| extension_archives_old_pullback_SHORT | PASS | The abandoned W2 remains separate gray evidence rather than an orange current pullback |
| extension_closes_old_lower_trigger_SHORT | PASS | A trigger derived from the old W2 stops at re-anchoring |
| extension_pending_has_no_fixed_anchors_SHORT | PASS | A newly observed extension is visibly provisional and cannot imply confirmed W1 |
| extension_provisional_updates_without_rewriting_history_SHORT | PASS | Only the current provisional leg moves; old anchors and retired bands remain unchanged |
| extension_confirmed_owns_new_blue_leg_SHORT | PASS | Only after confirmation is a new blue revision created and its temporary tracking caption removed |
| extension_new_fib_starts_when_confirmed_SHORT | PASS | The recomputed band begins at the new knowledge time and does not fill the intervening unknown history |
| extension_confirmation_has_separate_known_marker_SHORT | PASS | Retrospective swing location and actual confirmation availability are marked separately |
| extension_tooltip_retains_provenance_SHORT | UNAVAILABLE | This tester cannot read TOOLTIP; old and revised confirmation timestamps require recorded normal-chart inventory |
| extension_new_pullback_is_distinct_SHORT | PASS | A correction under the new anchors cannot overwrite the retired correction |
| multiple_extensions_keep_each_revision_finite_SHORT | PASS | Repeated re-anchoring preserves separately dated finite revisions instead of rewriting one continuous band |
| extension_events_cannot_create_trade_SHORT | PASS | Display-only extension events do not imply a signal |
| extended_candidate_terminal_stops_current_band_SHORT | PASS | Ending the setup stops only its current revision and cannot reopen any older Fib band |
| connected_cancel_not_drawn_before_candidate_LONG | PASS | A known older W1 alone cannot claim that a future opposite candidate already existed |
| connected_cancel_marks_candidate_known_time_LONG | PASS | The red observation point is at candidate availability |
| connected_cancel_caption_explains_reason_LONG | PASS | The cancelled old setup explicitly gives the connected opposite-candidate reason |
| connected_cancel_leader_finite_LONG | PASS | The causal point and spaced caption use a finite one-bar leader |
| connected_cancel_does_not_claim_trade_LONG | PASS | Pre-order invalidation is distinct from an entry or the existing post-fill positive exit |
| connected_cancel_provenance_tooltips_LONG | UNAVAILABLE | This tester cannot read TOOLTIP; verify source and shared swing in recorded normal-chart inventory |
| connected_cancel_stays_closed_LONG | PASS | Later observed market time cannot extend the cancelled setup or its cancellation leader |
| connected_future_source_not_drawn_LONG | PASS | An invalid snapshot cannot reveal an opposite source before its availability time |
| connected_cancel_not_drawn_before_candidate_SHORT | PASS | A known older W1 alone cannot claim that a future opposite candidate already existed |
| connected_cancel_marks_candidate_known_time_SHORT | PASS | The red observation point is at candidate availability |
| connected_cancel_caption_explains_reason_SHORT | PASS | The cancelled old setup explicitly gives the connected opposite-candidate reason |
| connected_cancel_leader_finite_SHORT | PASS | The causal point and spaced caption use a finite one-bar leader |
| connected_cancel_does_not_claim_trade_SHORT | PASS | Pre-order invalidation is distinct from an entry or the existing post-fill positive exit |
| connected_cancel_provenance_tooltips_SHORT | UNAVAILABLE | This tester cannot read TOOLTIP; verify source and shared swing in recorded normal-chart inventory |
| connected_cancel_stays_closed_SHORT | PASS | Later observed market time cannot extend the cancelled setup or its cancellation leader |
| connected_future_source_not_drawn_SHORT | PASS | An invalid snapshot cannot reveal an opposite source before its availability time |
| target_adjustment_alone_not_entry_LONG | PASS | A target adjustment diagnostic alone never draws an entry or an executable risk line |
| extended_target_uses_final_fixed_price_LONG | PASS | The green target has the final W1-buffer price |
| extended_target_caption_identifies_w1_LONG | PASS | The compact caption distinguishes the W1 target without adding a fixed chart panel |
| extended_target_tooltips_separate_rr_source_LONG | UNAVAILABLE | This tester cannot read TOOLTIP; final/base prices and W1 known time require recorded normal-chart inventory |
| later_adjustment_event_cannot_reanchor_target_LONG | PASS | A supplementary diagnostic after fill cannot rewrite the original target |
| extended_target_line_ends_at_exit_LONG | PASS | Extended targets retain the ordinary finite position lifecycle |
| cancelled_extension_keeps_plain_tp_caption_LONG | PASS | A final cap below the RR target is not misleadingly labelled as a W1 extension |
| future_w1_not_claimed_as_target_source_LONG | PASS | Unknown W1 provenance cannot be presented as a known W1 target source |
| target_adjustment_alone_not_entry_SHORT | PASS | A target adjustment diagnostic alone never draws an entry or an executable risk line |
| extended_target_uses_final_fixed_price_SHORT | PASS | The green target has the final W1-buffer price |
| extended_target_caption_identifies_w1_SHORT | PASS | The compact caption distinguishes the W1 target without adding a fixed chart panel |
| extended_target_tooltips_separate_rr_source_SHORT | UNAVAILABLE | This tester cannot read TOOLTIP; final/base prices and W1 known time require recorded normal-chart inventory |
| later_adjustment_event_cannot_reanchor_target_SHORT | PASS | A supplementary diagnostic after fill cannot rewrite the original target |
| extended_target_line_ends_at_exit_SHORT | PASS | Extended targets retain the ordinary finite position lifecycle |
| cancelled_extension_keeps_plain_tp_caption_SHORT | PASS | A final cap below the RR target is not misleadingly labelled as a W1 extension |
| future_w1_not_claimed_as_target_source_SHORT | PASS | Unknown W1 provenance cannot be presented as a known W1 target source |
