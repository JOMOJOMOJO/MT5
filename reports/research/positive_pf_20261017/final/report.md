# PFが1を超えた条件の追加検証

2026-10-17。ルールと既存データを変えずに、保存台帳を再集計した探索的な追加監査。2026年の価格は不使用。

**USDJPY H1 ATR収縮ブレイクは両方向ともSL先着扱いでPF>1。SHORTは2024/2025の両年で正、LONGは2024が負。ただし平均Rの未補正95%区間は0を含み、現時点で正の期待値を確認したとは言えない。**

## 観測事実

全432口座シナリオ中PF>1は12件、実質10条件。すべてH1。12件とも口座の途中打切りなし。ただしUSDCHFは17か月のみ。SL先着でもPF>1なのは今回の2方向だけ。

| side | n_candidates | n_closed | pf | pnl_usd | mean_r | mean_pnl_usd | n_ambiguous |
| --- | --- | --- | --- | --- | --- | --- | --- |
| LONG | 156 | 142 | 1.0665 | 42.5551 | 0.0370 | 0.2997 | 3 |
| SHORT | 68 | 66 | 1.1247 | 35.3672 | 0.0507 | 0.5359 | 2 |

損益はUSD10000開始・1回0.1%リスクの各独立口座。スプレッドproxy、片道0.2pipsの仮定スリップ、手数料0仮定を含む。**実swap控除前**であり、完全なネット利益ではない。LONG/SHORTの合算をポートフォリオ成績とみなさない。

候補の残りはLONGが重複見送り14件、SHORTが重複1件・失効1件。[元候補の会計](event_accounting.csv)に全件数を残した。

## 年別の違い

| side | year | n_closed | pf | pnl_usd | mean_r |
| --- | --- | --- | --- | --- | --- |
| LONG | 2024 | 90 | 0.9400 | -26.0840 | -0.0228 |
| LONG | 2025 | 52 | 1.3343 | 68.6391 | 0.1404 |
| SHORT | 2024 | 36 | 1.1067 | 16.5576 | 0.0456 |
| SHORT | 2025 | 30 | 1.1465 | 18.8096 | 0.0568 |

保存時刻の決済年で区分。LONGの通期プラスは年別に一貫しない。SHORTは両年プラスだが36件と30件だけで、独立した十分な再現性検証とは言えない。月別は[monthly.csv](monthly.csv)。実際のブローカーtimezoneを確認済みとはしていない。

## 不確実性

| side | n_closed | active_entry_weeks | mean_r | mean_r_ci_low | mean_r_ci_high | pf_ci_low | pf_ci_high | centered_one_sided_p | account_family_bonferroni_432 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| LONG | 142 | 54 | 0.0370 | -0.0900 | 0.1698 | 0.8225 | 1.4037 | 0.2928 | 1.0000 |
| SHORT | 66 | 44 | 0.0507 | -0.1711 | 0.2651 | 0.7133 | 1.7667 | 0.3219 | 1.0000 |

2024–25の105カレンダー週には無取引週を含め、取引全体をエントリー週へ帰属。主は4週の循環移動ブロック、20,000反復、seed=20261017。PF/平均Rは保存取引の再標本化で、lotや資金管理を再実行した成績分布ではない。1週・8週の感度も固定して全件保存した。[bootstrap.csv](bootstrap.csv)

CIは未補正の記述的95%区間。正の平均Rに対する中心化片側pは近似値で、432口座の選別に対するBonferroniも併記。循環接続、有限ブロック、相場の非定常性の制約があり、週数を独立標本数とは扱わない。それ以前のすべての探索まで補正したという意味ではない。2つの同足シナリオも独立標本ではない。

## 追加コストに残された余裕

| side | extra_roundtrip_pips_to_zero | extra_roundtrip_usd_per_lot_to_zero | n_source_day_crossing | lot_source_day_exposure |
| --- | --- | --- | --- | --- |
| LONG | 0.5259 | 3.4458 | 13 | 1.4900 |
| SHORT | 1.0708 | 7.1449 | 3 | 0.1900 |

上の水準は**既に差し引いたコストへの追加分**。pipsは保存exit換算率による会計負担、USD/lotは往復追加手数料。それぞれを単独加算した損益ゼロ点であり、実際のブローカー費用の見積りではない。日跨ぎ曝露はsource時計基準で、真のrolloverや三倍swap日数ではない。実swapを仮定で埋めない。

保存した同じ約定・lotへの費用感度なので、スプレッドや滑りが変わった場合のSL/TP順序、エントリー可否、lot変化を再現しない。[cost_sensitivity.csv](cost_sensitivity.csv)には事前に固定した全水準を出力した。

## 同足内の順序をM1で照合

