# Tick-shock研究EA Step 8 final QA

## 結論

Step 1～7の成果物は、研究用shadow executionの因果性を評価する基盤としては再現可能です。`REALIZABLE_EA` の2025年3月runについて、Step 8の独立再計算でもformal causal invariant違反は **0件** でした。

ただし、これは本番売買EAの合格ではありません。研究EAには注文経路がなく、実commission、server SL/TP、時間決済、actual partial fill、position/restart recoveryが未観測です。独立サンプルは15 market clustersしかなく、全gridのREALIZABLE ExpectancyRは `-0.292361643098`、4 strategyの集計もすべてマイナスでした。

最終判定は次のとおりです。

- `RESEARCH_PIPELINE_PARTIALLY_VALIDATED`
- `EXECUTION_MODEL_CAUSALLY_VALIDATED_FOR_SHADOW_REPLAY`
- `BROKER_ORDER_LIFECYCLE_NOT_VALIDATED`
- `STRATEGY_SHADOW_FEASIBILITY_ESTABLISHED`
- `DEPLOYABLE_STRATEGY_FEASIBILITY_NOT_ESTABLISHED`
- `EDGE_UNDETERMINED`
- `NOT_A_PRODUCTION_CANDIDATE`
- `LONG_OOS_NOT_AUTHORIZED`

Step 7の `STRATEGY_FEASIBILITY_ESTABLISHED` は「因果的かつbroker grid上で成立するshadow outcomeが存在する」という限定的な意味でのみ維持します。注文・実コストを含む売買可能性を意味しません。

## 監査範囲

指定された必須29パスを名前どおり確認しました。欠損は0件で、別名推測や代替入力は行っていません。主な入力は以下です。

- 引継: `docs/research/tick_shock/00_artifact_manifest.md`
- Step 1: `reports/checkpoints/tick_shock/`
- Step 2: `reports/analysis/tick_shock/step02_as_is_completion.md` と `docs/research/tick_shock/02_*.md`
- Step 3: `reports/tests/tick_shock/step03_test_spec_review.md`、`docs/research/tick_shock/03_*.md`、`tests/tick_shock/spec/`、128 fixtures、64 expected
- Step 4: `reports/refactor/tick_shock/` と `docs/research/tick_shock/04_*.md`
- Step 5/6: pre-fix RED evidence、post-fix GREEN evidence、causal fix document
- Step 7: IDEAL run、REALIZABLE run、causal comparisonの3ディレクトリ

詳細findingは `reports/qa/tick_shock/step08_final_qa_findings.csv`、Test ID単位の監査は `reports/qa/tick_shock/step08_traceability_audit.csv`、独立計算値は `reports/qa/tick_shock/step08_recalculation.csv` に保存しました。

## 検証できたもの

### Artifact、SHA、git

- manifestのartifact行は393、実パスは377です。欠損0件です。
- 各実パスの最新登録SHA-256は377/377一致しました。
- 後続Stepで同一パスが更新されたため現行bytesと異なる履歴行は16件ありますが、すべてStep 1/2/4/5の該当commitに対してSHAが一致しました。
- Step 7 `source_hashes.txt` のEA＋11 moduleは、IDEAL/REALIZABLEとも12/12がbase commit `1d3948916da587cd20e61036a14980fedd0cfd5d` および現行sourceに一致しました。
- presetとtester configの現在SHAも記録値に一致し、両runの差はexecution mode、RunId、log folderだけでした。
- Step 3 commit `672c18a85838e91f63c3247cccc82243037254ff` からStep 7まで、fixture、expected、test registry、Step 3 specification/traceability/oracleに変更はありません。
- git履歴は Step 1 `5f838702` → Step 2 `ebb12310` → Step 3 `672c18a8` → Step 4 `ba66f67a` → Step 5 `78d5a94c` → Step 6 `1d394891` → Step 7 `fdb09187` の順で保持されています。

### Specificationとtraceability

- Test ID 64件、Requirement ID 40件、Defect ID 14/14です。
- 64 tick fixture、64 config fixture、64 expectedを全件読み込み、欠損・空ファイル・基本header違反は0件でした。
- Step 5/6 resultsはどちらも64 Test IDと一致し、Requirement IDの不一致は0件です。
- evidence pathは64/64解決しました。Requirement → Test → fixture/expected → Step 5/6 evidenceの構造的欠損は0件です。
- expectedはStep 3の独立手計算oracleから作られ、test harnessはexpectedを読み、production moduleのactualと比較しています。expected生成にproduction関数を呼ぶ経路は見つかりませんでした。
- test側にはassertion用の派生値計算がありますが、期待値そのものはfixture/expectedから読み込まれています。

### RED/GREEN

