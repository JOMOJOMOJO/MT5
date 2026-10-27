# b_extension_on: MT5実測事例

時刻順とLONG/SHORT・成立/失効の被覆で抽出。損益は事例の選定に使用していない。

動画のチャート画像は未提供のため、動画との一致は未判定。以下はEAが実際に記録した判断根拠である。空欄・価格0は条件未成立等による未計算を含む。

| ID | 方向 | 候補認定 | W1終点位置 / 知り得た時刻 | 転換 / ライン既知時刻 | シグナル確定足時刻 | 結果 / 理由 |
|---|---|---|---|---|---|---|
| W33_XAUUSD+_5_1_LONG_1601543400_1 | LONG | 2020.10.01 09:15:00 | 2020.10.01 09:35:00 / 2020.10.01 09:50:00 | PIVOT_BREAK / 2020.10.01 09:55:00 | 2020.10.01 09:57:00 | CLOSED /  |
| W33_XAUUSD+_5_1_SHORT_1601547900_2 | SHORT | 2020.10.01 10:30:00 | 2020.10.01 10:40:00 / 2020.10.01 10:55:00 | PIVOT_BREAK / 2020.10.01 11:07:00 | 2020.10.01 11:09:00 | CLOSED /  |
| W33_XAUUSD+_5_1_LONG_1601553600_3 | LONG | 2020.10.01 12:05:00 |  /  |  /  |  | INVALIDATED / WAVE1_ORIGIN_BROKEN |
| W33_XAUUSD+_5_1_SHORT_1601559000_4 | SHORT | 2020.10.01 13:35:00 | 2020.10.01 13:45:00 / 2020.10.01 14:00:00 |  /  |  | INVALIDATED / WAVE1_ORIGIN_BROKEN |
| W33_XAUUSD+_5_1_LONG_1601561400_5 | LONG | 2020.10.01 14:15:00 | 2020.10.01 14:15:00 / 2020.10.01 14:30:00 |  /  |  | INVALIDATED / INITIAL_MOVE_MISSED |

## W33_XAUUSD+_5_1_LONG_1601543400_1

- 上位足の否定水準: 1894.6200000000。突破足 2020.10.01 09:10:00、確定 2020.10.01 09:15:00、EA認定 2020.10.01 09:15:00。根拠: 
- W1始点: 2020.10.01 08:55:00 @ 1892.3300000000、既知時刻 2020.10.01 09:10:00。W1終点: 2020.10.01 09:35:00 @ 1900.0200000000、固定を知り得た時刻 2020.10.01 09:50:00。
- Fib帯: 1897.0824200000 ～ 1895.2675800000。到達 あり、到達観測 2020.10.01 09:50:00。W2極値 2020.10.01 09:52:00 @ 1895.8800000000、既知時刻 2020.10.01 09:53:00、最終押し率 53.84%。
- 下位足確定ピボット時刻: 1601545320|1601545860|1601545500|1601545920。価格: 1898.1700000000|1897.0800000000|1896.1400000000|1895.8800000000。逆構造の確認時刻 2020.10.01 09:55:00。
- トリガー: PIVOT_BREAK @ 1897.0800000000、ライン既知 2020.10.01 09:55:00、検査足 2020.10.01 09:56:00。シグナル足の確定 2020.10.01 09:57:00、EAが知り得た実ティック 2020.10.01 09:57:00、注文送信 2020.10.01 09:57:00、約定 2020.10.01 09:57:00。
- ENTRY/SL/TP: 1897.2100000000 / 1895.4900000000 / 1898.9300000000。リスク幅 172.0000000000 points、目標 1.0000000000R。近隣水準 1900.0200000000 (PERIOD_M5)、既知 2020.10.01 09:50:00、余地 1.6337209302R、H1 H1_RANGE。
- 結果: CLOSED。見送り/失効理由 。最後のイベント COMPLETED: OBSERVATION / DEAL_REASON_TP。
- 描画: この事例のChartScreenShot保存なし。MT5ビジュアルモードで同じ日時・setup_idを照合する。
- ユーザーレビュー: 未判定（一致 / EAの認識遅れ・過剰判定 / 動画から判断不能）。

