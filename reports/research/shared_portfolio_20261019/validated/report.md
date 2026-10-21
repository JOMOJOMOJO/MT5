# 固定4条件・共有資金の検証

2026-10-19。ルール、配分、出口、暦休止を変更せず、候補全集合から共通口座を時系列再生した。

**主評価：475取引、PF 1.1847、含み損益込み黒字11/17月。** 総損益363.15USD、初期40,000USDに対し0.908%。完結=True。

## 固定条件

USDJPY Donchian LONG応用、USDJPY ATR SHORT応用、USDCHF Donchian SHORT応用、AUDUSD RSI2 SHORT。同時刻はこの順。全体40,000USD、均等25%リスク配分、各配分の0.1%=全体equityの0.025%/取引。当初10USDで、前回の4独立口座に比べ資金・1取引リスクを増やしていない。

各ルール1建玉、全体4建玉。予定初期SLリスク合計は全体equity0.1%、同一symbol0.05%以内で注文受付。日次3%減少・観測peakから5%減少で新規停止。既存建玉は元の出口を維持するため、これらはギャップを含む損失保証上限や足内即時kill-switchではない。

TP/SL各1ATR、最大10実足。主評価SL先着、TP先着を感度として全件保存。基準slippage片道0.2pip、ストレス0.7pip。spreadはbar proxy、commission0仮定、swap未知。

前足内決済→当足ギャップ決済→現在始値による評価→固定順新規の順序。数量計算・受付に現在足の高安終値や将来の決済結果を使わない。各候補の価格・約定経路は凍結エンジンから取得し、到来した時刻のmarkだけを共通口座へ反映。

## 共通17か月の主順序比較

| mode | cost | account_path_complete | n_closed | profit_factor | net_pnl_before_unknown_swap_usd | net_return_pct | monthly_positive | available_months | longest_negative_months | median_entries_per_month | max_drawdown_close_pct | max_drawdown_adverse_envelope_pct | max_simultaneous_positions | peak_margin_used_usd |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| hedging | base | True | 475 | 1.185 | 363.154 | 0.908 | 11 | 17 | 2 | 28.000 | 0.357 | 0.379 | 2 | 633.333 |
| hedging | stress | True | 476 | 1.060 | 121.413 | 0.304 | 10 | 17 | 3 | 28.000 | 0.397 | 0.412 | 2 | 600.000 |
| block_opposite | base | True | 475 | 1.185 | 363.154 | 0.908 | 11 | 17 | 2 | 28.000 | 0.357 | 0.379 | 2 | 633.333 |
| block_opposite | stress | True | 476 | 1.060 | 121.413 | 0.304 | 10 | 17 | 3 | 28.000 | 0.397 | 0.412 | 2 | 600.000 |

max_drawdown_close_pctは足終値だけでなく、観測した始値・新規約定・決済時点を含む評価DD。adverse_envelopeは通貨ごとの足内高安が同時に起きたと限らない保守的包絡DDで、実tick最大DDではない。

## 同じ開始日にリセットした独立口座との比較

比較対象も各10,000USDで開始し直し、同じ候補・暦休止・費用・順序・期間を使用。過去の利益による初期lot差と共有資金の影響を混同しない。共有口座と同じ資金総額40,000USD。

| period | cost | n_closed_shared | n_closed_independent | profit_factor_shared | profit_factor_independent | trade_difference | cash_difference_usd |
| --- | --- | --- | --- | --- | --- | --- | --- |
| common | base | 475 | 475 | 1.185 | 1.179 | 0 | 9.408 |
| common | stress | 476 | 476 | 1.060 | 1.060 | 0 | 0.920 |
| mixed_reference | base | 656 | 656 | 1.116 | 1.113 | 0 | 6.804 |
| mixed_reference | stress | 658 | 658 | 0.973 | 0.973 | 0 | -2.123 |

## 全16シナリオ

