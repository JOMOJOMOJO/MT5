# 2025年1～6月：月別リアルティック収集

## 今回起動したバッチ

`reports/backtest/batches/tstech_real_202501_202506_20260910/`

- `status.json`：現在状態。WAITING_FOR_TERMINAL_CLOSE / RUNNING / STOPPED_ERROR / COMPLETED。
- `months.csv`：六つの月の予定と進捗。
- `worker.stdout.log` / `worker.stderr.log`：バックグラウンド実行ログ。
- 各月の`runner.log`、`tester_config.ini`、`technical_discovery.set`、`collection_qa.json`。

起動中の`C:/Program Files/XMTrading MT5/terminal64.exe`を通常操作で閉じると開始する。
自動収集中は同じMT5を手動で起動しない。PCのスリープを避け、通信と空き容量を維持する。
完了通知をCodexへ送る際はバッチフォルダのパスを伝える。

## 固定条件

- 2025-01-01～02-01、02-01～03-01、…、06-01～07-01の六回。
- EURUSD/M1 driver、元の六通貨、Model=4（real ticks）、最適化なし、execution delay=0。
- Bybit環境の既存端末を明示指定。別Vantage端末へ黙って切り替えない。
- 研究用EX5。実注文を出すTechnicalCandidateではない。
- 検証済み4月研究runのEX5を変更せず再利用。SHA：79FE8D7864EF82607F141CCAFC1CD527FC0BB127D4ED6FE927044F0A3EBB7CFF。
- exact source ZIPと当時のcompile logもfrozen/へ保存。今回の再コンパイルは行っていない。
- worktreeで削除状態の2ソースは復元せず、他のEAや戦略ロジックも変更していない。
- 半年を連続実行したrunとは、月初のdetector warmupと月末censorが異なる。分析時に月境界と各RunIdのcluster IDを区別する。

## 出力と停止条件

### Scoped gate変更（ユーザーの続行指示）

「40」は上限ではなく旧研究の64 active event枠が満杯になった回数。
メモリを無制限にする変更は行わず、Technical収集の独立したチェックを追加した。
リアルtick、6通貨read-through完了、drop/stall/page limitなし、statistical track capacityなし、Technical capacity/feature errorなし、episode集合・12geometry・時刻の因果性・CSV重複なしを全て確認した場合のみ、旧event poolの失敗は警告で続行する。
結果は`PASS_WITH_LEGACY_WARNING`、scopeは`TECHNICAL_COLLECTION_ONLY`。旧run summaryのVALIDATION_INVALIDは消さない。
旧研究のシナリオ成績を正式結果として救済したわけではない。月収集チェックの変更であり、EAの戦略・モデル・メモリ容量に変更はない。
1月は27項目合格で再収集せず保存済みデータを使用。元FAIL結果は`202501/collection_qa_before_scoped_gate.json`に保存。
新ゲートの単体テスト6件PASS。tick loss等の不正を隠さないことを検査した。
`-Worker -ResumeCompleted`は、完了月のQAと主要CSVのSHAを検証してその月をスキップし、未開始月だけ続ける明示オプション。途中のrunへのappend/resumeではない。

原本はCommon/Files/tstech_real_202501_202506_20260910_YYYYMM/。
主要CSVと小さな証跡をバッチのYYYYMM/にもコピーする。旧研究の巨大CSVはCommon側だけに置く。
各月は最大6時間。report未生成、real tick mode不一致、異なるbroker、旧pool以外で説明できないintegrity invalid、Technical容量/特徴量異常、主要CSV欠落などで停止し、次月へ進まない。
実リアルティックmodeをjournalで確認しても、欠損時のgenerated fallbackが0だとは断定しない。全期間の正式品質判定は完了後の別監査。
Researchにも旧pool処理があるため、月分割だけで上限到達問題が消えるとは保証しない。旧poolだけの失敗は上記のTechnical scoped gateに従って警告として残す。
PC再起動後の自動復帰や暗黙resumeは実装しない。既存runへの追記・上書きは拒否する。

## スクリプト

`tools/tick_shock/run_technical_monthly_collection.ps1`
`tools/tick_shock/verify_technical_month_capture.py`

新規バッチを別名で作成・起動する場合のみ：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/tick_shock/run_technical_monthly_collection.ps1 -BatchId <new_unique_id>
```

今回のバッチは既にworker起動済みなので、重ねて実行しない。

## 旧生成ティックデータ

`Common/Files/tstech_candidate_202501to06-2/`はユーザーが削除を許可したが、完全削除のtool commandが実行環境に拒否され、削除していない。
小さいsummary/specs/runmetaと一覧は`reports/analysis/tick_shock/technical_4m2m_codex/retained_generated_capture_metadata/`へコピー済み。
元データは約17.8GBのまま残存。削除済みと扱わない。
