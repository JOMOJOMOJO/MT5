# Tick-shock研究EA Step 1 checkpoint

- 作成日: 2026-08-22
- branch: `research/tickshock-testability-refactor-20260822`
- remote: `origin` (`https://github.com/JOMOJOMOJO/MT5.git`)
- upstream: `origin/research/tickshock-testability-refactor-20260822`
- 作業前HEAD: `07405d426654647447f90e04a55086774f405a59`
- 分岐元: `research/trendline-wave2-failure/2026-08-20-m15-execution-shadow` のローカルHEAD

このcheckpointは、既存のTick-shock研究作業を失わず、Step 2のtestability refactor前に復元可能な境界を作るためのものです。strategy logicの追加変更、長期OOS、パラメータ最適化は行っていません。

## 作成したcommit

| commit | subject | 対象 |
|---|---|---|
| `affd45edae9aee57148546fc086c9f7f6926b56e` | `research: checkpoint tickshock source and harnesses` | source、shared include、3 harness（7ファイル） |
| `c6c6fb638911682ea06fe00edf2846561f53b5cd` | `research: add tickshock reproducibility tooling and presets` | validator、再現用preset（17ファイル） |
| `0c18ad5edfc2c6c822771e77993cac6f49e6be30` | `docs: record tickshock validation decisions` | QA、devlog、schema、knowledge、seed（11ファイル） |
| `030f3b091ea549a03fd92ed599f66410066333cb` | `research: preserve tickshock March validation evidence` | 2025年3月の選別済みvalidation evidence（29ファイル） |

本ファイル、artifact manifest、file inventoryを含むcheckpoint commitは自己参照になるため、この文書内に自身のcommit hashを固定しません。確認には `git log -1 -- reports/checkpoints/tick_shock/step01_checkpoint.md` を使用します。

## commit対象ファイル

作業前HEADから上記4 commitまでの64ファイルと、Step 1成果物3ファイルをcommit対象としました。64ファイルの正確な一覧、分類、SHA-256は [`step01_file_inventory.csv`](step01_file_inventory.csv) の `action=commit` 行にあります。

主な対象は次のとおりです。

- Tick-shock研究EA、scalper参照EA、shared include
- research/order/legacy reachability harness
- output validatorと再現用preset/INI/SET
- CSV schema、QA判断、devlog、knowledge、seed
- `20260822_tickshock_execution_revision` の選別済みbaseline evidence
- `20260822_tickshock_realizable_execution` の選別済み最新evidence
- Step 1 artifact manifest、file inventory、checkpoint

## commitしなかったファイル

作業前の全棚卸し386件のうち、次はcommitしていません。正確なパスとSHA-256はfile inventoryを参照してください。

| 分類 | 件数 | action | 理由 |
|---|---:|---|---|
| `tick_shock_evidence` | 76 | `leave_uncommitted` | 古いrun、重複・superseded evidence、巨大な生出力。Step 2のcanonical inputではないためローカルに保持 |
| `generated_cache` | 238 | `exclude` | HTML/PNG/meta/log/EX5/terminal生成物など。再生成可能またはcache相当 |
| `secret_risk` | 1 | `exclude` | `tester-journal-excerpt.txt` に端末Tester cacheの絶対パスが含まれるため |
| `unrelated_user_change` | 7 | `leave_uncommitted` | session-reversalの追記1件とTrendline raw event CSV 6件。Tick-shock Step 1のscope外 |

明示的に保持したunrelated user changeは次のとおりです。

- `reports/backtest/runs/20260628_session_reversal_pullback_timeframe_matrix/batch_status.csv`
- `reports/backtest/runs/20260815_trendline_wave2_failure/baseline_2024/legacy_fw2t_baseline_2024_events.csv`
- `reports/backtest/runs/20260815_trendline_wave2_failure/baseline_2025/legacy_fw2t_baseline_2025_events.csv`
- `reports/backtest/runs/20260815_trendline_wave2_failure/baseline_2026/legacy_fw2t_baseline_2026_events.csv`
- `reports/backtest/runs/20260815_trendline_wave2_failure/combined_2024/legacy_fw2t_combined_2024_events.csv`
- `reports/backtest/runs/20260815_trendline_wave2_failure/combined_2025/legacy_fw2t_combined_2025_events.csv`
- `reports/backtest/runs/20260815_trendline_wave2_failure/combined_2026/legacy_fw2t_combined_2026_events.csv`

secrets、認証token、password、private keyはcommit対象から検出されませんでした。確認したtester INIの口座指定は `Account=0` でした。remote URLにも認証情報は含まれていません。MT5 compile log、EX5、terminal cache、および口座表示を含み得るHTML/PNG/metaはcommitしていません。

## Tick-shock sourceの正確なパス

想定されたsource/test/document pathはすべて実在し、複製や移動はしていません。