| EAが知り得た時刻 | イベント | 状態 | 計測/除外区分 | 判断根拠 |
|---|---|---|---|---|
| 2020.10.01 09:15:00 | WAVE1_BREAK | WAVE1_BREAK_CANDIDATE | OBSERVATION |  |
| 2020.10.01 09:50:00 | WAVE1_PEAK_CONFIRMED | WAVE1_TOP_TRACKING | OBSERVATION |  |
| 2020.10.01 09:50:00 | FIB_TOUCH | WAVE2_RETRACEMENT | OBSERVATION |  |
| 2020.10.01 09:55:00 | LOWER_STRUCTURE_CONFIRMED | LOWER_COUNTERTREND | OBSERVATION |  |
| 2020.10.01 09:57:00 | SIGNAL | LOWER_REVERSAL_TRIGGER | OBSERVATION |  |
| 2020.10.01 09:57:00 | RISK_CHECK | RESISTANCE_AND_RISK_CHECK | OBSERVATION | actual_rr=1.000000 |
| 2020.10.01 09:57:00 | ORDER | RESISTANCE_AND_RISK_CHECK | OBSERVATION | volume=0.29000000 risk_budget=50.00 |
| 2020.10.01 09:57:00 | FILL | POSITION_TRACKING | OBSERVATION | position filled |
| 2020.10.01 10:00:40 | EXIT | POSITION_TRACKING | OBSERVATION | DEAL_REASON_TP |

## W33_XAUUSD+_5_1_SHORT_1601547900_2

- 上位足の否定水準: 1895.8800000000。突破足 2020.10.01 10:25:00、確定 2020.10.01 10:30:00、EA認定 2020.10.01 10:30:00。根拠: 
- W1始点: 2020.10.01 10:05:00 @ 1900.3100000000、既知時刻 2020.10.01 10:20:00。W1終点: 2020.10.01 10:40:00 @ 1894.6300000000、固定を知り得た時刻 2020.10.01 10:55:00。
- Fib帯: 1896.7997600000 ～ 1898.1402400000。到達 あり、到達観測 2020.10.01 10:55:00。W2極値 2020.10.01 10:57:00 @ 1897.7100000000、既知時刻 2020.10.01 10:58:00、最終押し率 54.23%。
- 下位足確定ピボット時刻: 1601549820|1601550240。価格: 1897.7100000000|1895.8700000000。逆構造の確認時刻 2020.10.01 11:07:00。
- トリガー: PIVOT_BREAK @ 1895.8700000000、ライン既知 2020.10.01 11:07:00、検査足 2020.10.01 11:08:00。シグナル足の確定 2020.10.01 11:09:00、EAが知り得た実ティック 2020.10.01 11:09:00、注文送信 2020.10.01 11:09:00、約定 2020.10.01 11:09:00。
- ENTRY/SL/TP: 1895.6000000000 / 1898.0800000000 / 1893.1200000000。リスク幅 248.0000000000 points、目標 1.0000000000R。近隣水準 1895.5400000000 (PERIOD_M5)、既知 2020.10.01 08:10:00、余地 0.0241935484R、H1 H1_RANGE。
- 結果: CLOSED。見送り/失効理由 。最後のイベント COMPLETED: OBSERVATION / DEAL_REASON_SL。
- 描画: この事例のChartScreenShot保存なし。MT5ビジュアルモードで同じ日時・setup_idを照合する。
- ユーザーレビュー: 未判定（一致 / EAの認識遅れ・過剰判定 / 動画から判断不能）。

