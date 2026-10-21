# 一目均衡表の追加観測：事前固定計画

## 目的と固定条件

前回M5候補の成績と、一目均衡表で表現した上位足環境の関係を調べる。
ユーザーの「試してみて」は診断追加の依頼として扱い、売買フィルター・新しい一目EAへ切り替えない。
既存M15/H1/H4のダウ分類を残す。Entry、SL2.2ATR、TP1.5R、risk0.65%、spread0.20ATR、保有18M5本など全inputを維持。
設定探索・可変RR・条件採用なし。本番EA/Sharedは変更しない。

## 観測定義

M15/H1/H4それぞれ9/26/52、シフト26本を固定。
足を古い順の配列とし、現在の足をq、最新確定足をj=q−1とする。

- 転換線：jまで9本の最高値/最安値の中間。
- 基準線：jまで26本の中間。傾きはjとj−3の基準線の差の符号。
- **現在位置に表示される雲**：q−26時点で計算した先行スパンA/B。最新計算値を現在の雲として扱わない。
- A：q−26までの転換線/基準線の中間。B：q−26まで52本の高安中間。
- 雲位置：候補Ask/実約定価格が雲の上ABOVE、中INSIDE、下BELOW。境界同値はINSIDE。
- 雲方向：A>B UP、A<B DOWN、同値FLAT。
- 転換線/基準線の上下、基準線傾き：UP/DOWN/FLAT。
- 遅行関係：jの確定終値とj−26の高安を比較してABOVE/INSIDE/BELOW。過去位置に描かれた未来終値を読む方式は禁止。
- 雲厚、価格−雲上下端、価格−基準線を元の予定SL幅Rで正規化。負距離も保持。

 forming barの高安終値を計算しない。現在足の開始時刻は雲の表示位置を指定するためだけに使用する。
26本は実際のバー数で数え、週末を含む経過秒数26本分で代用しない。
計算対象80本の確定OHLCと各close_time、cloud_source_bar/close、asof、decision時刻をCSV保存。
履歴不足はUNKNOWNとして残し、Entryを除外しない。

公式仕様：[MT5 Ichimoku](https://www.metatrader5.com/en/terminal/help/indicators/trend_indicators/ikh)、[MQL5 iIchimoku](https://www.mql5.com/en/docs/indicators/iichimoku)。
表示シフトの誤解を避けるため、記録は閉じたOHLCから直接計算し、Pythonで別途再計算・照合する。

## 期間・比較対象

1. M5短期2026年9月：前回と売買・全候補・shadow pathが同じことを監査。
2. 2023–2024：前回と同じ946候補/157実取引が期待される。
3. 2025–2026年9月：前回と同じ720候補/60実取引が期待される。

短期controlを本集計に混ぜない。過去に見た期間でありOOSと呼ばない。
実測が異なる場合は停止して原因を確認する。利益改善の証拠として採用しない。

## 事前固定した集計

- 全raw候補shadowと、実取引を別々に集計。
- TFごとの雲位置、雲方向、転換/基準、基準線傾き、遅行関係を個別に集計し、年別・件数・勝率・平均R・PFを比較。
- 雲位置×既存spread/ATR binのみ追加。時間帯や3TFのAND探索は行わない。
- 連続特徴値は全候補CSVへ保存し、今回は最適binや閾値を探さない。
- 月別実行数は既存CSVを保持。環境で取引を増減させないので、全体頻度は前回と同じになるはず。
- 30件未満をsmall_sampleとして表示。30件以上でも独立標本・再現性を保証しない。

生成tick混在、shadowの1分両側到達除外、時間決済、commission/swap未反映などは前回定義のまま。

## 監査と出力

全候補・全実Entryについて、保存OHLCからPython再計算しMQL値と照合。
future barを極端な価格へ変えても値が不変であること、全利用close_time<=decision<=Entryを検査。
一目追加前後の実取引・全候補・価格pathを完全比較し、不一致はバッチ停止。

- 各run：ichi.csv / ichi_bars.csv / ichimoku_audit.json
- 全体：candidates_with_ichimoku.csv / trades_with_ichimoku.csv
- ichimoku_shadow_statistics.csv / ichimoku_actual_statistics.csv / ichimoku_summary.md
- 既存のcontext/path/月別/損益ファイルも保持。

独立portable MT5を非同期起動後、待機せずターン終了。ユーザーの完了通知後に成績をレビューする。
