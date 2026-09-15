# 4か月学習／後続期間検証：データ受付QA

2026-09-10。判定：**BLOCKED_RUN_INTEGRITY**。モデル学習・選定・5～6月の損益集計は未実施。

追記：追加監査で**実際は生成ティックモード**と確認した。最新判定は[追加監査](provenance_audit/report.md)の`BLOCKED_WRONG_TICK_MODEL`。本受付QAの数値・当時の未解決事項は履歴として残す。

## 確認済み

| 項目 | 結果 |
|---|---:|
| Technical episodes | 17,648 |
| 特徴量 | 486 |
| LONG/SHORT × 6距離のoutcome行 | 211,776 |
| episodeに紐づくmarket clusters | 17,020 |
| 1～4月のepisode | 12,823 |
| 5～6月のepisode | 4,825 |
| 最初のepisode（brokerの符号化された日時） | 2025-01-02 03:13:51 |
| 最後のepisode | 2025-06-27 23:01:16.500 |
| QA | 34 PASS / 2 FAIL |

1月2,696件、2月2,155件、3月3,319件、4月4,653件、5月2,322件、6月2,503件。
これらは取引件数ではない。211,776行も独立取引数ではない。
元データのSHAは読み取り前後で一致。候補モデルの損益は評価していない。

## 機械的QAの結果

episode/outcomeの重複0、1 episodeあたり12 outcome、欠落結合0。
feature sourceがt0より未来の件数0、entry before processing/eligible 0、entryがt0/source quote以前の件数0、exit before entry 0。
entry Bid/Ask側、TP/SL対称距離、3spread guardの違反0。
medium_horizon_episode_summaryの17,648 episodeとTechnical特徴量のepisode集合は完全一致。
学習境界を跨ぐmarket cluster数0。ただし将来の学習処理ではlabel終了のpurgeが別途必要。

## 正常終了と異常判定は別

Tester journalに2025.06.27 23:56:59の終了処理がある。
Technical：episodes=17648、censored=5、capacity=0、feature_invalid=0。
Candidate：signals=17648、closed=1432、errors=0、remaining_positions=0。
Tester実行時間：5:27:26.570。全通貨tick：90,805,245。メモリ：2,269MB。
Technical側のorders=0というログはobserverだけの情報であり、Candidate全体が注文0だったという意味ではない。

Technicalのcensored=5は終了時のobserver record打切り件数。CSVの取引status=CENSOREDは0行。
両者は同じ指標ではなく、最大900秒の経路特徴の観測完了と取引決済完了を混同しない。

## 2 FAILの根拠

run summaryのINTEGRITY/fail_closed：

- validation=VALIDATION_INVALID
- ever_failure=true
- event_pool_exhaustions=15097
- pending_capacity_hits=0 / dropped_ticks=0 / cursor_stalls=0
- incomplete_frontier_instances=1 / read_failures=4
- 最終incomplete_frontier=false

FAILはrun validationと旧event pool exhaustion。Technicalの各行の因果性が15,097件破られたという意味ではない。

### ソース上のスコープ分離

`mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5:2775`では、先に`TSRV1RegisterStatisticalTrack`、その後で旧strategy条件を満たす場合に`TSRV1RegisterCandidateEvent`を呼ぶ。
`TSRV1RegisterStatisticalTrack`内の2472行でTechnical observerがarmされる。
旧candidate event poolの失敗は2562～2566行で発生する。
`mql/Include/TickShock/TickShockEventEngine.mqh:105`がpool exhaustionをカウントし、run validation invalidを立てる。

従って、旧poolの15,097回の失敗を、そのままTechnical episode欠落15,097件とは解釈できない。
summaryのSTATISTICAL_CLUSTER/countsはtrack_capacity_hits=0、Technical専用poolもcapacity=0。
これらは今回の主要CSVを救済できる可能性を支持するが、run全体のfail-closed判定を無条件に取り消す根拠にはしない。
read_failures=4と途中のfrontier不完全1回がどの範囲へ影響したか、および生成fallbackの詳細は未解決。

## 未解決の来歴

- 実際のtester設定/期間と完全な実行ログの対応づけ。入力metadataのperiod末尾には再実行番号`-2`が付いている。
- metadataはBybit-Live/build6182。過去Vantage4月結果と同じデータ条件ではない。
- metadata記載EX5 hashは旧Candidateと一致する文字列だが、今回実行時のEX5自体との照合は未完了。
- 2つのTechnical includeはworktreeで削除状態。Git HEAD参照は可能だが原位置を復元していない。
- 六通貨のcommissionはこのQAで未観測。旧commission説明ラベルを今回の実測とみなさない。
- 2025年5～6月の未使用性は、ユーザー/Claude側の別分析履歴も含めて確認が必要。

## 次の判断

元データは削除・再取得せず保持する。
正式な4m/2m検証には、失敗範囲とTechnical populationの独立性の追加監査、または収集器修復後の再収集が必要。
現在記録されている行だけを使った**参考分析**は別の選択肢だが、run全体の検証合格やproduction-readyとは扱えない。
このQAでは例外採用や不具合修正を自動的に行わず、学習・holdout損益評価前で停止した。

## 再現コマンド

リポジトリrootから。出力先は新規ディレクトリを指定する。

```powershell
python tools/tick_shock/audit_technical_4m2m_input.py --input C:\Users\windows\AppData\Roaming\MetaQuotes\Terminal\Common\Files\tstech_candidate_202501to06-2 --output reports/analysis/tick_shock/technical_4m2m_codex_replay --journal C:\Users\windows\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\Tester\logs\20260910.log
```

関連：`qa_checks.csv`、`input_hashes.csv`、`monthly_population.csv`、`monthly_symbol_population.csv`、`run_integrity.csv`、`journal_end_evidence.csv`、`intake_summary.json`。