| EAが知り得た時刻 | イベント | 状態 | 計測/除外区分 | 判断根拠 |
|---|---|---|---|---|
| 2020.10.01 10:30:00 | WAVE1_BREAK | WAVE1_BREAK_CANDIDATE | OBSERVATION |  |
| 2020.10.01 10:55:00 | WAVE1_PEAK_CONFIRMED | WAVE1_TOP_TRACKING | OBSERVATION |  |
| 2020.10.01 10:55:00 | FIB_TOUCH | WAVE2_RETRACEMENT | OBSERVATION |  |
| 2020.10.01 10:57:00 | LOWER_STRUCTURE_CONFIRMED | LOWER_COUNTERTREND | OBSERVATION | SIMPLE_REACTION_BREAK |
| 2020.10.01 11:07:00 | LOWER_STRUCTURE_CONFIRMED | LOWER_COUNTERTREND | OBSERVATION | SIMPLE_REACTION_BREAK |
| 2020.10.01 11:09:00 | SIGNAL | LOWER_REVERSAL_TRIGGER | OBSERVATION |  |
| 2020.10.01 11:09:00 | RISK_CHECK | RESISTANCE_AND_RISK_CHECK | OBSERVATION | actual_rr=1.000000 |
| 2020.10.01 11:09:00 | ORDER | RESISTANCE_AND_RISK_CHECK | OBSERVATION | volume=0.20000000 risk_budget=50.48 |
| 2020.10.01 11:09:00 | FILL | POSITION_TRACKING | OBSERVATION | position filled |
| 2020.10.01 12:55:30 | EXIT | POSITION_TRACKING | OBSERVATION | DEAL_REASON_SL |

## W33_XAUUSD+_5_1_LONG_1601553600_3

- 上位足の否定水準: 1895.2800000000。突破足 2020.10.01 12:00:00、確定 2020.10.01 12:05:00、EA認定 2020.10.01 12:05:00。根拠: 
- W1始点: 2020.10.01 11:35:00 @ 1893.4100000000、既知時刻 2020.10.01 11:50:00。W1終点:  @ 0.0000000000、固定を知り得た時刻 。
- Fib帯: 0.0000000000 ～ 0.0000000000。到達 記録なし、到達観測 。W2極値  @ 0.0000000000、既知時刻 、最終押し率 0.00%。
- 下位足確定ピボット時刻: 。価格: 。逆構造の確認時刻 。
- トリガー:  @ 0.0000000000、ライン既知 、検査足 。シグナル足の確定 、EAが知り得た実ティック 、注文送信 、約定 。
- ENTRY/SL/TP: 0.0000000000 / 0.0000000000 / 0.0000000000。リスク幅 0.0000000000 points、目標 0.0000000000R。近隣水準 0.0000000000 (PERIOD_CURRENT)、既知 、余地 0.0000000000R、H1 H1_RANGE。
- 結果: INVALIDATED。見送り/失効理由 WAVE1_ORIGIN_BROKEN。最後のイベント INVALIDATE: EXCLUSION / WAVE1_ORIGIN_BROKEN。
- 描画: この事例のChartScreenShot保存なし。MT5ビジュアルモードで同じ日時・setup_idを照合する。
- ユーザーレビュー: 未判定（一致 / EAの認識遅れ・過剰判定 / 動画から判断不能）。

| EAが知り得た時刻 | イベント | 状態 | 計測/除外区分 | 判断根拠 |
|---|---|---|---|---|
| 2020.10.01 12:05:00 | WAVE1_BREAK | WAVE1_BREAK_CANDIDATE | OBSERVATION |  |
| 2020.10.01 12:30:00 | INVALIDATE | WAVE1_TOP_TRACKING | EXCLUSION | WAVE1_ORIGIN_BROKEN |

## W33_XAUUSD+_5_1_SHORT_1601559000_4

