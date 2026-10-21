# 出力の読み方

## 固定条件

USDJPY、M1/M5、M1 pivot左1/右3、M5左1/右1、親終値pivot、CHoCH入口（SkipLowerHL=true）、SLは親起点価格−10ポイント、EMA OFF。M15分類は別定義のヒゲpivot左2/右2。価格損益をRで比較する研究であり、売買用EAの口座損益レポートではない。

## 集計CSV（analysis/）

| ファイル | 内容 |
|---|---|
| candidates_with_phase.csv | 候補1件1行。run+idがキー。phaseはEntry時点のM15状態。M5/M1/M15の価格・足時刻・確定時刻を保持 |
| all_rr_outcomes.csv | 同じ候補に4つの固定RR。run+id+rrがキー。Entry/SLは共通 |
| phase_statistics.csv | 候補全体（CANDIDATES）と制約下の実行分（UNFILTERED_ACCEPTED）を分離した状態別成績 |
| monthly_capacity.csv | 各月の候補数と実行可能数。UNFILTEREDは元戦略、PHASE_ONLY_CAPACITYは該当状態だけ使う仮想頻度 |
| execution_ledger.csv | RRごとのACCEPT / POSITION_OPEN / COOLDOWN / PARENT_ALREADY_USED / OTHER_PHASE。候補表へrun+idで結合 |
| paired_rr_comparison.csv | 同一候補でRR1との差、RR1では勝つが大きいTPでは負ける件数 |
| resistance_features.csv | H1/H4の通常2/2・主要5/5高値、確定時刻、距離R。主要高値は機械的な代理定義 |
| resistance_diagnostics.csv | 上値余地1.2R以上／未満／欠損の事前固定区分。採用フィルターではない |

全時刻はMT5サーバーの時刻軸。epoch値から表示しておりUTCや日本時間へ変換していない。フェーズのasofは最後に利用した確定M15足の終了時刻。

## 指標と制約

- 1R = Entry Ask − SL。SL割れは観測Bid、TPは指定水準で計算。スプレッドを含むが手数料・swap・遅延・口座通貨換算・ロット／証拠金制約を含まない。
- PFは正のR合計／負のR合計絶対値。損失0件の場合は空欄。口座の金額PFではない。
- 実行可能数は1ポジション、約定から15分クールタイム、同じ親構造1回。RRごとに占有期間が変わるため独立再生する。
- 未決済END_CENSOREDは勝敗・期待値の分母から除外し、件数を残す。後続候補の実行判定では保有継続とする。
- mfe_to_exit / mae_to_exitはそのRRの決済まで。別のmfe_until_sl_or_24h / mae_until_sl_or_24hはTPを置かずSLまたは24時間まで観測。到達率は後者の完了窓だけが分母。
- mean_r_iid_ciは固定seedの候補単位bootstrap。時系列相関を考慮しない参考区間で、少数標本の優位性証明ではない。
- 抵抗が800本内に見つからない場合は欠損。上値余地無限大とは扱わない。
- RANGE_UNKNOWNは非トレンドを保証せず、構造未成立・終了・否定後も含む。WAVE3_UPは突破後の最初の確定高値で終了する有限の波フェーズ。

## 再集計

```powershell
python tools/swing_structure/analyze_m15_phase_research.py known_close_2025h1 holdout_close_2024q3
python tools/swing_structure/audit_m15_phase_replay.py known_close_2025h1 holdout_close_2024q3
python tools/swing_structure/analyze_m15_phase_research.py known_close_2025h1 holdout_close_2024q3 --charts
```

`analysis/`は指定した期間だけで上書き集計する。旧smokeは混ぜない。期間別の元CSVとtester.logはそれぞれの実行フォルダに保存している。
