# connected_harness: MQL5決定論テスト

実際のMT5内でエンジンを呼び出し、因果順序とLONG/SHORT分岐を確認する合成入力 120項目。PASS 120 / FAIL 0 / UNAVAILABLE 0。未取得をPASSへ算入しない。市場の売買事例とは区別する。

原本: [harness.csv](harness.csv)。

| テスト | 判定 | 詳細 |
|---|---|---|
| pure_matching_anchor | PASS | A known exact shared endpoint qualifies |
| pure_reject_boundary_0 | PASS | Unfixed |
| pure_reject_boundary_1 | PASS | Unfixed |
| pure_reject_boundary_2 | PASS | Unfixed |
| pure_reject_boundary_3 | PASS | Unfixed |
| pure_reject_boundary_4 | PASS | Unfixed |
| pure_reject_boundary_5 | PASS | Unfixed |
| pure_reject_boundary_6 | PASS | Unfixed |
| pure_reject_boundary_7 | PASS | Unfixed |
| pure_reject_boundary_8 | PASS | Unfixed |
| pure_reject_boundary_9 | PASS | Unfixed |
| pure_reject_boundary_10 | PASS | Unfixed |
| pure_reject_boundary_11 | PASS | Unfixed |
| pure_reject_boundary_12 | PASS | Unfixed |
| pure_reject_boundary_13 | PASS | Unfixed |
| pure_reject_boundary_14 | PASS | Unfixed |
| pure_reject_boundary_15 | PASS | Unfixed |
| pure_reject_boundary_16 | PASS | Unfixed |
| pure_reject_boundary_17 | PASS | Unfixed |
| pure_reject_boundary_18 | PASS | Unfixed |
| pure_reject_boundary_19 | PASS | Unfixed |
| pure_reject_boundary_20 | PASS | Unfixed |
| pure_half_point_inclusive | PASS | Exact half-point equality is accepted with arithmetic-only representation tolerance |
| pure_signal_without_order_allowed | PASS | An emitted diagnostic signal without any submission or fill is still unordered |
| fixture_old_fixed_PERIOD_M15_PERIOD_M5_LONG_candidate | PASS | The original candidate and optional signal come from actual closed-bar engine processing |
| adopted_reverse_cancels_old_PERIOD_M15_PERIOD_M5_LONG_candidate | PASS | A genuinely adopted opposite candidate invalidates only the old unordered setup |
| shared_anchor_provenance_PERIOD_M15_PERIOD_M5_LONG_candidate | PASS | Cancellation links the two setup IDs and retains the shared candle |
| candidate_not_future_peak_PERIOD_M15_PERIOD_M5_LONG_candidate | PASS | Cancellation uses the already known origin at candidate detection and never waits for or invents its later endpoint |
| event_order_exclusion_PERIOD_M15_PERIOD_M5_LONG_candidate | PASS | The new break is published before exactly one explicit exclusion |
| cancelled_never_resignals_PERIOD_M15_PERIOD_M5_LONG_candidate | PASS | Later lower bars and repeated upper delivery cannot create a second signal or submit the terminally cancelled setup |
| fixture_old_fixed_PERIOD_M15_PERIOD_M5_LONG_signal | PASS | The original candidate and optional signal come from actual closed-bar engine processing |
| adopted_reverse_cancels_old_PERIOD_M15_PERIOD_M5_LONG_signal | PASS | A genuinely adopted opposite candidate invalidates only the old unordered setup |
| shared_anchor_provenance_PERIOD_M15_PERIOD_M5_LONG_signal | PASS | Cancellation links the two setup IDs and retains the shared candle |
| candidate_not_future_peak_PERIOD_M15_PERIOD_M5_LONG_signal | PASS | Cancellation uses the already known origin at candidate detection and never waits for or invents its later endpoint |
| event_order_exclusion_PERIOD_M15_PERIOD_M5_LONG_signal | PASS | The new break is published before exactly one explicit exclusion |
| cancelled_never_resignals_PERIOD_M15_PERIOD_M5_LONG_signal | PASS | Later lower bars and repeated upper delivery cannot create a second signal or submit the terminally cancelled setup |
| off_or_constructor_default0_PERIOD_M15_PERIOD_M5_LONG | PASS | Explicit OFF and the constructor default retain existing independent directional lanes |
| off_or_constructor_default1_PERIOD_M15_PERIOD_M5_LONG | PASS | Explicit OFF and the constructor default retain existing independent directional lanes |
| forming_break_no_cancel_PERIOD_M15_PERIOD_M5_LONG | PASS | An unfinished upper break candle cannot adopt a reverse candidate or cancel an older setup |
| late_delivery_not_backdated_PERIOD_M15_PERIOD_M5_LONG | PASS | Theoretical candle close and actual late knowledge remain distinct and cancellation is published only now |
| submitted_or_position_protected0_PERIOD_M15_PERIOD_M5_LONG | PASS | Neither a submitted order nor an actual open position is cancelled by the candidate-only policy |
| finish_cannot_release_order0_PERIOD_M15_PERIOD_M5_LONG | PASS | A final unordered completion cannot release a submitted order or an open position |
| failed_submission_releases_guard_PERIOD_M15_PERIOD_M5_LONG | PASS | A caller can explicitly release a rejected order's guard before completing that unordered setup |
| submitted_or_position_protected1_PERIOD_M15_PERIOD_M5_LONG | PASS | Neither a submitted order nor an actual open position is cancelled by the candidate-only policy |
| finish_cannot_release_order1_PERIOD_M15_PERIOD_M5_LONG | PASS | A final unordered completion cannot release a submitted order or an open position |
| untriggered_cannot_be_submitted_PERIOD_M15_PERIOD_M5_LONG | PASS | A fabricated submission cannot protect an untriggered candidate |
| skipped_lane_break_no_side_effect_PERIOD_M15_PERIOD_M5_LONG | PASS | A temporary break rejected by the occupied same-direction lane cannot cancel the opposite adopted setup |
| temporary_create_restores_submission_PERIOD_M15_PERIOD_M5_LONG | PASS | The temporary setup snapshot restores the original submitted-order guard as well as its strategy fields |
| fixture_old_fixed_PERIOD_M15_PERIOD_M5_SHORT_candidate | PASS | The original candidate and optional signal come from actual closed-bar engine processing |
| adopted_reverse_cancels_old_PERIOD_M15_PERIOD_M5_SHORT_candidate | PASS | A genuinely adopted opposite candidate invalidates only the old unordered setup |
| shared_anchor_provenance_PERIOD_M15_PERIOD_M5_SHORT_candidate | PASS | Cancellation links the two setup IDs and retains the shared candle |
| candidate_not_future_peak_PERIOD_M15_PERIOD_M5_SHORT_candidate | PASS | Cancellation uses the already known origin at candidate detection and never waits for or invents its later endpoint |
| event_order_exclusion_PERIOD_M15_PERIOD_M5_SHORT_candidate | PASS | The new break is published before exactly one explicit exclusion |
| cancelled_never_resignals_PERIOD_M15_PERIOD_M5_SHORT_candidate | PASS | Later lower bars and repeated upper delivery cannot create a second signal or submit the terminally cancelled setup |
| fixture_old_fixed_PERIOD_M15_PERIOD_M5_SHORT_signal | PASS | The original candidate and optional signal come from actual closed-bar engine processing |
| adopted_reverse_cancels_old_PERIOD_M15_PERIOD_M5_SHORT_signal | PASS | A genuinely adopted opposite candidate invalidates only the old unordered setup |
| shared_anchor_provenance_PERIOD_M15_PERIOD_M5_SHORT_signal | PASS | Cancellation links the two setup IDs and retains the shared candle |
| candidate_not_future_peak_PERIOD_M15_PERIOD_M5_SHORT_signal | PASS | Cancellation uses the already known origin at candidate detection and never waits for or invents its later endpoint |
| event_order_exclusion_PERIOD_M15_PERIOD_M5_SHORT_signal | PASS | The new break is published before exactly one explicit exclusion |
| cancelled_never_resignals_PERIOD_M15_PERIOD_M5_SHORT_signal | PASS | Later lower bars and repeated upper delivery cannot create a second signal or submit the terminally cancelled setup |
| off_or_constructor_default0_PERIOD_M15_PERIOD_M5_SHORT | PASS | Explicit OFF and the constructor default retain existing independent directional lanes |
| off_or_constructor_default1_PERIOD_M15_PERIOD_M5_SHORT | PASS | Explicit OFF and the constructor default retain existing independent directional lanes |
| forming_break_no_cancel_PERIOD_M15_PERIOD_M5_SHORT | PASS | An unfinished upper break candle cannot adopt a reverse candidate or cancel an older setup |
| late_delivery_not_backdated_PERIOD_M15_PERIOD_M5_SHORT | PASS | Theoretical candle close and actual late knowledge remain distinct and cancellation is published only now |
| submitted_or_position_protected0_PERIOD_M15_PERIOD_M5_SHORT | PASS | Neither a submitted order nor an actual open position is cancelled by the candidate-only policy |
| finish_cannot_release_order0_PERIOD_M15_PERIOD_M5_SHORT | PASS | A final unordered completion cannot release a submitted order or an open position |
| failed_submission_releases_guard_PERIOD_M15_PERIOD_M5_SHORT | PASS | A caller can explicitly release a rejected order's guard before completing that unordered setup |
| submitted_or_position_protected1_PERIOD_M15_PERIOD_M5_SHORT | PASS | Neither a submitted order nor an actual open position is cancelled by the candidate-only policy |
| finish_cannot_release_order1_PERIOD_M15_PERIOD_M5_SHORT | PASS | A final unordered completion cannot release a submitted order or an open position |
| untriggered_cannot_be_submitted_PERIOD_M15_PERIOD_M5_SHORT | PASS | A fabricated submission cannot protect an untriggered candidate |
| skipped_lane_break_no_side_effect_PERIOD_M15_PERIOD_M5_SHORT | PASS | A temporary break rejected by the occupied same-direction lane cannot cancel the opposite adopted setup |
| temporary_create_restores_submission_PERIOD_M15_PERIOD_M5_SHORT | PASS | The temporary setup snapshot restores the original submitted-order guard as well as its strategy fields |
| fixture_old_fixed_PERIOD_M5_PERIOD_M1_LONG_candidate | PASS | The original candidate and optional signal come from actual closed-bar engine processing |
| adopted_reverse_cancels_old_PERIOD_M5_PERIOD_M1_LONG_candidate | PASS | A genuinely adopted opposite candidate invalidates only the old unordered setup |
| shared_anchor_provenance_PERIOD_M5_PERIOD_M1_LONG_candidate | PASS | Cancellation links the two setup IDs and retains the shared candle |
| candidate_not_future_peak_PERIOD_M5_PERIOD_M1_LONG_candidate | PASS | Cancellation uses the already known origin at candidate detection and never waits for or invents its later endpoint |
| event_order_exclusion_PERIOD_M5_PERIOD_M1_LONG_candidate | PASS | The new break is published before exactly one explicit exclusion |
| cancelled_never_resignals_PERIOD_M5_PERIOD_M1_LONG_candidate | PASS | Later lower bars and repeated upper delivery cannot create a second signal or submit the terminally cancelled setup |
| fixture_old_fixed_PERIOD_M5_PERIOD_M1_LONG_signal | PASS | The original candidate and optional signal come from actual closed-bar engine processing |
| adopted_reverse_cancels_old_PERIOD_M5_PERIOD_M1_LONG_signal | PASS | A genuinely adopted opposite candidate invalidates only the old unordered setup |
| shared_anchor_provenance_PERIOD_M5_PERIOD_M1_LONG_signal | PASS | Cancellation links the two setup IDs and retains the shared candle |
| candidate_not_future_peak_PERIOD_M5_PERIOD_M1_LONG_signal | PASS | Cancellation uses the already known origin at candidate detection and never waits for or invents its later endpoint |
| event_order_exclusion_PERIOD_M5_PERIOD_M1_LONG_signal | PASS | The new break is published before exactly one explicit exclusion |
| cancelled_never_resignals_PERIOD_M5_PERIOD_M1_LONG_signal | PASS | Later lower bars and repeated upper delivery cannot create a second signal or submit the terminally cancelled setup |
| off_or_constructor_default0_PERIOD_M5_PERIOD_M1_LONG | PASS | Explicit OFF and the constructor default retain existing independent directional lanes |
| off_or_constructor_default1_PERIOD_M5_PERIOD_M1_LONG | PASS | Explicit OFF and the constructor default retain existing independent directional lanes |
| forming_break_no_cancel_PERIOD_M5_PERIOD_M1_LONG | PASS | An unfinished upper break candle cannot adopt a reverse candidate or cancel an older setup |
| late_delivery_not_backdated_PERIOD_M5_PERIOD_M1_LONG | PASS | Theoretical candle close and actual late knowledge remain distinct and cancellation is published only now |
| submitted_or_position_protected0_PERIOD_M5_PERIOD_M1_LONG | PASS | Neither a submitted order nor an actual open position is cancelled by the candidate-only policy |
| finish_cannot_release_order0_PERIOD_M5_PERIOD_M1_LONG | PASS | A final unordered completion cannot release a submitted order or an open position |
| failed_submission_releases_guard_PERIOD_M5_PERIOD_M1_LONG | PASS | A caller can explicitly release a rejected order's guard before completing that unordered setup |
| submitted_or_position_protected1_PERIOD_M5_PERIOD_M1_LONG | PASS | Neither a submitted order nor an actual open position is cancelled by the candidate-only policy |
| finish_cannot_release_order1_PERIOD_M5_PERIOD_M1_LONG | PASS | A final unordered completion cannot release a submitted order or an open position |
| untriggered_cannot_be_submitted_PERIOD_M5_PERIOD_M1_LONG | PASS | A fabricated submission cannot protect an untriggered candidate |
| skipped_lane_break_no_side_effect_PERIOD_M5_PERIOD_M1_LONG | PASS | A temporary break rejected by the occupied same-direction lane cannot cancel the opposite adopted setup |
| temporary_create_restores_submission_PERIOD_M5_PERIOD_M1_LONG | PASS | The temporary setup snapshot restores the original submitted-order guard as well as its strategy fields |
| fixture_old_fixed_PERIOD_M5_PERIOD_M1_SHORT_candidate | PASS | The original candidate and optional signal come from actual closed-bar engine processing |
| adopted_reverse_cancels_old_PERIOD_M5_PERIOD_M1_SHORT_candidate | PASS | A genuinely adopted opposite candidate invalidates only the old unordered setup |
| shared_anchor_provenance_PERIOD_M5_PERIOD_M1_SHORT_candidate | PASS | Cancellation links the two setup IDs and retains the shared candle |
| candidate_not_future_peak_PERIOD_M5_PERIOD_M1_SHORT_candidate | PASS | Cancellation uses the already known origin at candidate detection and never waits for or invents its later endpoint |
| event_order_exclusion_PERIOD_M5_PERIOD_M1_SHORT_candidate | PASS | The new break is published before exactly one explicit exclusion |
| cancelled_never_resignals_PERIOD_M5_PERIOD_M1_SHORT_candidate | PASS | Later lower bars and repeated upper delivery cannot create a second signal or submit the terminally cancelled setup |
| fixture_old_fixed_PERIOD_M5_PERIOD_M1_SHORT_signal | PASS | The original candidate and optional signal come from actual closed-bar engine processing |
| adopted_reverse_cancels_old_PERIOD_M5_PERIOD_M1_SHORT_signal | PASS | A genuinely adopted opposite candidate invalidates only the old unordered setup |
| shared_anchor_provenance_PERIOD_M5_PERIOD_M1_SHORT_signal | PASS | Cancellation links the two setup IDs and retains the shared candle |
| candidate_not_future_peak_PERIOD_M5_PERIOD_M1_SHORT_signal | PASS | Cancellation uses the already known origin at candidate detection and never waits for or invents its later endpoint |
| event_order_exclusion_PERIOD_M5_PERIOD_M1_SHORT_signal | PASS | The new break is published before exactly one explicit exclusion |
| cancelled_never_resignals_PERIOD_M5_PERIOD_M1_SHORT_signal | PASS | Later lower bars and repeated upper delivery cannot create a second signal or submit the terminally cancelled setup |
| off_or_constructor_default0_PERIOD_M5_PERIOD_M1_SHORT | PASS | Explicit OFF and the constructor default retain existing independent directional lanes |
| off_or_constructor_default1_PERIOD_M5_PERIOD_M1_SHORT | PASS | Explicit OFF and the constructor default retain existing independent directional lanes |
| forming_break_no_cancel_PERIOD_M5_PERIOD_M1_SHORT | PASS | An unfinished upper break candle cannot adopt a reverse candidate or cancel an older setup |
| late_delivery_not_backdated_PERIOD_M5_PERIOD_M1_SHORT | PASS | Theoretical candle close and actual late knowledge remain distinct and cancellation is published only now |
| submitted_or_position_protected0_PERIOD_M5_PERIOD_M1_SHORT | PASS | Neither a submitted order nor an actual open position is cancelled by the candidate-only policy |
| finish_cannot_release_order0_PERIOD_M5_PERIOD_M1_SHORT | PASS | A final unordered completion cannot release a submitted order or an open position |
| failed_submission_releases_guard_PERIOD_M5_PERIOD_M1_SHORT | PASS | A caller can explicitly release a rejected order's guard before completing that unordered setup |
| submitted_or_position_protected1_PERIOD_M5_PERIOD_M1_SHORT | PASS | Neither a submitted order nor an actual open position is cancelled by the candidate-only policy |
| finish_cannot_release_order1_PERIOD_M5_PERIOD_M1_SHORT | PASS | A final unordered completion cannot release a submitted order or an open position |
| untriggered_cannot_be_submitted_PERIOD_M5_PERIOD_M1_SHORT | PASS | A fabricated submission cannot protect an untriggered candidate |
| skipped_lane_break_no_side_effect_PERIOD_M5_PERIOD_M1_SHORT | PASS | A temporary break rejected by the occupied same-direction lane cannot cancel the opposite adopted setup |
| temporary_create_restores_submission_PERIOD_M5_PERIOD_M1_SHORT | PASS | The temporary setup snapshot restores the original submitted-order guard as well as its strategy fields |
