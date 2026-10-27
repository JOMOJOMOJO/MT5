# display_harness: MQL5決定論テスト

実際のMT5内で描画を呼び出し、線の終端と候補別の保持を確認する合成イベント 28項目。PASS 28 / FAIL 0。市場の売買事例とは区別する。

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