- 上位足の否定水準: 1896.7400000000。突破足 2020.10.01 13:30:00、確定 2020.10.01 13:35:00、EA認定 2020.10.01 13:35:00。根拠: 
- W1始点: 2020.10.01 12:55:00 @ 1898.3100000000、既知時刻 2020.10.01 13:10:00。W1終点: 2020.10.01 13:45:00 @ 1895.3400000000、固定を知り得た時刻 2020.10.01 14:00:00。
- Fib帯: 1896.4745400000 ～ 1897.1754600000。到達 あり、到達観測 2020.10.01 14:00:00。W2極値 2020.10.01 14:11:00 @ 1898.2200000000、既知時刻 2020.10.01 14:12:00、最終押し率 96.97%。
- 下位足確定ピボット時刻: 。価格: 。逆構造の確認時刻 。
- トリガー:  @ 0.0000000000、ライン既知 、検査足 。シグナル足の確定 、EAが知り得た実ティック 、注文送信 、約定 。
- ENTRY/SL/TP: 0.0000000000 / 0.0000000000 / 0.0000000000。リスク幅 0.0000000000 points、目標 0.0000000000R。近隣水準 0.0000000000 (PERIOD_CURRENT)、既知 、余地 0.0000000000R、H1 H1_RANGE。
- 結果: INVALIDATED。見送り/失効理由 WAVE1_ORIGIN_BROKEN。最後のイベント INVALIDATE: EXCLUSION / WAVE1_ORIGIN_BROKEN。
- 描画: この事例のChartScreenShot保存なし。MT5ビジュアルモードで同じ日時・setup_idを照合する。
- ユーザーレビュー: 未判定（一致 / EAの認識遅れ・過剰判定 / 動画から判断不能）。

| EAが知り得た時刻 | イベント | 状態 | 計測/除外区分 | 判断根拠 |
|---|---|---|---|---|
| 2020.10.01 13:35:00 | WAVE1_BREAK | WAVE1_BREAK_CANDIDATE | OBSERVATION |  |
| 2020.10.01 14:00:00 | WAVE1_PEAK_CONFIRMED | WAVE1_TOP_TRACKING | OBSERVATION |  |
| 2020.10.01 14:00:00 | FIB_TOUCH | WAVE2_RETRACEMENT | OBSERVATION |  |
| 2020.10.01 14:13:00 | INVALIDATE | WAVE2_RETRACEMENT | EXCLUSION | WAVE1_ORIGIN_BROKEN |

## W33_XAUUSD+_5_1_LONG_1601561400_5

- 上位足の否定水準: 1897.1000000000。突破足 2020.10.01 14:10:00、確定 2020.10.01 14:15:00、EA認定 2020.10.01 14:15:00。根拠: 
- W1始点: 2020.10.01 13:45:00 @ 1895.3400000000、既知時刻 2020.10.01 14:00:00。W1終点: 2020.10.01 14:15:00 @ 1899.8700000000、固定を知り得た時刻 2020.10.01 14:30:00。
- Fib帯: 1898.1395400000 ～ 1897.0704600000。到達 あり、到達観測 2020.10.01 14:30:00。W2極値 2020.10.01 14:27:00 @ 1897.1200000000、既知時刻 2020.10.01 14:30:00、最終押し率 60.71%。
- 下位足確定ピボット時刻: 。価格: 。逆構造の確認時刻 。
- トリガー:  @ 0.0000000000、ライン既知 、検査足 。シグナル足の確定 、EAが知り得た実ティック 、注文送信 、約定 。
- ENTRY/SL/TP: 0.0000000000 / 0.0000000000 / 0.0000000000。リスク幅 0.0000000000 points、目標 0.0000000000R。近隣水準 0.0000000000 (PERIOD_CURRENT)、既知 、余地 0.0000000000R、H1 H1_RANGE。
- 結果: INVALIDATED。見送り/失効理由 INITIAL_MOVE_MISSED。最後のイベント INVALIDATE: EXCLUSION / INITIAL_MOVE_MISSED。
- 描画: この事例のChartScreenShot保存なし。MT5ビジュアルモードで同じ日時・setup_idを照合する。
- ユーザーレビュー: 未判定（一致 / EAの認識遅れ・過剰判定 / 動画から判断不能）。

