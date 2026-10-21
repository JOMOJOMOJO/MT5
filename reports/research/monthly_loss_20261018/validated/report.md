# PF>1全条件の取引数・月次成績・負け方の診断

2026-10-18。新規フィルタを適用せず、既存の実行台帳と確定時点の環境を再集計。2024–25は探索済み、2026は不使用。

## 件数の意味

- PF>1の12会計シナリオの単純合計は **2,874取引**。
- 同じ条件のTP先着/SL先着重複を除くと **10条件・2,666取引**。両シナリオの候補ID集合が一致することを検証した。
- 同一通貨・方向・エントリー時刻のロジック間重複260組もまとめると **2,406時点**。時点が異なっても時間依存はあるため、独立標本数とはしない。
- 全10条件の元候補は2,845件。見送り・失効は[candidate_accounting.csv](candidate_accounting.csv)に保持。

これらは研究上の模擬約定件数。10口座の共通資金・同時建玉・相関を反映したポートフォリオ取引数ではない。全24か月に割ると月平均111.1件だがUSDCHFは後半17か月のみ。期間途中の対象追加を固定ポートフォリオの頻度と混同しない。

| method | n | winners | losers | flat |
| --- | --- | --- | --- | --- |
| ATR収縮ブレイク | 247 | 129 | 118 | 0 |
| ボリンジャー回帰 | 971 | 479 | 492 | 0 |
| ドンチャン | 1150 | 567 | 582 | 1 |
| 雲ブレイク | 298 | 145 | 153 | 0 |

4系統のうちATR収縮ブレイクはドンチャン条件の部分集合。ロジック名が違うだけで独立した機会にはならない。

## 条件別の月次実現損益

| symbol | method | side | n | data_months | mean_trades_per_available_month | pf | realized_positive_months | realized_negative_months | no_trade_months | TP_first_PF |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| AUDUSD | ボリンジャー回帰 | SHORT | 356 | 24 | 14.833 | 0.974 | 11 | 13 | 0 | 1.030 |
| AUDUSD | 雲ブレイク | SHORT | 298 | 24 | 12.417 | 0.947 | 12 | 12 | 0 | 1.044 |
| USDCHF | ATR収縮ブレイク | SHORT | 39 | 17 | 2.294 | 0.913 | 6 | 9 | 2 | 1.013 |
| USDCHF | ボリンジャー回帰 | SHORT | 261 | 17 | 15.353 | 0.932 | 7 | 10 | 0 | 1.018 |
| USDCHF | ドンチャン | SHORT | 273 | 17 | 16.059 | 0.972 | 7 | 10 | 0 | 1.019 |
| USDJPY | ATR収縮ブレイク | LONG | 142 | 24 | 5.917 | 1.066 | 12 | 12 | 0 | 1.165 |
| USDJPY | ATR収縮ブレイク | SHORT | 66 | 24 | 2.750 | 1.125 | 13 | 11 | 0 | 1.266 |
| USDJPY | ボリンジャー回帰 | LONG | 354 | 24 | 14.750 | 0.939 | 10 | 14 | 0 | 1.008 |
| USDJPY | ドンチャン | LONG | 488 | 24 | 20.333 | 0.957 | 13 | 11 | 0 | 1.026 |
| USDJPY | ドンチャン | SHORT | 389 | 24 | 16.208 | 0.930 | 11 | 13 | 0 | 1.002 |

全条件H1。PFと黒字/赤字月は主にSL先着の値、最後の列にTP先着PFを併記。8条件はTP先着だけPF>1なので、不利な順序での成績も表示して同足順序の都合よい選択を避ける。月は保存exit_timeの所属月。

USDCHFの2024年1〜7月は未取得であり、無取引ゼロ月にはしない。表の無取引月は履歴のある月の新規約定0件を数える。決済0件の月も別列に保存。利益/損失は既存spread/slippage/commission仮定控除後・実swap控除前。手数料0仮定の妥当性も未検証。

## 月末含み損益と最悪月

| symbol | method | side | realized_worst_month_usd | realized_longest_negative_months | equity_positive_months | equity_negative_months | equity_worst_month_usd | equity_longest_negative_months |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| AUDUSD | bollinger | SHORT | -139.140 | 4 | 11 | 13 | -139.140 | 4 |
| AUDUSD | ichimoku_cloud | SHORT | -77.070 | 4 | 12 | 12 | -81.270 | 4 |
| USDCHF | atr_breakout | SHORT | -27.898 | 5 | 6 | 9 | -27.898 | 5 |
| USDCHF | bollinger | SHORT | -38.897 | 7 | 7 | 10 | -38.401 | 7 |
| USDCHF | donchian | SHORT | -45.230 | 8 | 7 | 10 | -42.880 | 8 |
| USDJPY | atr_breakout | LONG | -29.555 | 5 | 12 | 12 | -29.555 | 5 |
| USDJPY | atr_breakout | SHORT | -28.657 | 5 | 13 | 11 | -28.657 | 5 |
| USDJPY | bollinger | LONG | -66.684 | 4 | 10 | 14 | -66.684 | 4 |
| USDJPY | donchian | LONG | -98.930 | 2 | 13 | 11 | -98.930 | 2 |
| USDJPY | donchian | SHORT | -105.706 | 4 | 11 | 13 | -105.706 | 4 |

