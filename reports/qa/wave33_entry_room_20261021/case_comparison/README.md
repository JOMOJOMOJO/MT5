# W1までの余地・下位足認識：固定画像10事例の比較

時刻は元データのブローカー時刻。候補番号を除き、銘柄・上下時間足・方向・候補認識時刻・W1始点日時/価格で照合。
利益や勝敗で抽出しない。controlの再現、同じ候補・固定W1の確認ができない事例は改善済みと判定しない。

- control：v1.30の認識、W1余地の制限なし。
- recognition_only：下位足認識のみ変更、余地の制限なし。
- room_only：v1.30の認識、W1まで最低0.25R。
- full：認識変更＋W1まで最低0.25R。

## 固定事例

|事例|元日時|control再現|full最初のSIGNAL|full約定|余地R・約定時|判定|
|---|---|---|---|---|---|---|
|good_apr26_long|2018.04.26 20:35:00|True|2018.04.26 20:35:00|20:35|1.422|PASS|
|good_sep05_long|2018.09.05 16:10:00|True|なし|なし|—|未成立|
|good_sep05_short|2018.09.05 21:30:00|True|2018.09.05 21:30:00|21:30|1.478|PASS|
|late_sep06_long|2018.09.06 11:55:00|True|2018.09.06 11:55:00|なし|—|PASS|
|late_sep17_long|2018.09.17 16:20:00|True|2018.09.17 16:20:00|なし|—|PASS|
|late_sep24_long|2018.09.24 15:25:00|True|2018.09.24 15:25:00|なし|—|PASS|
|missed_jun07_short|2018.06.07 04:15:00|True|2018.06.07 02:30:00|02:30|0.254|要目視|
|missed_jun27_short|2018.06.27 10:10:00|True|2018.06.27 08:55:00|08:55|1.083|要目視|
|missed_aug27_long|2018.08.27 11:00:00|True|2018.08.27 09:45:00|09:45|0.609|要目視|
|missed_sep05_early_long|2018.09.05 04:00:00|True|なし|なし|—|要目視|

## 全候補の観測数

|設定|候補|SIGNAL|FILL|余地で見送り|最小余地R・発注前|最小余地R・約定後|
|---|---:|---:|---:|---:|---:|---:|
|a_v130_control|271|32|31|0|-0.030|-0.030|
|a_recognition_only|271|124|113|0|-0.239|-0.239|
|a_room_only|271|32|26|5|0.371|0.371|
|a_v140_full|271|120|79|37|0.254|0.254|

## 各設定の事例結果