- Step 5: PASS 24 / FAIL 0 / XFAIL 1 / XPASS 16 / SKIP 23。
- Step 6: PASS 45 / FAIL 0 / XFAIL 0 / XPASS 0 / SKIP 19。
- FAIL → SKIP移行は0件です。
- Step 8で正式コマンド `powershell -NoProfile -ExecutionPolicy Bypass -File tools/tick_shock/run_all_tests.ps1 -TimeoutSeconds 45 -Phase post-fix` を再実行し、PASS 45 / FAIL 0 / XFAIL 0 / XPASS 0 / SKIP 19を再現しました。
- 8 compile log（研究EA＋7 harness）は保存証跡上すべて0 errors / 0 warningsです。Step 8再実行対象の7 harnessも同結果でした。
- fixture/expectedを実装へ合わせた変更はなく、Step 6 GREENはproduction module・adapter・wiringおよびtest wiringの変更後に得られています。

### IDEAL/REALIZABLE分離と因果性

Step 7の両runは同じEA source、broker/server、M1 driver、期間、6 symbols、strategy parameterを使用し、mode/identityだけを分けています。

| Check | IDEAL | REALIZABLE formal |
|---|---:|---:|
| valid scenario cells | 7,128 | 7,128 |
| entry >= signal + delay 違反 | 0 | 0 |
| entry >= processing + latency 違反 | 6,204 | 0 |
| entry >= eligible 違反 | 0 | 0 |
| entry strictly after signal 違反 | 0 | 0 |
| stale Detection boundary fill | 0 | 0 |
| reversal signal != invalidation | 0 | 0 |
| realized RR < requested RR | 0 | 0 |

IDEALの6,204件はevent-time研究の仕様どおりで、formal feasibilityには使用しません。REALIZABLEのformal causal invariant違反総数は0件です。

### Detector、cluster、RR、broker判定

- 250/500/1,000ms returnは独立列とvalid flagを持ち、`TS-RET-001` と統合run schemaで確認しました。
- market clusterを全symbol・全detector、first-event anchor、2,000ms inclusiveで再計算し15 cluster、ID違反0件でした。
- event duplicateは `(symbol, detector_window_ms, detection_time_msc)` で0件でした。
- 7,128 valid cellsの最小realized RRは1.2、違反0件でした。
- Bid/Ask基準StopsLevelとFreezeLevel分離はproduction module fixtureでPASSしました。

### CSV、outcome、集計

REALIZABLEの19 event rows × 552 scenario cells = 10,488 cellsを再parseしました。

| Status | 独立再計算 | summary |
|---|---:|---:|
| valid | 7,128 | 7,128 |
| invalid broker | 324 | 324 |
| NO_SIGNAL | 3,036 | 3,036 |
| TP_LIMIT | 1,227 | 1,227 |
| SL_GAP | 2,820 | 2,820 |
| TIME_MARKET | 3,081 | 3,081 |

policy maskは `0=2037 / 1=4353 / 2=717 / 3=21` で一致しました。552 scenario summary keysについてvalid/invalid/ExpectancyRの1,656値を再計算し、CSVの6桁丸めに対する許容差 `1e-6` 内で不一致0件でした。OVERALL 4値とFUNNEL 7値も不一致0件です。

REALIZABLE ExpectancyRは `-0.292361643098`、summaryの `-0.292362` と一致しました。market cluster内で相関cellを平均してからcluster間平均を取ると `-0.242732085354`、中央値 `-0.398433015152`、min `-1.054014628788`、max `1.038894606061`、正のcluster平均は3/15です。

## 部分検証のもの

### Production-path coverage

45 PASSのうちMQL unit/integrationはproduction moduleを直接呼びます。Step 7 real-tick runはEAのdispatcher/grid/detector/event/scenario/CSV統合経路を通っています。ただし、次のdeterministic production seamは19 SKIP中10件として残り、特定fixtureによる直接coverageがありません。

- percentile、Robust Z、MAD/noise floor、efficiency、baseline ready: 7件
- commission adapter: 1件
- cross-detector cluster、dedup: 2件

したがってproduction-path coverageは部分検証です。Step 7の統合reconciliationはこの不足を補助しますが、境界条件fixtureの代替ではありません。

### Function catalogとdata structure資料

現在sourceの関数定義は216件ですが、`02_function_catalog.md` はStep 4時点の207件です。差分9件は主に次です。

- EA: `TSRRunMetadataFingerprint`
- serializer: `TSCsvOpenStatusName`、`TSOrderEntryStateName`
- MT5 adapter: `TSMt5ReadRunMetadata`、`TSMt5WriteRunMetadata`、`TSMt5ExistingCsvHeaderMatches`
- order lifecycle: `TSResetOrderFillState`、`TSApplyEntryDeal`、`TSResolveEntryRemainderCancel`

さらに `TSMt5OpenAppendCsv` のsignature/責務はStep 6で拡張されています。`02_data_structures_and_globals.md` にも `ENUM_TS_CSV_OPEN_STATUS`、`ENUM_TS_ORDER_ENTRY_STATE`、`TickShockOrderFillState` のStep 6更新が反映されていません。As-Is資料はStep 4までは網羅、現行HEADには9関数分のdriftがあります。