| side | entry_source_time | expected_m1 | actual_m1 | h1_bid_ohlc_match | first | first_source_minute |
| --- | --- | --- | --- | --- | --- | --- |
| LONG | 2024-04-10 12:00 | 240 | 240 | True | stop_first | 2024-04-10 15:23 |
| LONG | 2024-06-20 08:00 | 180 | 180 | True | stop_first | 2024-06-20 10:30 |
| LONG | 2025-07-15 15:00 | 60 | 60 | True | stop_first | 2025-07-15 15:30 |
| SHORT | 2024-07-11 16:00 | 60 | 60 | True | target_first | 2024-07-11 16:01 |
| SHORT | 2025-04-21 01:00 | 60 | 60 | True | stop_first | 2025-04-21 01:00 |

エントリーから対象H1足末までのM1が連続し、時間ごとのBid OHLCもH1と一致。LONG3件はSL先着、SHORT2件はTP先着とSL先着が1件ずつ。同一M1足内両到達はなかった。SHORTはH1固定spreadとM1別spreadのAsk proxyで結論が一致した。

M1はティック列・実際のAskではないため、厳密な約定順や価格の検証完了とはしない。今回、この判定を使って元口座の損益を差し替えていない。[intrabar.csv](intrabar.csv)

## 利益集中の感度

| side | sensitivity | removed_month | removed_n | n_closed | pf | pnl_usd |
| --- | --- | --- | --- | --- | --- | --- |
| LONG | remove_best_exit_month | 2024-06 | 12 | 130 | 1.0127 | 7.6224 |
| LONG | remove_top_3_winners |  | 3 | 139 | 1.0208 | 13.3120 |
| LONG | remove_top_5_winners |  | 5 | 137 | 0.9905 | -6.0831 |
| SHORT | remove_best_exit_month | 2024-02 | 7 | 59 | 1.0287 | 7.6172 |
| SHORT | remove_top_3_winners |  | 3 | 63 | 1.0220 | 6.2456 |
| SHORT | remove_top_5_winners |  | 5 | 61 | 0.9543 | -12.9694 |

最高利益月を除いても両者はわずかにプラスだが、上位5勝を除けばPF<1。固定1ATR利確では勝ち額が近いため、「例外的な大勝ちだけに依存」とは断定しない。これは利益の余裕の参考検査であり、事後除外した新戦略や条件選別ではない。

## PF>1だった全条件の対照

| symbol | timeframe | method | side | stop_first_lower | target_first_upper |
| --- | --- | --- | --- | --- | --- |
| AUDUSD | H1 | bollinger | SHORT | 0.9738 | 1.0297 |
| AUDUSD | H1 | ichimoku_cloud | SHORT | 0.9473 | 1.0444 |
| USDCHF | H1 | atr_breakout | SHORT | 0.9127 | 1.0125 |
| USDCHF | H1 | bollinger | SHORT | 0.9319 | 1.0175 |
| USDCHF | H1 | donchian | SHORT | 0.9723 | 1.0192 |
| USDJPY | H1 | atr_breakout | LONG | 1.0665 | 1.1649 |
| USDJPY | H1 | atr_breakout | SHORT | 1.1247 | 1.2660 |
| USDJPY | H1 | bollinger | LONG | 0.9387 | 1.0081 |
| USDJPY | H1 | donchian | LONG | 0.9571 | 1.0262 |
| USDJPY | H1 | donchian | SHORT | 0.9301 | 1.0017 |

その他8条件はTP先着扱いの場合だけPF>1。両シナリオは同足順序の仮定であり、lot丸め・資金推移もあるため数学的な全体上下限と断定しない。

## 判断と次の検証

確認できたことは「SL先着でも利益が残る2条件があり、SHORTは両年プラス」という点。仮説として、低ボラティリティ後の下方向ブレイクは固定検証を続ける候補になる。ただし少数標本、未補正CIの0跨ぎ、探索済み2024–25、実swap・Ask・tick・歴史仕様未確認が残る。

以前のStage1イベント統計（固定H10・ランダム対照・648検定）に合格した結果ではない。今回の1ATR TP/SL付き口座PFと混同せず、[元のイベント統計](previous_event_statistics.csv)も保存した。Stage1/2の固定基準を緩めず、**運用採択はしない**。

次の対象を絞るならSHORTの同一ルールを固定し、実ティック・実コスト照合と、ルール凍結後の未使用期間を検証する。LONGは年別不安定も残る。SHORTへフィルターを追加したり、TP/SLやリスクを変えて今回の結果を救済しない。2026の探索除外は維持する。この追加監査は完了しており、実ティック・将来期間の検証を実施済みとは扱わない。

## 再現性と証拠

[全概要CSV](summary.csv) / [ダッシュボード](dashboard.html) / [manifest](manifest.json) / [検算](qa.json) / [固定計画](../../../knowledge/experiments/2026-10-17-positive-pf-followup-plan.md)

元台帳・価格・元コードのSHA256を検証。旧結果・EA・元データは変更しない。新規ソースはmanifestにSHAを保存。全表はCSVとParquet、DuckDBに保存した。