|事例|設定|SIGNAL|FILL|見送り・失効理由|認識|
|---|---|---|---|---|---|
|good_apr26_long|v130_control|2018.04.26 20:35:00|20:35||STRICT_COUNTERTREND|
|good_apr26_long|recognition_only|2018.04.26 20:35:00|20:35||NORMALIZED_COUNTERTREND|
|good_apr26_long|room_only|2018.04.26 20:35:00|20:35||STRICT_COUNTERTREND|
|good_apr26_long|v140_full|2018.04.26 20:35:00|20:35||NORMALIZED_COUNTERTREND|
|good_sep05_long|v130_control|2018.09.05 16:10:00|16:10||STRICT_COUNTERTREND|
|good_sep05_long|recognition_only|なし|なし|ACTIVE_SETUP_SAME_DIRECTION||
|good_sep05_long|room_only|2018.09.05 16:10:00|16:10||STRICT_COUNTERTREND|
|good_sep05_long|v140_full|なし|なし|ACTIVE_SETUP_SAME_DIRECTION||
|good_sep05_short|v130_control|2018.09.05 21:30:00|21:30||STRICT_COUNTERTREND|
|good_sep05_short|recognition_only|2018.09.05 21:30:00|21:30||NORMALIZED_COUNTERTREND|
|good_sep05_short|room_only|2018.09.05 21:30:00|21:30||STRICT_COUNTERTREND|
|good_sep05_short|v140_full|2018.09.05 21:30:00|21:30||NORMALIZED_COUNTERTREND|
|late_sep06_long|v130_control|2018.09.06 11:55:00|11:55||STRICT_COUNTERTREND|
|late_sep06_long|recognition_only|2018.09.06 11:55:00|11:55||NORMALIZED_COUNTERTREND|
|late_sep06_long|room_only|2018.09.06 11:55:00|なし|WAVE1_ROOM_TOO_SMALL|STRICT_COUNTERTREND|
|late_sep06_long|v140_full|2018.09.06 11:55:00|なし|WAVE1_ROOM_TOO_SMALL|NORMALIZED_COUNTERTREND|
|late_sep17_long|v130_control|2018.09.17 16:20:00|16:20||STRICT_COUNTERTREND|
|late_sep17_long|recognition_only|2018.09.17 16:20:00|16:20||NORMALIZED_COUNTERTREND|
|late_sep17_long|room_only|2018.09.17 16:20:00|なし|WAVE1_ROOM_TOO_SMALL|STRICT_COUNTERTREND|
|late_sep17_long|v140_full|2018.09.17 16:20:00|なし|WAVE1_ROOM_TOO_SMALL|NORMALIZED_COUNTERTREND|
|late_sep24_long|v130_control|2018.09.24 15:25:00|15:25||STRICT_COUNTERTREND|
|late_sep24_long|recognition_only|2018.09.24 15:25:00|15:25||NORMALIZED_COUNTERTREND|
|late_sep24_long|room_only|2018.09.24 15:25:00|なし|WAVE1_ROOM_TOO_SMALL|STRICT_COUNTERTREND|
|late_sep24_long|v140_full|2018.09.24 15:25:00|なし|WAVE1_ROOM_TOO_SMALL|NORMALIZED_COUNTERTREND|
|missed_jun07_short|v130_control|なし|なし|INITIAL_MOVE_MISSED||
|missed_jun07_short|recognition_only|2018.06.07 02:30:00|02:30||SIMPLE_REACTION_BREAK|
|missed_jun07_short|room_only|なし|なし|INITIAL_MOVE_MISSED||
|missed_jun07_short|v140_full|2018.06.07 02:30:00|02:30||SIMPLE_REACTION_BREAK|
|missed_jun27_short|v130_control|なし|なし|INITIAL_MOVE_MISSED||
|missed_jun27_short|recognition_only|2018.06.27 08:55:00|08:55||NORMALIZED_COUNTERTREND|
|missed_jun27_short|room_only|なし|なし|INITIAL_MOVE_MISSED||
|missed_jun27_short|v140_full|2018.06.27 08:55:00|08:55||NORMALIZED_COUNTERTREND|
|missed_aug27_long|v130_control|なし|なし|INITIAL_MOVE_MISSED||
|missed_aug27_long|recognition_only|2018.08.27 09:45:00|09:45||SIMPLE_REACTION_BREAK|
|missed_aug27_long|room_only|なし|なし|INITIAL_MOVE_MISSED||
|missed_aug27_long|v140_full|2018.08.27 09:45:00|09:45||SIMPLE_REACTION_BREAK|
|missed_sep05_early_long|v130_control|なし|なし|INITIAL_MOVE_MISSED||
|missed_sep05_early_long|recognition_only|なし|なし|ACTIVE_SETUP_SAME_DIRECTION||
|missed_sep05_early_long|room_only|なし|なし|INITIAL_MOVE_MISSED||
|missed_sep05_early_long|v140_full|なし|なし|ACTIVE_SETUP_SAME_DIRECTION||

簡易認識 `SIMPLE_REACTION_BREAK` は厳密な下位1→2→3の成立を主張しない。
短い調整の見送り4例は、全てを売買必須とは決めず、早い約定が生じたかを観測した。
正の余地は、W1を越えてTPへ進む保証ではない。最低0.25Rは比較のための初期仮定。
全イベント、基準アンカー差、時刻差、注文価格差、全約定の符号付き余地、欠落候補は [entry_room_case_regression.json](entry_room_case_regression.json) に保存。