### Sourceとtester binaryの結合

source、base commit、preset、config、compile log、build 6140、VantageTradingLtd-Live、run commandは一致しました。compile logと現行EX5の時刻も一致し、現行EX5 SHA-256は監査時点で `e9fdb3001b0c6395adff85a87781a4c81ca2cd2e28fac4de5857d093077324b2` です。

ただし、このEX5 hashはStep 7 `source_hashes.txt` に保存されていないため、実行時binaryそのものとの暗号学的な結合は部分検証です。次runではEX5とterminal executableのSHAもrun directoryへ保存する必要があります。

### Tick qualityとbroker spec

- GBPUSDは30,187分中179分がgenerated fallback（0.5930%）でした。
- 他5 symbolsはdiscard warning未観測ですが、全tickがbroker-recordedである証明ではありません。
- 6 symbolsのMarch `StopsLevel` と `FreezeLevel` はすべて0でした。Bid/Ask基準計算はfixtureで検証されていますが、非zero制約の実市場server acceptanceは未観測です。

## 未検証のものとremaining SKIP

19 SKIPは次のとおりで、PASSには含めていません。

- detector: `TS-PCT-001`, `TS-Z-001`, `TS-Z-002`, `TS-EFF-001`, `TS-EFF-002`, `TS-BASE-001`, `TS-BASE-002`
- commission: `TS-COMM-001`
- cluster/dedup: `TS-CLUSTER-002`, `TS-DUP-001`
- server SL/TP: `TS-SERVER-SL-LONG-001`, `TS-SERVER-SL-SHORT-001`, `TS-SERVER-TP-LONG-001`, `TS-SERVER-TP-SHORT-001`
- actual time close/position: `TS-TIME-CLOSE-LONG-001`, `TS-TIME-CLOSE-SHORT-001`, `TS-POSITION-001`
- restart: `TS-RESTART-001`, `TS-RESTART-002`

`TS-PARTIAL-001` はproduction order-fill stateへのdeterministic multi-deal注入ではPASSしましたが、actual terminal/server partial fillは観測していません。研究EAは無注文設計なので、Step 7のtrade CSVは0行であり、OrderCheck/OrderSend、server SL/TP、実commissionの証拠にはなりません。

## RED/XFAIL証跡の制約

Step 5で事前にXFAILが要求された7件（`TS-TIME-001`, `TS-DETECT-001`, `TS-REV-001`, `TS-RET-001`, `TS-CLUSTER-001`, `TS-RR-001`, `TS-BROKER-001`）は、実際にはStep 4 production coreで既にdesired outputを返しXPASSでした。XFAILとして再現したのは `TS-CSV-001` のRunId append衝突だけです。

このため、Step 7の因果不変条件が0であることは実データから検証できますが、「7問題がStep 6修正によってREDからGREENになった」という履歴的主張はできません。Step 4比較は直前pre-refactor sourceとのbehavior preservationを示すため、7修正はStep 4より前のsourceに既に存在したと読むのが整合的です。報告上はこのevidence gapを残します。

## Sample、edge、長期OOS

- event rows: 19
- symbol clusters: 17
- formal independent market clusters: 15
- correlated valid scenario cells: 7,128
- 正のmarket-cluster平均: 3/15
- REALIZABLE grid mean: -0.292361643098 R
- 4 strategyの集計ExpectancyR: detection -0.319703、post-burst -0.339913、pullback -0.218739、reversal -0.196465
- actual commission: 未検証

7,128は取引サンプル数ではありません。15 clusterではedgeの有無を統計的に確定できず、March cellを選ぶと後付けstrategy selectionになります。そのため `EDGE_UNDETERMINED` を維持します。負の記述統計は昇格理由にならず、actual commissionを入れれば改善する根拠もありません。

長期OOSは現時点では進めません。理由は、order lifecycleとcommissionのpromotion blocker、19 SKIP、binary provenanceの不足、15 clusterという小標本、そしてpre-registered strategyがない状態で全gridからcellを選べないためです。

## 次のpromotion gate

長期OOSや本番候補化の前に、次を順に満たす必要があります。

1. 9件のfunction catalog driftとStep 6 data structure資料を更新する。
2. detector/commission/cluster/dedupの10 deterministic SKIPをproduction module経由で解消する。
3. actual terminalでLong/ShortのOrderCheck、OrderSend、full/multiple/partial fill、residual cancel、server SL/TP、time close、deal aggregation、position/restart recoveryを観測する。
4. broker accountのactual commissionを測定し、固定した値で同一のREALIZABLE March runを再集計する。
5. runごとにEX5とterminal executable SHAを保存する。
6. ここまでGREENになった後、Marchのpositive cellを選ばず、単一の事前登録された評価単位または全grid報告規則を確定してから、長期OOS開始の承認を別途得る。

threshold、stop grid、RR、strategy選択、parameter optimizationはこのQAで変更していません。production/test sourceも変更していません。
