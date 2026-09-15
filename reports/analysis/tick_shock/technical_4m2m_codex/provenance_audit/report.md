# 追加監査：半年CSVの生成モードと異常の影響範囲

2026-09-10。最終判定：**BLOCKED_WRONG_TICK_MODEL**。
学習・5～6月の損益評価・MQL変更・MT5再実行は未実施。

## 決定的な確認事項

実際のAgent journalで対象RunIdを一意に特定し、その直前の同じrun開始行を確認した。

`20260909.log:2584`:

```text
EURUSD,M1 (Bybit-Live): every tick generating
```

`20260909.log:2585`:

```text
testing with execution delay 6 milliseconds
```

`20260909.log:2586`は、TechnicalCandidateを2025.01.01 00:00～2025.06.30 00:00で開始したことを示す。
`20260909.log:2625`は`InpRunId=tstech_candidate_202501to06-2`。
対応は`target_journal_evidence.csv`に保存した。他の同日run・途中失敗runとは分離している。

今回の実行は**生成ティックのEvery tick**。metadataの`REAL_TICKS_MODEL_4`は実行設定と不一致。
以前の4月正式runのjournalは`generating based on real ticks`であり、今回と異なる。
`InpTesterModel`等のEA入力に説明文字列を入れても、Strategy Testerのモデリング設定は変更されない。

MT5公式資料は実際のbroker tickとM1から生成するtickを区別する：
https://www.metatrader5.com/en/terminal/help/algotrading/tick_generation
https://www.metatrader5.com/en/terminal/help/algotrading/testing

急変検出の250/500/1000ms return、activity、Bid/Ask経路、first-touchはtick生成方式に依存する。
従って今回の特徴量とラベルを、そのまま「実リアルティックの急変から利益が取れる」ことの学習・検証母集団にはできない。
生成ティック上の分析やソフトウェア試験には残せるが、リアルティックへの変換はCSV加工ではできない。
生成モードが旧pool exhaustionの原因だとは、本監査だけでは証明していない。

## 15,097回のpool exhaustion

- target runに限定したAgent journalの発生行数：15,097。summary値と一致。
- 発生時刻・symbolを`legacy_pool_failure_occurrences.csv`に保存。月別/通貨別にも集計。
- 対象は旧strategy scenario用`g_event_engine`のslot。
- `TSRV1ObserveBoundary`（研究EAの2750行付近）ではstatistical trackとTechnical episode登録を先に行い、その後に旧candidate eventを登録する。
- `TSRV1RegisterCandidateEvent`（2562行付近）のpool failureは、その旧イベント登録をfalseで終了する。先行するTechnical observerを削除しない。
- `TSRV1RegisterStatisticalTrack`のtrack_capacity_hits=0、Technical専用capacity=0、feature_invalid=0。
- medium_horizonとTechnicalのepisode集合17,648件が一致。
- `TSRProcessOneTick`ではTechnicalへのquote供給が旧g_eventsの処理より先で、旧pool失敗を条件に供給停止するコードは確認されない。

結論：15,097件の**Technical episode欠落**と同一視するのは誤り。旧scenario研究の不完全性は実在し、run全体のVALIDATION_INVALIDは維持する。
これは静的経路と保存済みcounterの監査であり、旧機能を外した再実行による完全な反実仮想比較ではない。

## read failures=4 / incomplete frontier=1

GBPUSD、USDJPY、USDCAD、USDCHFで各1回。EURUSD/AUDUSDは0。
各通貨の最終状態：

- history_synchronized=true
- last_copy_error=0 / root_cause空
- cursor_stalls=0 / page_limits=0
- final_drains=1
- read_through_msc=requested_to_msc=1751068619710

全体でpending_capacity_hits=0 / dropped_ticks=0 / cursor_stalls=0、最終incomplete_frontier=false。
`TickShockMergeSequencer.mqh:98`のBeginReadCycleはhistory未同期でもread_failure_countを増やすため、4回をすべてCopyTicks APIエラーと呼ぶことはできない。
同ファイルの`TSMergeObserveReadThroughFrontier`は不完全rangeがある間はreleaseせず、後のread-through証明でrecoverable gapだけを解除する。capacity/drop/stallの恒久的損失は解除しない。
`TSRDispatcher`もready=falseの間はreleased=0とする。

結論：保存された最終状態と実装は**回復済みのread-through**を支持し、今回の4回だけからtick欠落とは断定しない。
ただし各失敗の瞬間のroot cause/正確な時刻は通常ログに残っておらず、初期同期の失敗だったと断言しない。pending read-throughの回復はtick生成モードの誤りを解消しない。

## 来歴と範囲

- 現在のCandidate EX5 SHAはmetadata記載値と一致：FB7F284E5E34EFB1EA72626D4B9C15D041F5766976AFB86C1688ED2E8424C113。
- これは現在ファイルとの照合。実行時に採取した独立hash証跡ではない。
- Tester指定終了は6月30日00:00で、最後の処理quoteは6月27日金曜日の終了近辺。6月30日の取引時間は対象外。末尾6月27日は途中停止の証拠ではない。
- Tester自身のTest passedは終了確認であり、研究runのintegrity合格ではない。
- 今回のモデルは生成tickなので、「リアルtickモード内fallback何分」という以前の未解決表現よりも、実行modeそのものが違うことを優先して記録する。

## 次の手順

実リアルティックを目的にした正式分析には、正しいmodeでのデータ収集が必要。
ただし、直ちに半年を再実行せず、まず短期間で次を確認することを推奨する。

1. 研究用`ExpectedValue_MultiCurrency_TickShockTechnicalResearch`をStrategy Testerで選択。
2. Testerのモデリングを「リアルティックに基づいたすべてのティック」にする。「すべてのティック」だけでは異なる。
3. EURUSD/M1、六通貨、最適化なし。同じ対象brokerを維持するならBybitのreal tick履歴を確認する。勝手にVantageと混ぜない。
4. RunId/LogFolderは新規一意名。InpResearchPeriodは本当の期間、source/EX5識別も実ファイルに合わせる。
5. 開始journalで`generating based on real ticks`を確認。履歴品質とpool/capacityも確認してから長期間へ延長。
6. 旧研究poolの問題はResearchにも残りうる。Researchへの切替だけで解決すると保証しない。

今回は監査のみの依頼なので収集器修正やテスト起動はしていない。既存データは削除しない。

## 検証証跡

`scope_checks.csv`：45 PASS、2 FAIL（actual real tick mode / metadata一致の2件）。
全入力のSHAは`provenance_input_hashes.csv`。独立した旧受付QA34 PASS/2 FAILを上書きしていない。
今回のスクリプトはモデルや損益計算をimportしない。

```powershell
python tools/tick_shock/audit_technical_4m2m_provenance.py --input C:\Users\windows\AppData\Roaming\MetaQuotes\Terminal\Common\Files\tstech_candidate_202501to06-2 --output reports/analysis/tick_shock/technical_4m2m_codex/provenance_audit_replay --journal C:\Users\windows\AppData\Roaming\MetaQuotes\Tester\2FA8A7E69CED7DC259B1AD86A247F675\Agent-127.0.0.1-3000\logs\20260909.log --journal C:\Users\windows\AppData\Roaming\MetaQuotes\Tester\2FA8A7E69CED7DC259B1AD86A247F675\Agent-127.0.0.1-3000\logs\20260910.log --ex5 mql/Experts/ExpectedValue_MultiCurrency_TickShockTechnicalCandidate.ex5
```
