# room_harness: MQL5決定論テスト

実際のMT5内でエンジンを呼び出し、因果順序とLONG/SHORT分岐を確認する合成入力 19項目。PASS 19 / FAIL 0 / UNAVAILABLE 0。未取得をPASSへ算入しない。市場の売買事例とは区別する。

原本: [harness.csv](harness.csv)。

| テスト | 判定 | 詳細 |
|---|---|---|
| accepted_sep5_long | PASS | Executable quote to fixed W1 signed room |
| accepted_long_room | PASS | Executable quote to fixed W1 signed room |
| accepted_sep5_short | PASS | Executable quote to fixed W1 signed room |
| accepted_short_room | PASS | Executable quote to fixed W1 signed room |
| accepted_apr26_long | PASS | Executable quote to fixed W1 signed room |
| late_sep6_rejected | PASS | Executable quote to fixed W1 signed room |
| late_sep6_room | PASS | Executable quote to fixed W1 signed room |
| late_sep17_rejected | PASS | Executable quote to fixed W1 signed room |
| late_sep24_ask_beyond_peak | PASS | Executable quote to fixed W1 signed room |
| beyond_peak_negative | PASS | Executable quote to fixed W1 signed room |
| exact_boundary_long | PASS | Executable quote to fixed W1 signed room |
| exact_boundary_short | PASS | Executable quote to fixed W1 signed room |
| spread_can_cross_boundary | PASS | Executable quote to fixed W1 signed room |
| short_quote_can_cross_boundary | PASS | Executable quote to fixed W1 signed room |
| at_peak_rejected | PASS | Executable quote to fixed W1 signed room |
| legacy_switch_allows_at_peak | PASS | Executable quote to fixed W1 signed room |
| short_past_endpoint_rejected | PASS | Executable quote to fixed W1 signed room |
| legacy_allows_past_endpoint | PASS | Executable quote to fixed W1 signed room |
| invalid_risk_rejected | PASS | Executable quote to fixed W1 signed room |
