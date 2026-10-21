# display_harness: MQL5決定論テスト

実際のMT5内でエンジンを呼び出した 18項目。PASS 18 / FAIL 0。市場の売買事例ではなく、因果順序とLONG/SHORT分岐を確認する合成入力である。

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
| trendline_finite | PASS | Projected diagonal is finite |
| lost_trend_stops | PASS | Replaced or lost trigger stops at its last valid time |
| test_end_stops_all | PASS | Tester stop closes remaining live drawings |
| all_lines_no_infinite_rays | PASS | No candidate |