- `mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5`
- `mql/Include/TickShockStateMachine.mqh`
- `mql/Include/TickShockResearchExecution.mqh`
- `mql/Experts/tests/ExpectedValue_TickShock_ResearchReachabilityHarness.mq5`
- `mql/Experts/tests/ExpectedValue_TickShock_OrderReachabilityHarness.mq5`
- `mql/Experts/tests/ExpectedValue_TickShock_ReachabilityHarness.mq5`
- `docs/research/tick_shock_scalper_csv_schema.md`

`TickShockResearchExecution.mqh` とlegacy reachability harnessは、当初の想定一覧にはありませんでしたが、実際の依存関係・検証資産として登録しています。

## baseline backtest成果物の正確なパス

ユーザーが想定したpre-refactor baselineは次の実在パスです。

- `reports/backtest/runs/20260822_tickshock_execution_revision/summary.md`
- `reports/backtest/runs/20260822_tickshock_execution_revision/events.csv`
- `reports/backtest/runs/20260822_tickshock_execution_revision/summary.csv`
- `reports/backtest/runs/20260822_tickshock_execution_revision/tick_quality.csv`
- `reports/backtest/runs/20260822_tickshock_execution_revision/symbol_specs.csv`
- `reports/backtest/runs/20260822_tickshock_execution_revision/trades.csv`

これとは別に、Step 2が最新のcausality/testability課題を参照するための現行evidenceは次の実在パスです。

- `reports/backtest/runs/20260822_tickshock_realizable_execution/summary.md`
- `reports/backtest/runs/20260822_tickshock_realizable_execution/events.csv`
- `reports/backtest/runs/20260822_tickshock_realizable_execution/summary.csv`
- `reports/backtest/runs/20260822_tickshock_realizable_execution/tick_quality.csv`
- `reports/backtest/runs/20260822_tickshock_realizable_execution/symbol_specs.csv`
- `reports/backtest/runs/20260822_tickshock_realizable_execution/research-reachability.csv`
- `reports/backtest/runs/20260822_tickshock_realizable_execution/order-reachability.csv`
- `reports/backtest/runs/20260822_tickshock_realizable_execution/csv-recount-validation.csv`

## 現時点の判定

- `RESEARCH_PIPELINE_PARTIALLY_VALIDATED`
- `EXECUTION_MODEL_NOT_CAUSALLY_VALIDATED`
- `STRATEGY_FEASIBILITY_NOT_ESTABLISHED`
- `EDGE_UNDETERMINED`
- 長期OOS未実施

このcheckpointはexecution modelの妥当性やstrategy edgeを承認しません。正式なExpectancy・edge判定、長期OOS、最適化、売買EAへの昇格はStep 1の対象外です。

## 次Stepが参照すべきファイル

Step 2は最低限、次を入力として使用します。

1. `docs/research/tick_shock/00_artifact_manifest.md`
2. `reports/checkpoints/tick_shock/step01_file_inventory.csv`
3. `reports/checkpoints/tick_shock/step01_checkpoint.md`
4. `mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5`
5. `mql/Include/TickShockResearchExecution.mqh`
6. `mql/Include/TickShockStateMachine.mqh`
7. `mql/Experts/tests/ExpectedValue_TickShock_ResearchReachabilityHarness.mq5`
8. `mql/Experts/tests/ExpectedValue_TickShock_OrderReachabilityHarness.mq5`
9. `docs/research/tick_shock_scalper_csv_schema.md`
10. `reports/backtest/runs/20260822_tickshock_execution_revision/summary.md`
11. `reports/backtest/runs/20260822_tickshock_realizable_execution/summary.md`
12. `reports/backtest/runs/20260822_tickshock_realizable_execution/events.csv`
13. `reports/backtest/runs/20260822_tickshock_realizable_execution/research-reachability.csv`
14. `reports/backtest/runs/20260822_tickshock_realizable_execution/order-reachability.csv`
15. `reports/backtest/runs/20260822_tickshock_realizable_execution/csv-recount-validation.csv`

## 復元方法

push後のcheckpoint branchを復元する場合:

```powershell
git fetch origin
git switch --track origin/research/tickshock-testability-refactor-20260822
```

同名local branchが既にある場合は、そのbranchへ切り替えてからfast-forward可能かを確認します。上書きやforce操作は行いません。

checkpoint commitを直接確認する場合:

```powershell
git log -1 origin/research/tickshock-testability-refactor-20260822
git switch --detach <表示されたcheckpoint-commit-hash>
```

作業開始前の状態だけを参照する場合:

```powershell
git switch --detach 07405d426654647447f90e04a55086774f405a59
```

未commitのユーザー変更や生成物はこのGit checkpointには含まれません。必要なローカルファイルは削除せず、そのままworktreeに残しています。
