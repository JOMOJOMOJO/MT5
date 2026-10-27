# Wave33 v1.40：描画付き15事例

Aはユーザー画像の固定10候補、Bは時間順とLONG/SHORT・成立/失効を含む5候補。勝敗で選んでいない。時刻はブローカー時計。ユーザーの判定（一致／認識遅れ・過剰／動画から判断不能）は未記入。

**画像は通常チャートへの記録イベント再生**。各判定時点までの実M1データを使用し、シグナル再計算・注文はしない。 nativeテスターの発注・決済は別の原本CSVで照合する。

|区分・事例|方向・候補認定|W1終点位置 → 知り得た時刻|転換ライン既知 → SIGNAL既知|認定・結果|画像|
|---|---|---|---|---|---|
|A0 good_apr26_long|LONG / 2018.04.26 17:45:00|2018.04.26 18:15:00 → 2018.04.26 19:00:00|2018.04.26 20:30:00 → 2018.04.26 20:35:00|NORMALIZED_COUNTERTREND / 発注・約定|[PNG](final_drawing_a/A/W33R_14242942957B93CC_0.png)|
|A1 good_sep05_long|LONG / 2018.09.05 12:30:00|2018.09.05 13:30:00 → 2018.09.05 14:15:00|2018.09.05 16:05:00 → 2018.09.05 16:10:00|NORMALIZED_COUNTERTREND / 発注・約定|[PNG](final_drawing_a/A/W33R_15242AD5D7479319_1.png)|
|A2 good_sep05_short|SHORT / 2018.09.05 18:45:00|2018.09.05 19:00:00 → 2018.09.05 19:45:00|2018.09.05 21:10:00 → 2018.09.05 21:30:00|NORMALIZED_COUNTERTREND / 発注・約定|[PNG](final_drawing_a/A/W33R_1224261C7EEB20D6_2.png)|
|A3 late_sep06_long|LONG / 2018.09.06 06:45:00|2018.09.06 07:30:00 → 2018.09.06 08:15:00|2018.09.06 11:30:00 → 2018.09.06 11:55:00|NORMALIZED_COUNTERTREND / 余地不足で見送り|[PNG](final_drawing_a/A/W33R_132427AFF6F29643_3.png)|
|A4 late_sep17_long|LONG / 2018.09.17 13:00:00|2018.09.17 14:00:00 → 2018.09.17 14:45:00|2018.09.17 16:15:00 → 2018.09.17 16:20:00|NORMALIZED_COUNTERTREND / 余地不足で見送り|[PNG](final_drawing_a/A/W33R_102422F6220D0468_4.png)|
|A5 late_sep24_long|LONG / 2018.09.24 11:45:00|2018.09.24 11:45:00 → 2018.09.24 12:30:00|2018.09.24 15:05:00 → 2018.09.24 15:25:00|NORMALIZED_COUNTERTREND / 余地不足で見送り|[PNG](final_drawing_a/A/W33R_1124248967CE6EF5_5.png)|
|A6 missed_jun07_short|SHORT / 2018.06.06 23:45:00|2018.06.07 00:00:00 → 2018.06.07 00:45:00|2018.06.07 01:55:00 → 2018.06.07 02:30:00|SIMPLE_REACTION_BREAK / 発注・約定|[PNG](final_drawing_a/A/W33R_0E241FD0B7A12AB2_6.png)|
|A7 missed_jun27_short|SHORT / 2018.06.27 04:00:00|2018.06.27 04:45:00 → 2018.06.27 05:30:00|2018.06.27 08:45:00 → 2018.06.27 08:55:00|NORMALIZED_COUNTERTREND / 発注・約定|[PNG](final_drawing_a/A/W33R_0F242163F35878DF_7.png)|
|A8 missed_aug27_long|LONG / 2018.08.27 07:30:00|2018.08.27 08:00:00 → 2018.08.27 08:45:00|2018.08.27 09:25:00 → 2018.08.27 09:45:00|SIMPLE_REACTION_BREAK / 発注・約定|[PNG](final_drawing_a/A/W33R_1C2435DAED862E64_8.png)|
|A9 missed_sep05_early_long|LONG / 2018.09.05 01:30:00|2018.09.05 01:30:00 → 2018.09.05 02:15:00|2018.09.05 02:15:00 → なし|SIMPLE_REACTION_BREAK / INITIAL_MOVE_MISSED|[PNG](final_drawing_a/A/W33R_1D24376DE6702611_9.png)|
|B0 XAU_0|LONG / 2025.01.06 03:00:00|2025.01.06 03:20:00 → 2025.01.06 03:35:00|2025.01.06 04:05:00 → 2025.01.06 04:06:00|NORMALIZED_COUNTERTREND / 発注・約定|[PNG](final_drawing_b/B/W33R_D3A0BD9D893A8209_0.png)|
|B1 XAU_1|SHORT / 2025.01.06 05:20:00|2025.01.06 05:45:00 → 2025.01.06 06:00:00|2025.01.06 06:16:00 → なし|SIMPLE_REACTION_BREAK / TIMEOUT / NO_LOWER_REVERSAL|[PNG](final_drawing_b/B/W33R_D2A0BC0AD24F4C0C_1.png)|
|B2 XAU_2|LONG / 2025.01.06 10:25:00|2025.01.06 10:30:00 → 2025.01.06 10:45:00|2025.01.06 10:45:00 → 2025.01.06 10:48:00|SIMPLE_REACTION_BREAK / 発注・約定|[PNG](final_drawing_b/B/W33R_D1A0BA77D9EF44C3_2.png)|
|B3 XAU_3|SHORT / 2025.01.06 15:30:00|2025.01.06 15:45:00 → 2025.01.06 16:00:00|2025.01.06 17:11:00 → 2025.01.06 17:12:00|NORMALIZED_COUNTERTREND / 発注・約定|[PNG](final_drawing_b/B/W33R_D0A0B8E4920028A6_3.png)|
|B4 XAU_4| / | → |なし → なし|未成立 / LH|[PNG](final_drawing_b/B/W33R_CFA0B7517AA9A1F5_4.png)|

A3/4/5の青①まで余地は0.128/0.052/-0.030Rで、緑ENTRYは描かず赤点・見送り理由を表示。元の判定価格と、読みやすく移した文字を短い補助線で結ぶ。紫の元高安には同じR番号を置き、画面外の古い高安は現在位置のラベルに元日時を併記する。

A6は02:30の時点で01:05高値110.174をW2に採用している。旧画像の03:20高値110.220からの入口とは異なり、未来のW2高値を利用した説明にはしない。A9は確定反応が間に合わず引き続き初動終了。

B1/B4の長い未成立期間は画面の時間・価格圧縮が大きく、細部の照合にはMT5で拡大して見る。固定パネルは表示せず、過去候補の有限線と高安を残す。

[固定4設定比較](final_case_comparison/README.md) / [15件のnative object監査](drawing_audit.json) / [原本Aイベント](final_usdjpy_2018/20261021_151444_6628351f/a_v140_full/events.csv) / [原本Bイベント](final_engineering/20261021_151408_14185e95/b_orders_smoke/events.csv)