| period | mode | cost | scenario | account_path_complete | n_closed | profit_factor | net_pnl_before_unknown_swap_usd | monthly_positive | available_months | max_drawdown_close_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| common | hedging | base | stop_first_lower | True | 475 | 1.185 | 363.154 | 11 | 17 | 0.357 |
| common | hedging | base | target_first_upper | True | 475 | 1.236 | 453.059 | 12 | 17 | 0.275 |
| common | hedging | stress | stop_first_lower | True | 476 | 1.060 | 121.413 | 10 | 17 | 0.397 |
| common | hedging | stress | target_first_upper | True | 476 | 1.094 | 185.831 | 11 | 17 | 0.316 |
| common | block_opposite | base | stop_first_lower | True | 475 | 1.185 | 363.154 | 11 | 17 | 0.357 |
| common | block_opposite | base | target_first_upper | True | 475 | 1.236 | 453.059 | 12 | 17 | 0.275 |
| common | block_opposite | stress | stop_first_lower | True | 476 | 1.060 | 121.413 | 10 | 17 | 0.397 |
| common | block_opposite | stress | target_first_upper | True | 476 | 1.094 | 185.831 | 11 | 17 | 0.316 |
| mixed_reference | hedging | base | stop_first_lower | True | 656 | 1.116 | 325.645 | 14 | 24 | 0.358 |
| mixed_reference | hedging | base | target_first_upper | True | 656 | 1.177 | 483.775 | 16 | 24 | 0.275 |
| mixed_reference | hedging | stress | stop_first_lower | True | 658 | 0.973 | -79.146 | 12 | 24 | 0.714 |
| mixed_reference | hedging | stress | target_first_upper | True | 658 | 1.015 | 42.423 | 13 | 24 | 0.553 |
| mixed_reference | block_opposite | base | stop_first_lower | True | 656 | 1.116 | 325.645 | 14 | 24 | 0.358 |
| mixed_reference | block_opposite | base | target_first_upper | True | 656 | 1.177 | 483.775 | 16 | 24 | 0.275 |
| mixed_reference | block_opposite | stress | stop_first_lower | True | 658 | 0.973 | -79.146 | 12 | 24 | 0.714 |
| mixed_reference | block_opposite | stress | target_first_upper | True | 658 | 1.015 | 42.423 | 13 | 24 | 0.553 |

mixed_referenceは2024年1月開始で、USDCHF未取得1〜7月は当該配分を使えず他へ再配分しない。4戦略が全て利用できた2年として扱わない。commonは2024年8月1日08時からflatで開始。最初の8時間未取得とUSDCHF指標準備期間を含むので、8月を完全取得月とは称さない。

## 不確実性と実行上の制約

主評価の平均取引Rは0.0850、暦4週ブロック5,000回の95%区間[0.0019, 0.1687]。4条件は過去の結果を見て選択済みで、この区間も選択偏りを解消しない。期間・mode・費用・順序は感度比較で、最良profileを選ぶ最適化ではない。

hedgingを主仮定とし、block_oppositeは同じsymbolの逆方向注文を拒否する。実口座がnettingなら、反対売買による相殺・部分決済を別に実装検証する必要がある。証拠金はレバレッジ1:30、両建て減免なし。USDJPY/USDCHFはUSDベース額、AUDUSDは当時midで換算する。ブローカーの歴史的証拠金・mode・stopoutの再現ではない。[MT5公式の証拠金計算](https://www.metatrader5.com/en/terminal/help/trading_advanced/margin_forex)。

予定SL損失は損失保証上限ではなく、4条件すべてUSDに関係する。通貨集中も別に保存した。新規受付時のmarginとリスクは検査するが、未知swap・commission・歴史的仕様・source時計を推測で補っていない。欠損で共通口座が止まれば、その後の月次をゼロとせず未完了とする。

## 結果の扱い

共有口座への統合は、既存の入口の期待値を増やす操作ではない。月次の補完、資金効率、建玉競合を確認する工程である。実際の黒字月数・赤字月数を上表の通り報告し、「ほぼ毎月黒字」や実運用への昇格とは判断しない。損失月だけを除外したり、好成績のprofileへ配分を変えたりしない。

## 成果物

[ダッシュボード](dashboard.html)、[全シナリオCSV](summary.csv)、[月次CSV](monthly.csv)、[年次CSV](yearly.csv)、[注文処理CSV](events.csv)、[取引CSV](trades.csv)、[独立口座比較CSV](reference_comparison.csv)。同名ParquetとDuckDBを保存。

profiles/に各口座の約定・注文処理・equityを保存。manifest.jsonに固定条件・入力/凍結実装SHA・新コード版・依存版を保存。READMEとテストはtools/entry_research/shared_portfolio/。