| EAが知り得た時刻 | イベント | 状態 | 計測/除外区分 | 判断根拠 |
|---|---|---|---|---|
| 2020.10.01 14:15:00 | WAVE1_BREAK | WAVE1_BREAK_CANDIDATE | OBSERVATION |  |
| 2020.10.01 14:30:00 | WAVE1_PEAK_CONFIRMED | WAVE1_TOP_TRACKING | OBSERVATION |  |
| 2020.10.01 14:30:00 | FIB_TOUCH | WAVE2_RETRACEMENT | OBSERVATION |  |
| 2020.10.01 14:35:00 | INVALIDATE | WAVE2_RETRACEMENT | EXCLUSION | INITIAL_MOVE_MISSED |

## 状態到達数（全候補）

| 状態 | 到達したsetup数 |
|---|---:|
| SEARCH_STRUCTURE | 0 |
| WAVE1_BREAK_CANDIDATE | 177 |
| WAVE1_TOP_TRACKING | 177 |
| WAVE2_RETRACEMENT | 154 |
| LOWER_COUNTERTREND | 117 |
| LOWER_REVERSAL_TRIGGER | 75 |
| RESISTANCE_AND_RISK_CHECK | 75 |
| POSITION_TRACKING | 52 |

SEARCH_STRUCTUREは候補発行前の待機状態のため、setup行に含まれない場合は0となる。発注OFFではPOSITION_TRACKINGは0。

## 実行時の仮定・設定

| 設定 | 値 |
|---|---|
| upper_tf | PERIOD_M5 |
| lower_tf | PERIOD_M1 |
| swing_left | 2 |
| swing_right | 2 |
| fib_min | 0.382 |
| fib_max | 0.618 |
| require_fib_touch | true |
| reject_deep_fib | false |
| timeout_upper_bars | 96 |
| trigger_mode | W33_PIVOT_BREAK |
| obstacle_mode | DISPLAY_ONLY |
| reward_r | 1.0 |
| risk_percent | 1.0 |
| tester_orders | true |
| tester | 1 |
| visual | 0 |
| terminal_build | 6230 |

MT5成績レポートの補助画像。EAの描画検証には数えない:

- [wave33_20261022_140527_f4364f5c_b_extension_on-holding.png](images/wave33_20261022_140527_f4364f5c_b_extension_on-holding.png)
- [wave33_20261022_140527_f4364f5c_b_extension_on-hst.png](images/wave33_20261022_140527_f4364f5c_b_extension_on-hst.png)
- [wave33_20261022_140527_f4364f5c_b_extension_on-mfemae.png](images/wave33_20261022_140527_f4364f5c_b_extension_on-mfemae.png)
- [wave33_20261022_140527_f4364f5c_b_extension_on.png](images/wave33_20261022_140527_f4364f5c_b_extension_on.png)
- [wave33_20261022_140527_f4364f5c_b_extension_on-holding.png](wave33_20261022_140527_f4364f5c_b_extension_on-holding.png)
- [wave33_20261022_140527_f4364f5c_b_extension_on-hst.png](wave33_20261022_140527_f4364f5c_b_extension_on-hst.png)
- [wave33_20261022_140527_f4364f5c_b_extension_on-mfemae.png](wave33_20261022_140527_f4364f5c_b_extension_on-mfemae.png)
- [wave33_20261022_140527_f4364f5c_b_extension_on.png](wave33_20261022_140527_f4364f5c_b_extension_on.png)

全候補: [candidate_index.csv](candidate_index.csv)。全イベント原本: [events.csv](events.csv)。追加の既知時刻列もCSVに保持。

自動監査: PASS。因果時刻・必須列・注文監査の違反 0件。動画との一致や利益性の合格を意味しない。