決済損益とは別に、保存H1評価台帳の月末境界までの最終評価額の差を集計。境界時刻の足終値評価を含み、翌月始値のgap決済は含めない。境界を跨ぐ取引では決済月と評価月がずれることがある。価格を補間せず、持越し件数・評価の経過時間を[monthly.csv](monthly.csv)に併記。これはsource時計とbar spread proxyによる評価で、未検証の実swapを含まない。独立口座の損益を合算して運用成績とはしない。

## ロジック別の負け方

| method | loss_class | n | losing_cash_usd |
| --- | --- | --- | --- |
| atr_breakout | ambiguous_stop_loss | 6 | 55.229 |
| atr_breakout | stop_after_first_2_bars | 33 | 313.173 |
| atr_breakout | stop_within_first_2_bars | 78 | 733.599 |
| atr_breakout | time_exit_loss | 1 | 4.176 |
| bollinger | ambiguous_stop_loss | 17 | 154.642 |
| bollinger | stop_after_first_2_bars | 200 | 1855.244 |
| bollinger | stop_within_first_2_bars | 260 | 2405.693 |
| bollinger | time_exit_loss | 15 | 56.581 |
| donchian | ambiguous_stop_loss | 18 | 167.090 |
| donchian | stop_after_first_2_bars | 205 | 1861.194 |
| donchian | stop_within_first_2_bars | 346 | 3114.514 |
| donchian | time_exit_loss | 13 | 42.132 |
| ichimoku_cloud | ambiguous_stop_loss | 7 | 65.910 |
| ichimoku_cloud | stop_after_first_2_bars | 71 | 688.670 |
| ichimoku_cloud | stop_within_first_2_bars | 68 | 643.730 |
| ichimoku_cloud | time_exit_loss | 7 | 26.760 |

`stop_within_first_2_bars`はエントリー後1〜2実足の非曖昧SL損失、`stop_after_first_2_bars`は3本以上、`ambiguous_stop_loss`は同足TP/SL順序不明、`time_exit_loss`は固定10本時間決済での負け。これらは事後ラベル。エントリー時に将来のSL到達を知っていたことにはしない。

ドンチャンはブレイク後早期のSLと上位足方向、ボリンジャーは回帰せずトレンドが続く環境、雲ブレイクは抜けた後の失速、ATR収縮ブレイクは低頻度と他ロジック重複、という観点で次の仮説を整理できる。この文章は調べる仮説であり、損失原因の因果的な確定ではない。

## 事前情報による単独区分

H1方向一致/H4方向一致/既存相対ATR区分/雲位置の4軸で、SL先着の全110区分を保存。組合せ探索・閾値最適化は行わず、unknownも残した。H1自身は`trend`、上位足はavailabilityを検証したH4を使う。H1候補で未設定の`h1_trend`や`m15_trend`を誤って方向判定に使わない。

n>=100、活動週>=30、各年30件以上で両年損益負、という記述用フラグは13区分。そのうち除外後にも取引が残るものは12区分。これは多重比較補正を通った戦略や採択条件ではない。

[全区分と勝ちの取りこぼし](context_slices.csv) / [区分除外後の固定台帳月次](fixed_ledger_monthly_removals.csv)

各区分には、避けられる損失件数/金額だけでなく、失う勝ち件数/利益、残存取引数、無取引月、悪化する月を出した。**保存取引を除く計算は新しい売買ルールのバックテストではない。** 元候補から再実行すると、重複制限で見送られていた別候補の約定、lot、資金推移も変わる。

## 次の比較の作り方

負けを減らす研究に使える母数はある。月単位の安定性を重視するなら、ドンチャンとボリンジャーのように月約15〜20取引ある条件も調べる価値がある。ATR SHORT単独は月約2.8件なので、これだけで毎月安定を目指すには標本が薄い。

次の実験はこの記述診断から一つの事前条件だけを仮説化し、元候補全件を使ってフィルタなし/ありを同じ費用・出口で再生する。比較するのは勝率だけでなく、実費後期待値、黒字月率、最悪月、連続赤字月、月末含み損、残存件数と見送った勝ち。2024–25内の時系列分割は探索用であり、独立OOSとは呼ばない。2026の探索除外を維持する。

毎月黒字を保証したり、過去の赤字月を見て月ごとのルールを選び直したりしない。条件を足した後に件数がほぼ消える場合も改善扱いにしない。最終的な併用は、各条件の固定検証後に共通資金・相関を含む別のポートフォリオ評価で行う。

## 再現性

[固定計画](../../../../knowledge/experiments/2026-10-18-monthly-loss-diagnosis-plan.md) / [manifest](manifest.json) / [検算](qa.json) / [月別チャート](dashboard.html)。旧EA・価格・候補・結果を変更しない。入力/ソース/出力SHA、元候補数、両順序の対応、全20口座の通期損益と月別合計を確認。
