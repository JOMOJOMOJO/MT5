# Tick-shock研究EA artifact manifest

- artifact ID: `TS-STEP01-MANIFEST`
- step: `01`
- branch: `research/tickshock-testability-refactor-20260822`
- purpose: testability refactor前のcanonical source、test、document、baseline/current evidence、checkpoint成果物を固定する
- status: `CHECKPOINT_READY`

`source/generated` は、実装・定義・設定を `source`、実行結果・集計・checkpoint記録を `generated evidence` として区別します。`commit対象` はこのStep 1 branchへ保存する判断です。

| artifact ID | step | artifactの相対パス | 種別 | 用途 | source/generated | SHA-256 | commit対象 | 次の使用Step | status | 備考 |
|---|---:|---|---|---|---|---|---|---|---|---|
| TS-SRC-001 | 01 | `mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5` | research EA | event study/realizable execution研究本体 | source | `976148D017E067728DC8827724516A076E7561C89D8D57BCD850D40DCB54A32C` | yes | Step 2 | PRESENT_COMMITTED | 想定パスと一致 |
| TS-SRC-002 | 01 | `mql/Include/TickShockStateMachine.mqh` | shared include | shock状態機械 | source | `3F943BA650A45A5C4D7CA587C342A1AFF00D9FDF3C5533BE7AFDB5E6E173A6ED` | yes | Step 2 | PRESENT_COMMITTED | 想定パスと一致 |
| TS-SRC-003 | 01 | `mql/Include/TickShockResearchExecution.mqh` | shared include | research execution/scenario共通処理 | source | `14577A74598F7974DCDD87097E83A1E1152B02D204C69CD327B8ED61F4EBA660` | yes | Step 2 | PRESENT_COMMITTED | 想定一覧外だが実在する依存source |
| TS-SRC-004 | 01 | `mql/Experts/ExpectedValue_MultiCurrency_TickShockScalper.mq5` | reference EA | 研究EAと売買EAの境界・既存実装参照 | source | `60A1A462CF19683A4C01BE8407B24BC3316A55F7D26DB1F54310329A775BCDF2` | yes | Step 2 | PRESENT_COMMITTED | Step 1ではlogic変更なし |
| TS-TST-001 | 01 | `mql/Experts/tests/ExpectedValue_TickShock_ResearchReachabilityHarness.mq5` | production-path test | research経路の到達性検証 | source | `E352D902FE01F7B721045175DCF139AC0B3CA0F938E2D459785B569684CCD594` | yes | Step 2, 3 | PRESENT_COMMITTED | 想定パスと一致 |
| TS-TST-002 | 01 | `mql/Experts/tests/ExpectedValue_TickShock_OrderReachabilityHarness.mq5` | order harness | OrderCheck/OrderSend/約定観測 | source | `164A5C89E976E66FED7EE1AA3557DB784C7E3A8990B244F673E0C5A421F8917C` | yes | Step 2, 3 | PRESENT_COMMITTED | 想定パスと一致 |
| TS-TST-003 | 01 | `mql/Experts/tests/ExpectedValue_TickShock_ReachabilityHarness.mq5` | legacy harness | 状態機械の既存到達性回帰 | source | `04E116772925CA1D7ADC6BD8352894A9A23CC1248FFF890D7775EC2452DB0AB1` | yes | Step 2, 3 | PRESENT_COMMITTED | 想定一覧外の既存test |
| TS-TST-004 | 01 | `scripts/validate-tickshock-research-output.ps1` | validator | scenario CSVと集計の再計算 | source | `12D30B12A553F6395ADFF0FFA321A25AB3BAA7B599AA10A59EF653040F8293EF` | yes | Step 2, 3 | PRESENT_COMMITTED | 再現性tool |
| TS-DOC-001 | 01 | `docs/research/tick_shock_scalper_csv_schema.md` | schema | CSV列定義 | source | `102FBD601D14986B056600C368FE612D62AD1BD7C5400A36D58BC5F48C3F5066` | yes | Step 2, 3 | PRESENT_COMMITTED | 想定パスと一致 |
| TS-DOC-002 | 01 | `.company/qa/2026-08-22-tick-shock-execution-revision.md` | QA decision | execution revisionの評価境界 | source | `FDEE25ED228E8C4C3278EF039854331114DE013EF372CA91C4B8E1A3306E6119` | yes | Step 2 | PRESENT_COMMITTED | pre-causal-validation判断 |
| TS-DOC-003 | 01 | `.company/qa/2026-08-22-tick-shock-realizable-execution.md` | QA decision | realizable execution検証の現状 | source | `EEB17443DA4DCC188A77DAA7E88C6BBD2D8D599285262A0FBD72943CB04BECEF` | yes | Step 2 | PRESENT_COMMITTED | 現在のvalidation stance |
| TS-DOC-004 | 01 | `docs/devlog/2026-08-22-tick-shock-realizable-execution.md` | devlog | 実装・証拠・既知制約への案内 | source | `10FE56195F76021C335FC3DBC861927F03F959493F03868D92EDEE76DE3C23BA` | yes | Step 2 | PRESENT_COMMITTED | repo ruleに基づくdurable log |
| TS-CFG-001 | 01 | `reports/presets/ExpectedValue_MultiCurrency_TickShockResearch_realizable_202503.set` | tester preset | 2025年3月realizable run再現 | source | `297018FA9BE5BD5DCED316BF9D0AB93B46A4D3BC5C73F2D7633B8393616505C6` | yes | Step 3 | PRESENT_COMMITTED | 長期OOS用ではない |
| TS-CFG-002 | 01 | `reports/presets/ExpectedValue_TickShock_ResearchReachability_production_path.set` | tester preset | research harness再現 | source | `1E8F23CD4AD17007A0BE7E43F3DBE76097F02494CDB69F7E34CF3E567C2A6671` | yes | Step 3 | PRESENT_COMMITTED | production-path test |
| TS-CFG-003 | 01 | `reports/presets/ExpectedValue_TickShock_OrderReachability_observation_truth.set` | tester preset | order harness再現 | source | `740DEEECB7DC89899EAAA897A8009990216CB9C77DE36874E82F3C9F50F64E4C` | yes | Step 3 | PRESENT_COMMITTED | 未観測項目をPASS化しない設定 |
| TS-BAS-001 | 01 | `reports/backtest/runs/20260822_tickshock_execution_revision/summary.md` | baseline report | pre-refactor baseline判断 | generated evidence | `D5C3CA7D19B9C1158C5B8A1C57AC1AACB1F023D7EA68AC81731331AE04FE2967` | yes | Step 2, 4 | PRESENT_COMMITTED | 想定パスと一致。現行正式edge根拠ではない |
| TS-BAS-002 | 01 | `reports/backtest/runs/20260822_tickshock_execution_revision/events.csv` | event evidence | baseline event-level再計算 | generated evidence | `45F01B4F54CE45ACC94A08B48391A6CCB382110096FBAC9FE4B54741D10D9D14` | yes | Step 2, 4 | PRESENT_COMMITTED | 想定パスと一致 |
| TS-BAS-003 | 01 | `reports/backtest/runs/20260822_tickshock_execution_revision/summary.csv` | aggregate evidence | baseline aggregate | generated evidence | `3CED2C22045F5911445E895BD2A55386BD8CB5DA28D6606AC7C283C5FEEFA17A` | yes | Step 2, 4 | PRESENT_COMMITTED | 想定パスと一致 |
| TS-BAS-004 | 01 | `reports/backtest/runs/20260822_tickshock_execution_revision/tick_quality.csv` | data-quality evidence | real/generated tick品質 | generated evidence | `ABE0DC22294F3D584329B9069F06FA5A1DCA7683D3BC78A53F2BF989A60635AC` | yes | Step 2, 4 | PRESENT_COMMITTED | 想定パスと一致 |
| TS-BAS-005 | 01 | `reports/backtest/runs/20260822_tickshock_execution_revision/symbol_specs.csv` | broker-spec evidence | symbol仕様・stop grid参照 | generated evidence | `629B721ABE1F4756597B2155EA7C3E08B9D05A88EF6E685FA5CC575D7C793AB0` | yes | Step 2, 4 | PRESENT_COMMITTED | baseline補助成果物 |
| TS-BAS-006 | 01 | `reports/backtest/runs/20260822_tickshock_execution_revision/trades.csv` | scenario evidence | baseline trade/scenario再計算 | generated evidence | `69DFAB285053561A1B3B95776103D8CEEB380E1963FE3C407392E6C216A729C6` | yes | Step 2, 4 | PRESENT_COMMITTED | 実注文取引とは区別 |
| TS-CUR-001 | 01 | `reports/backtest/runs/20260822_tickshock_realizable_execution/summary.md` | current report | 最新checkpointの判断と制約 | generated evidence | `9043A771322F5F83BCA0207D63D50803F7980AF6A8CBCCBCF0EDCCE9EAAA38C9` | yes | Step 2, 4 | PRESENT_COMMITTED | causal validation完了を意味しない |
| TS-CUR-002 | 01 | `reports/backtest/runs/20260822_tickshock_realizable_execution/events.csv` | event evidence | event funnel/causality監査 | generated evidence | `EAC7BBEBFF71CAFC70576A4E4D06D9BD6EFAF5BF34E8A4826284EB754986E2A1` | yes | Step 2, 4 | PRESENT_COMMITTED | Step 2差分比較の主入力 |
| TS-CUR-003 | 01 | `reports/backtest/runs/20260822_tickshock_realizable_execution/summary.csv` | aggregate evidence | current aggregate再計算 | generated evidence | `3AADFE299C94B98D201BFC566248FC60701D9FF9927A931F45BE4F2893DAB23D` | yes | Step 2, 4 | PRESENT_COMMITTED | current summary |
| TS-CUR-004 | 01 | `reports/backtest/runs/20260822_tickshock_realizable_execution/tick_quality.csv` | data-quality evidence | 通貨別tick品質 | generated evidence | `084F8F6188BCB37611DA5B8943055B16CEDC9777E5216884DD7FF8A72A413ED4` | yes | Step 2, 4 | PRESENT_COMMITTED | fallback監査入力 |
| TS-CUR-005 | 01 | `reports/backtest/runs/20260822_tickshock_realizable_execution/symbol_specs.csv` | broker-spec evidence | Bid/Ask基準distance/volume仕様 | generated evidence | `0F613577AC822AC79985792E359DF284DC224DD70B350170CDF3F058858555E7` | yes | Step 2, 4 | PRESENT_COMMITTED | broker条件の固定入力 |
| TS-CUR-006 | 01 | `reports/backtest/runs/20260822_tickshock_realizable_execution/research-reachability.csv` | harness evidence | production-path test結果 | generated evidence | `E59A11AB9E7BD31D3C2C5CAA6A839C4AF090715318AA95DC583D4C5E6AE06864` | yes | Step 2, 3 | PRESENT_COMMITTED | Step 2で再実行対象 |
| TS-CUR-007 | 01 | `reports/backtest/runs/20260822_tickshock_realizable_execution/order-reachability.csv` | harness evidence | order observation結果 | generated evidence | `8881A5ABBBBE820B9E76643E1B56B1BE950FD7AFF2C15AA191658FDA0ED18DB9` | yes | Step 2, 3 | PRESENT_COMMITTED | NOT_OBSERVEDを含む観測表 |
| TS-CUR-008 | 01 | `reports/backtest/runs/20260822_tickshock_realizable_execution/csv-recount-validation.csv` | recount evidence | scenario集計とCSVの一致確認 | generated evidence | `366D61506959BD50BC15ED5DD9C30E70C1EAB6CB9B9E2962A469D395946C3758` | yes | Step 2, 3 | PRESENT_COMMITTED | validator比較入力 |
| TS-CUR-009 | 01 | `reports/backtest/runs/20260822_tickshock_realizable_execution/sha256.txt` | checksum evidence | run成果物のdigest一覧 | generated evidence | `463ACDAF51B6250F20E44C5F6944714B0050FFF3E2E5F98D685E4A44B586C53E` | yes | Step 2, 4 | PRESENT_COMMITTED | run内の既存digest |
| TS-CHK-001 | 01 | `reports/checkpoints/tick_shock/step01_file_inventory.csv` | file inventory | 作業前変更386件の分類・action・digest | generated evidence | `5EFC952B6FD8A430E4FABCC49D69356AD62C625577E9391C8569AECC0167ABBC` | yes | Step 2 | READY_TO_COMMIT | Step 1生成物 |
| TS-CHK-002 | 01 | `reports/checkpoints/tick_shock/step01_checkpoint.md` | checkpoint report | branch、commit、除外、復元方法 | generated evidence | `8614ABBFE67A0867962C0CB20AD408C8B94EC7AB4AA4E8F4B09BD1335996A3DC` | yes | Step 2 | READY_TO_COMMIT | Step 1生成物 |
| TS-ARC-001 | 02 | `docs/research/tick_shock/02_as_is_architecture.md` | architecture document | component・lifecycle・merge・execution時刻のAs-Is固定 | source | `73A3961343AA298663BB288E3F30090AAB51EB251E88CFD847F06AFDA084CD8B` | yes | Step 3, 4 | PRESENT_COMMITTED | production/test source変更なし |
| TS-CAT-001 | 02 | `docs/research/tick_shock/02_function_catalog.md` | function catalog | 5 source・165関数の責務/副作用/呼出関係 | source | `88971062E4FBE49D9852F2F19FA254F82348279B82B89F8D0ADD5B9C8F8F28F9` | yes | Step 3, 4 | PRESENT_COMMITTED | 機械抽出165、catalog165、差分0 |
| TS-DAT-001 | 02 | `docs/research/tick_shock/02_data_structures_and_globals.md` | data inventory | input・constant・enum・struct・global・capacity固定 | source | `807313A51C42077148938081C34FDF09ED14CB074DD916EA0B82FBE677BCDD53` | yes | Step 3, 4 | PRESENT_COMMITTED | 単位/lifetime/注入可能性を含む |
| TS-FLW-001 | 02 | `docs/research/tick_shock/02_dataflow_and_state.md` | dataflow/state document | detector/event/scenario/orderと全時刻のAs-Is固定 | source | `19DB8BF09AE3E0B956C658F99FFB73F0FE3F736A5C4E0C933EA0718B19FC0A70` | yes | Step 3, 4 | PRESENT_COMMITTED | Long/Short対称表を含む |
| TS-DEF-001 | 02 | `docs/research/tick_shock/02_known_defects.md` | defect register | baseline欠陥・current guard・未観測gapの分離 | source | `F7174D68DB9F72852ED08310DCF2EE84D2915A6DA0D70BFC3B3F058DA2B146C6` | yes | Step 3, 4 | PRESENT_COMMITTED | Step 3 Test ID候補を付与 |
| TS-REF-001 | 02 | `docs/research/tick_shock/02_refactor_targets.md` | refactor plan | test seam・adapter・module・安全な抽出順序 | source | `2CA081BB31A49224CC76A1CC63C7C0333E20D03A930328C88758AEA240AF2F73` | yes | Step 3, 4 | PRESENT_COMMITTED | behavior-preservingとbug fixを分離 |
| TS-RPT-001 | 02 | `reports/analysis/tick_shock/step02_as_is_completion.md` | completion evidence | 入力digest・件数照合・未解決事項・引継 | generated evidence | `D8852C6EBBE545CB2C5AD2C06646F5E4AE6EE4D5003BD00D00EBF6DEB5A3C844` | yes | Step 3 | PRESENT_COMMITTED | Step 2完了証跡 |

このmanifest自身は内容内に自身のSHA-256を埋め込むとdigestが循環するため、表の対象外です。完全性はcheckpoint commitのGit objectで固定し、外部確認時は `Get-FileHash -Algorithm SHA256 docs/research/tick_shock/00_artifact_manifest.md` を使用します。全64既存commit対象と全未commit対象の網羅的な一覧は `reports/checkpoints/tick_shock/step01_file_inventory.csv` がsource of truthです。

## Validation boundary

- `RESEARCH_PIPELINE_PARTIALLY_VALIDATED`
- `EXECUTION_MODEL_NOT_CAUSALLY_VALIDATED`
- `STRATEGY_FEASIBILITY_NOT_ESTABLISHED`
- `EDGE_UNDETERMINED`
- 長期OOS未実施
