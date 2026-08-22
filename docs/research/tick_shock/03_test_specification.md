# Tick-shock研究EA Step 3 テスト仕様

## 仕様の地位

この文書、03_requirements_traceability.md、03_test_oracle_calculation.md、test_cases.csv、各fixture、各expectedを一体としてStep 5テスト実装の唯一の仕様根拠とする。現行production関数の戻り値からexpectedを作ってはならない。Step 3はテストを実行せず、production/test sourceを変更しない。

## テスト目的

- event time、processing time、entry eligibility、実quoteを因果順に固定する。
- detector、状態機械、shadow execution、multicurrency merge、order lifecycleを再現可能な入力で検証する。
- Long/Short対称性、境界値、無効経路、未観測の正直な報告を契約化する。
- refactor後も閾値・scenario grid・価格side・exit modelが意図せず変わらないことを確認する。

## Correctnessとstrategy edge

Correctnessは、同じ入力から定義済み状態・時刻・価格・R・statusが得られることを意味する。PASSしても収益性は示さない。Strategy edgeはREALIZABLE_EAの独立market clusterを統計単位とし、実コスト後outcomeを十分な標本で評価する別工程である。IDEAL_EVENT_STUDY、unit test、stress cell数、同一eventの複数scenarioはedgeの独立標本数へ数えない。

## Test layer

| Layer | 実行境界 | 許可oracle | 禁止事項 |
|---|---|---|---|
| unit | MT5端末I/Oなしの関数/状態 | 本文の数式・静的expected | production出力をgolden生成 |
| production_path_integration | Step 4で抽出するEAと同一engineへsynthetic tick/clock/specを注入 | fixture＋静的expected | test専用strategy shortcut |
| strategy_tester | 実OrderCheck/OrderSend/transaction/server reason | server transactionとdeal history | 未観測をPASS、shadow結果との混同 |
| python | CSV/schema/recount/provenanceの独立再計算 | 標準数学・CSV parser・固定expected | MQL/EX5呼出し、production関数の移植コピー |

## Status定義

| Status | 定義 | 集計 |
|---|---|---|
| PASS | 必須layerを実行し、全expectedがtolerance内、禁止出力0 | PASSへ加算 |
| FAIL | 実行可能だったが1項目以上不一致、例外、欠損、禁止出力あり | FAILへ加算しgate失敗 |
| XFAIL | 既知Defectまたは未抽出production seamにより失敗を事前宣言 | PASSへ含めない。XPASSは理由確認なしに合格化しない |
| SKIP | server/process/history等の必須前提を観測・注入できない | PASS/FAILへ含めずNOT_OBSERVED理由必須 |

current_expected_statusはStep 3時点の予測であり実行結果ではない。

## Requirement IDs

| Requirement ID | Normative requirement |
|---|---|
| REQ-TIME-001 | REALIZABLE_EA must calculate eligibility from both event and processing clocks and never enter before either causal lower bound. |
| REQ-TIME-002 | Requested delays 0/100/250 ms use exact millisecond boundaries; every fill must be a real quote strictly later than the signal tick. |
| REQ-TIME-003 | Submit latency is added to processing time before taking the maximum with event-time delay. |
| REQ-TIME-004 | A grid detection stores boundary/source quote/age separately and never converts a stale or synthetic boundary quote into a fill. |
| REQ-TIME-005 | Failed-shock reversal signal time is the invalidation tick and is immutable. |
| REQ-DET-001 | 250/500/1000 ms log returns use independent exact anchors; a missing anchor is invalid/blank. |
| REQ-DET-002 | Percentile is the documented type-7 linear quantile over half-tick-quantized baseline values. |
| REQ-DET-003 | Robust Z uses median and 1.4826 MAD with an explicit tick-price noise floor. |
| REQ-DET-004 | Directional efficiency is absolute net displacement divided by total absolute path; zero denominator rejects. |
| REQ-DET-005 | Tick intensity is window tick count divided by baseline median and the 1.5 threshold is inclusive. |
| REQ-DET-006 | Move/Spread uses absolute detector-window price move divided by current positive spread and the 4.0 threshold is inclusive. |
| REQ-DET-007 | Current spread/five-minute median spread must be at most 1.5; equality passes. |
| REQ-DET-008 | All six gate boundaries are fixed, inclusive as specified, and represented by an independent truth bitmask without threshold tuning. |
| REQ-DET-009 | At least 300 valid baseline samples are required; 299 rejects and 300 permits gate evaluation. |
| REQ-STATE-001 | The Long production path must reach burst freeze, valid pullback, two-tick reacceleration, and a Long continuation signal. |
| REQ-STATE-002 | The Short production path must be the price-side mirror of the Long path. |
| REQ-STATE-003 | Burst freezes at quiet-time or maximum-age equality and the frozen range/time are not rewritten. |
| REQ-STATE-004 | Pullback 15–35 percent is valid, above 35 below 50 is diagnostic only, and 50 percent invalidates continuation. |
| REQ-STATE-005 | Pullback and reacceleration waits expire at the exact 10000 ms boundary with distinct actions. |
| REQ-EXEC-001 | Spread stress widens Bid/Ask around unchanged Mid while stop risk remains based on unstressed absolute spread. |
| REQ-EXEC-002 | Entry uses the tradable side plus adverse slippage and outward adverse tick rounding for Long/Short. |
| REQ-EXEC-003 | TP rounds outward so realized RR is never below requested 1.2. |
| REQ-EXEC-004 | TP is limit-like: crossing quotes fill at the target barrier. |
| REQ-EXEC-005 | SL is market-like: gap and adverse exit slippage determine fill and loss R without a -1R clamp. |
| REQ-EXEC-006 | Hard time exit occurs at 120-second equality on the current tradable Bid/Ask side. |
| REQ-EXEC-007 | Commission R is round-turn account-currency commission divided by the one-lot structural SL loss and is deducted once. |
| REQ-EXEC-008 | StopsLevel uses current Bid for Long and current Ask for Short; FreezeLevel is a separate diagnostic. |
| REQ-EXEC-009 | Cost/range policy gates produce a two-bit label and cannot invalidate a broker-feasible barrier outcome. |
| REQ-MULTI-001 | All ticks sharing symbol/time_msc form one group; only its final quote closes an equal grid boundary. |
| REQ-MULTI-002 | Global ordering is time, configured symbol index, sequence; watermark lag becomes explicit processing latency in REALIZABLE_EA. |
| REQ-MULTI-003 | Market clusters span all symbols/detectors and use a first-event anchor with inclusive 2000 ms boundary. |
| REQ-MULTI-004 | Event rows, symbol clusters, market clusters, and exact duplicate events are counted separately. |
| REQ-CSV-001 | A repeated RunId must not silently mix distinct attempts; collision or unique attempt isolation is mandatory. |
| REQ-CSV-002 | CSV scenario reparse must exactly reproduce summary valid/invalid counts and aggregate R. |
| REQ-PROV-001 | Formal evidence must bind commit/source/set/terminal/broker/chart/mode provenance; mismatched source is ineligible. |
| REQ-ORDER-001 | Entry fills aggregate every DEAL_ENTRY_IN by volume; no close/exit state follows the first partial deal. |
| REQ-ORDER-002 | A terminal residual cancel resolves the request while preserving filled quantity and zero active remaining quantity. |
| REQ-ORDER-003 | Server SL/TP PASS requires an observed deal with matching reason for both Long and Short. |
| REQ-ORDER-004 | Long/Short time close submits and aggregates the entire managed exit and is not mislabeled as a server barrier. |
| REQ-ORDER-005 | Position/restart recovery restores all manageable fields; an un-injected restart is SKIP/NOT_OBSERVED and never PASS. |

## Fixture/expected contract

- 各Test IDは tests/tick_shock/fixtures/<TEST_ID>_ticks.csv、同名_config.csv、tests/tick_shock/expected/<TEST_ID>_expected.csvを必ず持つ。
- tick列は sequence,symbol,time_msc,bid,ask,processing_msc,note の固定順。sequenceはfixture内の到着順、time_mscはmarket event time、processing_mscはEA認識clock。
- config列は key,value,unit,note。全configは production_function_used_for_expected=false を含む。
- expected列は field,expected_value,tolerance,unit,note。空欄は0ではない。文字列と整数のtolerance 0は完全一致を意味する。
- 入力価格はdecimal文字列として読み、比較時だけ明記toleranceを用いる。CSV row順を時系列の代用にせずsequenceとsymbol/time規則を使う。

## Test cases

### A. 時刻・因果性

| Test ID / Req / Defect | 初期状態 | 入力 | 期待状態遷移・出力 | 禁止される出力 | current → desired | 独立oracle |
|---|---|---|---|---|---|---|
| TS-TIME-001<br>REQ-TIME-001<br>TS-KD-001 | signal未登録・entry未fill | tests/tick_shock/fixtures/TS-TIME-001_ticks.csv + TS-TIME-001_config.csv | arm → early quote拒否 → 最初のeligible real quote。tests/tick_shock/expected/TS-TIME-001_expected.csvの全field | processing/eligible以前、signal同一tick、synthetic時刻でのentry | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → REALIZABLE_EA rejects all quotes before processing and uses the first quote at or after eligibility. | 03 oracle §Clock。production関数不使用 |
| TS-TIME-002<br>REQ-TIME-002<br>NONE | signal未登録・entry未fill | tests/tick_shock/fixtures/TS-TIME-002_ticks.csv + TS-TIME-002_config.csv | arm → early quote拒否 → 最初のeligible real quote。tests/tick_shock/expected/TS-TIME-002_expected.csvの全field | processing/eligible以前、signal同一tick、synthetic時刻でのentry | 現行helper/定義は一致予定。Step 3では未実行 → Delay 0 still requires a real quote strictly after the signal tick. | 03 oracle §Clock。production関数不使用 |
| TS-TIME-003<br>REQ-TIME-002<br>NONE | signal未登録・entry未fill | tests/tick_shock/fixtures/TS-TIME-003_ticks.csv + TS-TIME-003_config.csv | arm → early quote拒否 → 最初のeligible real quote。tests/tick_shock/expected/TS-TIME-003_expected.csvの全field | processing/eligible以前、signal同一tick、synthetic時刻でのentry | 現行helper/定義は一致予定。Step 3では未実行 → Delay 100 ms accepts equality and rejects boundary minus one. | 03 oracle §Clock。production関数不使用 |
| TS-TIME-004<br>REQ-TIME-002<br>NONE | signal未登録・entry未fill | tests/tick_shock/fixtures/TS-TIME-004_ticks.csv + TS-TIME-004_config.csv | arm → early quote拒否 → 最初のeligible real quote。tests/tick_shock/expected/TS-TIME-004_expected.csvの全field | processing/eligible以前、signal同一tick、synthetic時刻でのentry | 現行helper/定義は一致予定。Step 3では未実行 → Delay 250 ms accepts equality and rejects boundary minus one. | 03 oracle §Clock。production関数不使用 |
| TS-TIME-005<br>REQ-TIME-003<br>NONE | signal未登録・entry未fill | tests/tick_shock/fixtures/TS-TIME-005_ticks.csv + TS-TIME-005_config.csv | arm → early quote拒否 → 最初のeligible real quote。tests/tick_shock/expected/TS-TIME-005_expected.csvの全field | processing/eligible以前、signal同一tick、synthetic時刻でのentry | 現行helper/定義は一致予定。Step 3では未実行 → Submit latency is added to processing and can dominate requested delay. | 03 oracle §Clock。production関数不使用 |
| TS-TIME-006<br>REQ-TIME-002<br>NONE | signal未登録・entry未fill | tests/tick_shock/fixtures/TS-TIME-006_ticks.csv + TS-TIME-006_config.csv | arm → early quote拒否 → 最初のeligible real quote。tests/tick_shock/expected/TS-TIME-006_expected.csvの全field | processing/eligible以前、signal同一tick、synthetic時刻でのentry | 現行helper/定義は一致予定。Step 3では未実行 → If no tick exists at eligibility the first later real tick is used. | 03 oracle §Clock。production関数不使用 |
| TS-DETECT-001<br>REQ-TIME-004<br>TS-KD-002 | fixture記載のgrid/baseline初期状態 | tests/tick_shock/fixtures/TS-DETECT-001_ticks.csv + TS-DETECT-001_config.csv | tick/grid → sample/baseline → gateまたは明示reject。tests/tick_shock/expected/TS-DETECT-001_expected.csvの全field | processing/eligible以前、signal同一tick、synthetic時刻でのentry | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → A stale grid quote can detect but cannot fill Detection delay 0 at the boundary. | 03 oracle §Clock。production関数不使用 |
| TS-MERGE-001<br>REQ-TIME-001<br>TS-KD-001 | signal未登録・entry未fill | tests/tick_shock/fixtures/TS-MERGE-001_ticks.csv + TS-MERGE-001_config.csv | arm → early quote拒否 → 最初のeligible real quote。tests/tick_shock/expected/TS-MERGE-001_expected.csvの全field | processing/eligible以前、signal同一tick、synthetic時刻でのentry | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → A watermark-released old signal cannot use a quote earlier than its 1600 ms processing time. | 03 oracle §Clock。production関数不使用 |
| TS-REV-001<br>REQ-TIME-005<br>TS-KD-003 | signal未登録・entry未fill | tests/tick_shock/fixtures/TS-REV-001_ticks.csv + TS-REV-001_config.csv | arm → early quote拒否 → 最初のeligible real quote。tests/tick_shock/expected/TS-REV-001_expected.csvの全field | processing/eligible以前、signal同一tick、synthetic時刻でのentry | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → Failed-shock reversal signal remains the invalidation tick and entry uses a later tick. | 03 oracle §Clock。production関数不使用 |
### B. detector

| Test ID / Req / Defect | 初期状態 | 入力 | 期待状態遷移・出力 | 禁止される出力 | current → desired | 独立oracle |
|---|---|---|---|---|---|---|
| TS-RET-001<br>REQ-DET-001<br>TS-KD-004 | fixture記載のgrid/baseline初期状態 | tests/tick_shock/fixtures/TS-RET-001_ticks.csv + TS-RET-001_config.csv | tick/grid → sample/baseline → gateまたは明示reject。tests/tick_shock/expected/TS-RET-001_expected.csvの全field | anchor補間・0埋め・分母0計算・閾値緩和・failed sampleのevent化 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → 250 500 and 1000 ms log returns use independent exact anchors. | 03 oracle §Detector。production関数不使用 |
| TS-RET-002<br>REQ-DET-001<br>NONE | fixture記載のgrid/baseline初期状態 | tests/tick_shock/fixtures/TS-RET-002_ticks.csv + TS-RET-002_config.csv | tick/grid → sample/baseline → gateまたは明示reject。tests/tick_shock/expected/TS-RET-002_expected.csvの全field | anchor補間・0埋め・分母0計算・閾値緩和・failed sampleのevent化 | 現行helper/定義は一致予定。Step 3では未実行 → Missing exact anchor yields invalid and blank output rather than zero. | 03 oracle §Detector。production関数不使用 |
| TS-PCT-001<br>REQ-DET-002<br>NONE | fixture記載のgrid/baseline初期状態 | tests/tick_shock/fixtures/TS-PCT-001_ticks.csv + TS-PCT-001_config.csv | tick/grid → sample/baseline → gateまたは明示reject。tests/tick_shock/expected/TS-PCT-001_expected.csvの全field | anchor補間・0埋め・分母0計算・閾値緩和・failed sampleのevent化 | 現行helper/定義は一致予定。Step 3では未実行 → Type-7 linear percentile on half-tick bins is independently defined. | 03 oracle §Detector。production関数不使用 |
| TS-Z-001<br>REQ-DET-003<br>NONE | fixture記載のgrid/baseline初期状態 | tests/tick_shock/fixtures/TS-Z-001_ticks.csv + TS-Z-001_config.csv | tick/grid → sample/baseline → gateまたは明示reject。tests/tick_shock/expected/TS-Z-001_expected.csvの全field | anchor補間・0埋め・分母0計算・閾値緩和・failed sampleのevent化 | 現行helper/定義は一致予定。Step 3では未実行 → Robust Z uses median and 1.4826 times MAD. | 03 oracle §Detector。production関数不使用 |
| TS-Z-002<br>REQ-DET-003<br>NONE | fixture記載のgrid/baseline初期状態 | tests/tick_shock/fixtures/TS-Z-002_ticks.csv + TS-Z-002_config.csv | tick/grid → sample/baseline → gateまたは明示reject。tests/tick_shock/expected/TS-Z-002_expected.csvの全field | anchor補間・0埋め・分母0計算・閾値緩和・failed sampleのevent化 | 現行helper/定義は一致予定。Step 3では未実行 → MAD zero uses the configured price noise floor and remains finite. | 03 oracle §Detector。production関数不使用 |
| TS-EFF-001<br>REQ-DET-004<br>NONE | fixture記載のgrid/baseline初期状態 | tests/tick_shock/fixtures/TS-EFF-001_ticks.csv + TS-EFF-001_config.csv | tick/grid → sample/baseline → gateまたは明示reject。tests/tick_shock/expected/TS-EFF-001_expected.csvの全field | anchor補間・0埋め・分母0計算・閾値緩和・failed sampleのevent化 | 現行helper/定義は一致予定。Step 3では未実行 → Efficiency is net displacement divided by absolute path length. | 03 oracle §Detector。production関数不使用 |
| TS-EFF-002<br>REQ-DET-004<br>NONE | fixture記載のgrid/baseline初期状態 | tests/tick_shock/fixtures/TS-EFF-002_ticks.csv + TS-EFF-002_config.csv | tick/grid → sample/baseline → gateまたは明示reject。tests/tick_shock/expected/TS-EFF-002_expected.csvの全field | anchor補間・0埋め・分母0計算・閾値緩和・failed sampleのevent化 | 現行helper/定義は一致予定。Step 3では未実行 → Zero path denominator rejects the shock. | 03 oracle §Detector。production関数不使用 |
| TS-INT-001<br>REQ-DET-005<br>NONE | fixture記載のgrid/baseline初期状態 | tests/tick_shock/fixtures/TS-INT-001_ticks.csv + TS-INT-001_config.csv | tick/grid → sample/baseline → gateまたは明示reject。tests/tick_shock/expected/TS-INT-001_expected.csvの全field | anchor補間・0埋め・分母0計算・閾値緩和・failed sampleのevent化 | 現行helper/定義は一致予定。Step 3では未実行 → Tick intensity threshold is inclusive at 1.5. | 03 oracle §Detector。production関数不使用 |
| TS-MOVE-001<br>REQ-DET-006<br>NONE | fixture記載のgrid/baseline初期状態 | tests/tick_shock/fixtures/TS-MOVE-001_ticks.csv + TS-MOVE-001_config.csv | tick/grid → sample/baseline → gateまたは明示reject。tests/tick_shock/expected/TS-MOVE-001_expected.csvの全field | anchor補間・0埋め・分母0計算・閾値緩和・failed sampleのevent化 | 現行helper/定義は一致予定。Step 3では未実行 → Move over spread threshold is inclusive at 4.0. | 03 oracle §Detector。production関数不使用 |
| TS-SPREAD-001<br>REQ-DET-007<br>NONE | fixture記載のgrid/baseline初期状態 | tests/tick_shock/fixtures/TS-SPREAD-001_ticks.csv + TS-SPREAD-001_config.csv | tick/grid → sample/baseline → gateまたは明示reject。tests/tick_shock/expected/TS-SPREAD-001_expected.csvの全field | anchor補間・0埋め・分母0計算・閾値緩和・failed sampleのevent化 | 現行helper/定義は一致予定。Step 3では未実行 → Spread ratio ceiling is inclusive at 1.5. | 03 oracle §Detector。production関数不使用 |
| TS-GATE-001<br>REQ-DET-008<br>NONE | fixture記載のgrid/baseline初期状態 | tests/tick_shock/fixtures/TS-GATE-001_ticks.csv + TS-GATE-001_config.csv | tick/grid → sample/baseline → gateまたは明示reject。tests/tick_shock/expected/TS-GATE-001_expected.csvの全field | anchor補間・0埋め・分母0計算・閾値緩和・failed sampleのevent化 | 現行helper/定義は一致予定。Step 3では未実行 → All six detector gates define before equal and after behavior without market fitting. | 03 oracle §Detector。production関数不使用 |
| TS-BASE-001<br>REQ-DET-009<br>TS-KD-008 | fixture記載のgrid/baseline初期状態 | tests/tick_shock/fixtures/TS-BASE-001_ticks.csv + TS-BASE-001_config.csv | tick/grid → sample/baseline → gateまたは明示reject。tests/tick_shock/expected/TS-BASE-001_expected.csvの全field | anchor補間・0埋め・分母0計算・閾値緩和・failed sampleのevent化 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → 299 valid samples are insufficient when the minimum is 300. | 03 oracle §Detector。production関数不使用 |
| TS-BASE-002<br>REQ-DET-009<br>TS-KD-008 | fixture記載のgrid/baseline初期状態 | tests/tick_shock/fixtures/TS-BASE-002_ticks.csv + TS-BASE-002_config.csv | tick/grid → sample/baseline → gateまたは明示reject。tests/tick_shock/expected/TS-BASE-002_expected.csvの全field | anchor補間・0埋め・分母0計算・閾値緩和・failed sampleのevent化 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → Exactly 300 valid samples make baseline evaluation eligible. | 03 oracle §Detector。production関数不使用 |
### C. state machine

| Test ID / Req / Defect | 初期状態 | 入力 | 期待状態遷移・出力 | 禁止される出力 | current → desired | 独立oracle |
|---|---|---|---|---|---|---|
| TS-STATE-LONG-001<br>REQ-STATE-001<br>TS-KD-008 | configのinitial_stateまたは新規event | tests/tick_shock/fixtures/TS-STATE-LONG-001_ticks.csv + TS-STATE-LONG-001_config.csv | config初期state → expected CSVのaction/state。tests/tick_shock/expected/TS-STATE-LONG-001_expected.csvの全field | 凍結値の再探索、単一tick reacceleration、境界の排他的扱い | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → Long burst to valid pullback to two-tick reacceleration reaches a continuation signal. | 03 oracle §State。production関数不使用 |
| TS-STATE-SHORT-001<br>REQ-STATE-002<br>TS-KD-008 | configのinitial_stateまたは新規event | tests/tick_shock/fixtures/TS-STATE-SHORT-001_ticks.csv + TS-STATE-SHORT-001_config.csv | config初期state → expected CSVのaction/state。tests/tick_shock/expected/TS-STATE-SHORT-001_expected.csvの全field | 凍結値の再探索、単一tick reacceleration、境界の排他的扱い | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → Short path mirrors Long through burst pullback and reacceleration. | 03 oracle §State。production関数不使用 |
| TS-BURST-001<br>REQ-STATE-003<br>NONE | configのinitial_stateまたは新規event | tests/tick_shock/fixtures/TS-BURST-001_ticks.csv + TS-BURST-001_config.csv | config初期state → expected CSVのaction/state。tests/tick_shock/expected/TS-BURST-001_expected.csvの全field | 凍結値の再探索、単一tick reacceleration、境界の排他的扱い | 現行helper/定義は一致予定。Step 3では未実行 → Burst quiet threshold freezes at exactly 300 ms since last extreme. | 03 oracle §State。production関数不使用 |
| TS-BURST-002<br>REQ-STATE-003<br>NONE | configのinitial_stateまたは新規event | tests/tick_shock/fixtures/TS-BURST-002_ticks.csv + TS-BURST-002_config.csv | config初期state → expected CSVのaction/state。tests/tick_shock/expected/TS-BURST-002_expected.csvの全field | 凍結値の再探索、単一tick reacceleration、境界の排他的扱い | 現行helper/定義は一致予定。Step 3では未実行 → Burst maximum freezes at exactly 3000 ms even if quiet timeout is disabled. | 03 oracle §State。production関数不使用 |
| TS-PB-001<br>REQ-STATE-004<br>NONE | configのinitial_stateまたは新規event | tests/tick_shock/fixtures/TS-PB-001_ticks.csv + TS-PB-001_config.csv | config初期state → expected CSVのaction/state。tests/tick_shock/expected/TS-PB-001_expected.csvの全field | 凍結値の再探索、単一tick reacceleration、境界の排他的扱い | 現行helper/定義は一致予定。Step 3では未実行 → Retracement below 15 percent remains WAIT_PULLBACK. | 03 oracle §State。production関数不使用 |
| TS-PB-002<br>REQ-STATE-004<br>NONE | configのinitial_stateまたは新規event | tests/tick_shock/fixtures/TS-PB-002_ticks.csv + TS-PB-002_config.csv | config初期state → expected CSVのaction/state。tests/tick_shock/expected/TS-PB-002_expected.csvの全field | 凍結値の再探索、単一tick reacceleration、境界の排他的扱い | 現行helper/定義は一致予定。Step 3では未実行 → Retracement lower and upper bounds 15 and 35 percent are valid and inclusive. | 03 oracle §State。production関数不使用 |
| TS-PB-003<br>REQ-STATE-004<br>NONE | configのinitial_stateまたは新規event | tests/tick_shock/fixtures/TS-PB-003_ticks.csv + TS-PB-003_config.csv | config初期state → expected CSVのaction/state。tests/tick_shock/expected/TS-PB-003_expected.csvの全field | 凍結値の再探索、単一tick reacceleration、境界の排他的扱い | 現行helper/定義は一致予定。Step 3では未実行 → Retracement just above 35 but below 50 is diagnostic too-deep and not a valid pullback. | 03 oracle §State。production関数不使用 |
| TS-INVALID-001<br>REQ-STATE-004<br>TS-KD-003 | configのinitial_stateまたは新規event | tests/tick_shock/fixtures/TS-INVALID-001_ticks.csv + TS-INVALID-001_config.csv | config初期state → expected CSVのaction/state。tests/tick_shock/expected/TS-INVALID-001_expected.csvの全field | 凍結値の再探索、単一tick reacceleration、境界の排他的扱い | 現行helper/定義は一致予定。Step 3では未実行 → Retracement exactly 50 percent invalidates continuation at that tick. | 03 oracle §State。production関数不使用 |
### A. 時刻・因果性

| Test ID / Req / Defect | 初期状態 | 入力 | 期待状態遷移・出力 | 禁止される出力 | current → desired | 独立oracle |
|---|---|---|---|---|---|---|
| TS-TIMEOUT-001<br>REQ-STATE-005<br>NONE | configのinitial_stateまたは新規event | tests/tick_shock/fixtures/TS-TIMEOUT-001_ticks.csv + TS-TIMEOUT-001_config.csv | config初期state → expected CSVのaction/state。tests/tick_shock/expected/TS-TIMEOUT-001_expected.csvの全field | processing/eligible以前、signal同一tick、synthetic時刻でのentry | 現行helper/定義は一致予定。Step 3では未実行 → Pullback wait times out at exactly 10000 ms from burst end. | 03 oracle §Clock。production関数不使用 |
### C. state machine

| Test ID / Req / Defect | 初期状態 | 入力 | 期待状態遷移・出力 | 禁止される出力 | current → desired | 独立oracle |
|---|---|---|---|---|---|---|
| TS-NOREACCEL-001<br>REQ-STATE-005<br>NONE | configのinitial_stateまたは新規event | tests/tick_shock/fixtures/TS-NOREACCEL-001_ticks.csv + TS-NOREACCEL-001_config.csv | config初期state → expected CSVのaction/state。tests/tick_shock/expected/TS-NOREACCEL-001_expected.csvの全field | 凍結値の再探索、単一tick reacceleration、境界の排他的扱い | 現行helper/定義は一致予定。Step 3では未実行 → Valid pullback without two breakout confirmations expires at the same wait boundary. | 03 oracle §State。production関数不使用 |
### D. execution

| Test ID / Req / Defect | 初期状態 | 入力 | 期待状態遷移・出力 | 禁止される出力 | current → desired | 独立oracle |
|---|---|---|---|---|---|---|
| TS-EXEC-LONG-001<br>REQ-EXEC-001<br>TS-KD-008 | broker-feasible候補またはpending scenario | tests/tick_shock/fixtures/TS-EXEC-LONG-001_ticks.csv + TS-EXEC-LONG-001_config.csv | pending candidate → activeまたは明示invalid。tests/tick_shock/expected/TS-EXEC-LONG-001_expected.csvの全field | Mid約定、stressでrisk拡大、nearest TP、SLを-1R固定、policyによるoutcome抹消 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → Long spread stress widens only Bid Ask while risk stays based on unstressed spread. | 03 oracle §Execution。production関数不使用 |
| TS-EXEC-SHORT-001<br>REQ-EXEC-002<br>TS-KD-008 | broker-feasible候補またはpending scenario | tests/tick_shock/fixtures/TS-EXEC-SHORT-001_ticks.csv + TS-EXEC-SHORT-001_config.csv | pending candidate → activeまたは明示invalid。tests/tick_shock/expected/TS-EXEC-SHORT-001_expected.csvの全field | Mid約定、stressでrisk拡大、nearest TP、SLを-1R固定、policyによるoutcome抹消 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → Short spread stress and adverse entry rounding mirror Long with fixed absolute risk. | 03 oracle §Execution。production関数不使用 |
| TS-RR-001<br>REQ-EXEC-003<br>TS-KD-006 | broker-feasible候補またはpending scenario | tests/tick_shock/fixtures/TS-RR-001_ticks.csv + TS-RR-001_config.csv | pending candidate → activeまたは明示invalid。tests/tick_shock/expected/TS-RR-001_expected.csvの全field | Mid約定、stressでrisk拡大、nearest TP、SLを-1R固定、policyによるoutcome抹消 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → Outward target rounding never reduces requested 1.2R. | 03 oracle §Execution。production関数不使用 |
| TS-TP-001<br>REQ-EXEC-004<br>NONE | entry済みactive scenario | tests/tick_shock/fixtures/TS-TP-001_ticks.csv + TS-TP-001_config.csv | active → TP_LIMIT/SL_GAP/TIME_MARKET。tests/tick_shock/expected/TS-TP-001_expected.csvの全field | Mid約定、stressでrisk拡大、nearest TP、SLを-1R固定、policyによるoutcome抹消 | 現行helper/定義は一致予定。Step 3では未実行 → A price gap through TP fills at the TP barrier like a limit. | 03 oracle §Execution。production関数不使用 |
| TS-SL-001<br>REQ-EXEC-005<br>NONE | entry済みactive scenario | tests/tick_shock/fixtures/TS-SL-001_ticks.csv + TS-SL-001_config.csv | active → TP_LIMIT/SL_GAP/TIME_MARKET。tests/tick_shock/expected/TS-SL-001_expected.csvの全field | Mid約定、stressでrisk拡大、nearest TP、SLを-1R固定、policyによるoutcome抹消 | 現行helper/定義は一致予定。Step 3では未実行 → Long stop gaps use first Bid beyond SL plus adverse exit slippage. | 03 oracle §Execution。production関数不使用 |
| TS-SL-002<br>REQ-EXEC-005<br>NONE | entry済みactive scenario | tests/tick_shock/fixtures/TS-SL-002_ticks.csv + TS-SL-002_config.csv | active → TP_LIMIT/SL_GAP/TIME_MARKET。tests/tick_shock/expected/TS-SL-002_expected.csvの全field | Mid約定、stressでrisk拡大、nearest TP、SLを-1R固定、policyによるoutcome抹消 | 現行helper/定義は一致予定。Step 3では未実行 → Short stop gaps use first Ask beyond SL plus adverse exit slippage. | 03 oracle §Execution。production関数不使用 |
### A. 時刻・因果性

| Test ID / Req / Defect | 初期状態 | 入力 | 期待状態遷移・出力 | 禁止される出力 | current → desired | 独立oracle |
|---|---|---|---|---|---|---|
| TS-TIMEEXIT-001<br>REQ-EXEC-006<br>NONE | entry済みactive scenario | tests/tick_shock/fixtures/TS-TIMEEXIT-001_ticks.csv + TS-TIMEEXIT-001_config.csv | active → TP_LIMIT/SL_GAP/TIME_MARKET。tests/tick_shock/expected/TS-TIMEEXIT-001_expected.csvの全field | processing/eligible以前、signal同一tick、synthetic時刻でのentry | 現行helper/定義は一致予定。Step 3では未実行 → Hard time exit occurs at equality and uses current tradable Bid. | 03 oracle §Clock。production関数不使用 |
### D. execution

| Test ID / Req / Defect | 初期状態 | 入力 | 期待状態遷移・出力 | 禁止される出力 | current → desired | 独立oracle |
|---|---|---|---|---|---|---|
| TS-COMM-001<br>REQ-EXEC-007<br>NONE | entry済みactive scenario | tests/tick_shock/fixtures/TS-COMM-001_ticks.csv + TS-COMM-001_config.csv | gross outcome → commission換算 → net R。tests/tick_shock/expected/TS-COMM-001_expected.csvの全field | Mid約定、stressでrisk拡大、nearest TP、SLを-1R固定、policyによるoutcome抹消 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → Commission R is round-turn commission divided by one-lot SL loss and reduces net R once. | 03 oracle §Execution。production関数不使用 |
| TS-BROKER-001<br>REQ-EXEC-008<br>TS-KD-007 | broker-feasible候補またはpending scenario | tests/tick_shock/fixtures/TS-BROKER-001_ticks.csv + TS-BROKER-001_config.csv | pending candidate → activeまたは明示invalid。tests/tick_shock/expected/TS-BROKER-001_expected.csvの全field | Mid約定、stressでrisk拡大、nearest TP、SLを-1R固定、policyによるoutcome抹消 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → StopsLevel is checked from current Bid for Long and current Ask for Short. | 03 oracle §Execution。production関数不使用 |
| TS-POLICY-001<br>REQ-EXEC-009<br>NONE | broker-feasible候補またはpending scenario | tests/tick_shock/fixtures/TS-POLICY-001_ticks.csv + TS-POLICY-001_config.csv | pending candidate → activeまたは明示invalid。tests/tick_shock/expected/TS-POLICY-001_expected.csvの全field | Mid約定、stressでrisk拡大、nearest TP、SLを-1R固定、policyによるoutcome抹消 | 現行helper/定義は一致予定。Step 3では未実行 → Cost and range policy gates are a two-bit label and never erase broker-feasible outcomes. | 03 oracle §Execution。production関数不使用 |
### E. multicurrency

| Test ID / Req / Defect | 初期状態 | 入力 | 期待状態遷移・出力 | 禁止される出力 | current → desired | 独立oracle |
|---|---|---|---|---|---|---|
| TS-SAMEMSC-001<br>REQ-MULTI-001<br>TS-KD-008 | 空のqueue/cluster/event registry | tests/tick_shock/fixtures/TS-SAMEMSC-001_ticks.csv + TS-SAMEMSC-001_config.csv | pending → deterministic sort/watermark release。tests/tick_shock/expected/TS-SAMEMSC-001_expected.csvの全field | same-ms分割、event-time逆転、symbol clusterを統計nに使用 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → Same-symbol same-millisecond group closes the grid with its final quote. | 03 oracle §Merge/cluster。production関数不使用 |
| TS-MULTI-001<br>REQ-MULTI-002<br>TS-KD-008 | 空のqueue/cluster/event registry | tests/tick_shock/fixtures/TS-MULTI-001_ticks.csv + TS-MULTI-001_config.csv | pending → deterministic sort/watermark release。tests/tick_shock/expected/TS-MULTI-001_expected.csvの全field | same-ms分割、event-time逆転、symbol clusterを統計nに使用 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → Simultaneous currencies preserve deterministic time symbol sequence order. | 03 oracle §Merge/cluster。production関数不使用 |
| TS-MERGE-002<br>REQ-MULTI-002<br>TS-KD-014 | 空のqueue/cluster/event registry | tests/tick_shock/fixtures/TS-MERGE-002_ticks.csv + TS-MERGE-002_config.csv | pending → deterministic sort/watermark release。tests/tick_shock/expected/TS-MERGE-002_expected.csvの全field | same-ms分割、event-time逆転、symbol clusterを統計nに使用 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → Slow currency holds active currency until frontier advances and delay is processing latency. | 03 oracle §Merge/cluster。production関数不使用 |
| TS-CLUSTER-001<br>REQ-MULTI-003<br>TS-KD-005 | 空のqueue/cluster/event registry | tests/tick_shock/fixtures/TS-CLUSTER-001_ticks.csv + TS-CLUSTER-001_config.csv | event input → cluster/dedup counters。tests/tick_shock/expected/TS-CLUSTER-001_expected.csvの全field | same-ms分割、event-time逆転、symbol clusterを統計nに使用 | 現行helper/定義は一致予定。Step 3では未実行 → Cross-symbol market cluster uses first-event anchor with inclusive 2000 ms boundary. | 03 oracle §Merge/cluster。production関数不使用 |
| TS-CLUSTER-002<br>REQ-MULTI-004<br>TS-KD-005 | 空のqueue/cluster/event registry | tests/tick_shock/fixtures/TS-CLUSTER-002_ticks.csv + TS-CLUSTER-002_config.csv | event input → cluster/dedup counters。tests/tick_shock/expected/TS-CLUSTER-002_expected.csvの全field | same-ms分割、event-time逆転、symbol clusterを統計nに使用 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → Different detectors for one shock produce separate event rows but one market cluster. | 03 oracle §Merge/cluster。production関数不使用 |
| TS-DUP-001<br>REQ-MULTI-004<br>TS-KD-008 | 空のqueue/cluster/event registry | tests/tick_shock/fixtures/TS-DUP-001_ticks.csv + TS-DUP-001_config.csv | event input → cluster/dedup counters。tests/tick_shock/expected/TS-DUP-001_expected.csvの全field | same-ms分割、event-time逆転、symbol clusterを統計nに使用 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → Exact same symbol detector and detection time is emitted once. | 03 oracle §Merge/cluster。production関数不使用 |
### G. evidence/CSV

| Test ID / Req / Defect | 初期状態 | 入力 | 期待状態遷移・出力 | 禁止される出力 | current → desired | 独立oracle |
|---|---|---|---|---|---|---|
| TS-CSV-001<br>REQ-CSV-001<br>TS-KD-012 | 分離された空のanalysis workspace | tests/tick_shock/fixtures/TS-CSV-001_ticks.csv + TS-CSV-001_config.csv | input records → independent Python validation。tests/tick_shock/expected/TS-CSV-001_expected.csvの全field | 異なるrunのappend混在、集計不一致、SHA不一致evidenceの昇格 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → A second run with the same RunId must not silently append into the first run files. | 03 oracle §Evidence。production関数不使用 |
| TS-CSV-002<br>REQ-CSV-002<br>NONE | 分離された空のanalysis workspace | tests/tick_shock/fixtures/TS-CSV-002_ticks.csv + TS-CSV-002_config.csv | input records → independent Python validation。tests/tick_shock/expected/TS-CSV-002_expected.csvの全field | 異なるrunのappend混在、集計不一致、SHA不一致evidenceの昇格 | 現行helper/定義は一致予定。Step 3では未実行 → Reparsed scenario cells exactly match summary valid invalid and R totals. | 03 oracle §Evidence。production関数不使用 |
| TS-PROV-001<br>REQ-PROV-001<br>TS-KD-013 | 分離された空のanalysis workspace | tests/tick_shock/fixtures/TS-PROV-001_ticks.csv + TS-PROV-001_config.csv | input records → independent Python validation。tests/tick_shock/expected/TS-PROV-001_expected.csvの全field | 異なるrunのappend混在、集計不一致、SHA不一致evidenceの昇格 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → Evidence is eligible only when source config terminal broker and chart provenance match. | 03 oracle §Evidence。production関数不使用 |
### F. order lifecycle

| Test ID / Req / Defect | 初期状態 | 入力 | 期待状態遷移・出力 | 禁止される出力 | current → desired | 独立oracle |
|---|---|---|---|---|---|---|
| TS-ORDER-001<br>REQ-ORDER-001<br>NONE | SEND_ENTRY・deal未集約 | tests/tick_shock/fixtures/TS-ORDER-001_ticks.csv + TS-ORDER-001_config.csv | request → 1..N fills/cancel → resolved entry。tests/tick_shock/expected/TS-ORDER-001_expected.csvの全field | first partial dealでclose、未観測をPASS、他Magic/positionの集約 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → One entry deal fills requested volume and advances only after resolution. | 03 oracle §Order。production関数不使用 |
| TS-ORDER-002<br>REQ-ORDER-001<br>NONE | SEND_ENTRY・deal未集約 | tests/tick_shock/fixtures/TS-ORDER-002_ticks.csv + TS-ORDER-002_config.csv | request → 1..N fills/cancel → resolved entry。tests/tick_shock/expected/TS-ORDER-002_expected.csvの全field | first partial dealでclose、未観測をPASS、他Magic/positionの集約 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → Multiple entry deals are volume-weighted and all included. | 03 oracle §Order。production関数不使用 |
| TS-PARTIAL-001<br>REQ-ORDER-001<br>TS-KD-009 | SEND_ENTRY・deal未集約 | tests/tick_shock/fixtures/TS-PARTIAL-001_ticks.csv + TS-PARTIAL-001_config.csv | request → 1..N fills/cancel → resolved entry。tests/tick_shock/expected/TS-PARTIAL-001_expected.csvの全field | first partial dealでclose、未観測をPASS、他Magic/positionの集約 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → Partial fill remains entry-pending until all entry deals are aggregated. | 03 oracle §Order。production関数不使用 |
| TS-ORDER-003<br>REQ-ORDER-002<br>NONE | SEND_ENTRY・deal未集約 | tests/tick_shock/fixtures/TS-ORDER-003_ticks.csv + TS-ORDER-003_config.csv | request → 1..N fills/cancel → resolved entry。tests/tick_shock/expected/TS-ORDER-003_expected.csvの全field | first partial dealでclose、未観測をPASS、他Magic/positionの集約 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → Residual cancel resolves entry after retaining filled volume and zeroing remaining active quantity. | 03 oracle §Order。production関数不使用 |
| TS-SERVER-SL-LONG-001<br>REQ-ORDER-003<br>TS-KD-011 | SEND_ENTRY・deal未集約 | tests/tick_shock/fixtures/TS-SERVER-SL-LONG-001_ticks.csv + TS-SERVER-SL-LONG-001_config.csv | entry fill → observed exit deal → aggregate。tests/tick_shock/expected/TS-SERVER-SL-LONG-001_expected.csvの全field | first partial dealでclose、未観測をPASS、他Magic/positionの集約 | 外部server/process観測がなければSKIP予定 → Long server SL observation requires a real tester deal reason SL. | 03 oracle §Order。production関数不使用 |
| TS-SERVER-SL-SHORT-001<br>REQ-ORDER-003<br>TS-KD-011 | SEND_ENTRY・deal未集約 | tests/tick_shock/fixtures/TS-SERVER-SL-SHORT-001_ticks.csv + TS-SERVER-SL-SHORT-001_config.csv | entry fill → observed exit deal → aggregate。tests/tick_shock/expected/TS-SERVER-SL-SHORT-001_expected.csvの全field | first partial dealでclose、未観測をPASS、他Magic/positionの集約 | 外部server/process観測がなければSKIP予定 → Short server SL observation requires a real tester deal reason SL. | 03 oracle §Order。production関数不使用 |
| TS-SERVER-TP-LONG-001<br>REQ-ORDER-003<br>TS-KD-011 | SEND_ENTRY・deal未集約 | tests/tick_shock/fixtures/TS-SERVER-TP-LONG-001_ticks.csv + TS-SERVER-TP-LONG-001_config.csv | entry fill → observed exit deal → aggregate。tests/tick_shock/expected/TS-SERVER-TP-LONG-001_expected.csvの全field | first partial dealでclose、未観測をPASS、他Magic/positionの集約 | 外部server/process観測がなければSKIP予定 → Long server TP observation requires a real tester deal reason TP. | 03 oracle §Order。production関数不使用 |
| TS-SERVER-TP-SHORT-001<br>REQ-ORDER-003<br>TS-KD-011 | SEND_ENTRY・deal未集約 | tests/tick_shock/fixtures/TS-SERVER-TP-SHORT-001_ticks.csv + TS-SERVER-TP-SHORT-001_config.csv | entry fill → observed exit deal → aggregate。tests/tick_shock/expected/TS-SERVER-TP-SHORT-001_expected.csvの全field | first partial dealでclose、未観測をPASS、他Magic/positionの集約 | 外部server/process観測がなければSKIP予定 → Short server TP observation requires a real tester deal reason TP. | 03 oracle §Order。production関数不使用 |
### A. 時刻・因果性

| Test ID / Req / Defect | 初期状態 | 入力 | 期待状態遷移・出力 | 禁止される出力 | current → desired | 独立oracle |
|---|---|---|---|---|---|---|
| TS-TIME-CLOSE-LONG-001<br>REQ-ORDER-004<br>NONE | SEND_ENTRY・deal未集約 | tests/tick_shock/fixtures/TS-TIME-CLOSE-LONG-001_ticks.csv + TS-TIME-CLOSE-LONG-001_config.csv | entry fill → observed exit deal → aggregate。tests/tick_shock/expected/TS-TIME-CLOSE-LONG-001_expected.csvの全field | processing/eligible以前、signal同一tick、synthetic時刻でのentry | 外部server/process観測がなければSKIP予定 → Long expert time close aggregates its exit deal and labels client/expert reason separately from server barriers. | 03 oracle §Clock。production関数不使用 |
| TS-TIME-CLOSE-SHORT-001<br>REQ-ORDER-004<br>NONE | SEND_ENTRY・deal未集約 | tests/tick_shock/fixtures/TS-TIME-CLOSE-SHORT-001_ticks.csv + TS-TIME-CLOSE-SHORT-001_config.csv | entry fill → observed exit deal → aggregate。tests/tick_shock/expected/TS-TIME-CLOSE-SHORT-001_expected.csvの全field | processing/eligible以前、signal同一tick、synthetic時刻でのentry | 外部server/process観測がなければSKIP予定 → Short expert time close mirrors Long and aggregates the exit deal. | 03 oracle §Clock。production関数不使用 |
### F. order lifecycle

| Test ID / Req / Defect | 初期状態 | 入力 | 期待状態遷移・出力 | 禁止される出力 | current → desired | 独立oracle |
|---|---|---|---|---|---|---|
| TS-POSITION-001<br>REQ-ORDER-005<br>NONE | owned position存在 | tests/tick_shock/fixtures/TS-POSITION-001_ticks.csv + TS-POSITION-001_config.csv | snapshot/terminal state → managed recovery。tests/tick_shock/expected/TS-POSITION-001_expected.csvの全field | first partial dealでclose、未観測をPASS、他Magic/positionの集約 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → Managed position recovery restores identity direction volume time SL and TP. | 03 oracle §Order。production関数不使用 |
| TS-RESTART-001<br>REQ-ORDER-005<br>TS-KD-010 | SEND_ENTRY・deal未集約 | tests/tick_shock/fixtures/TS-RESTART-001_ticks.csv + TS-RESTART-001_config.csv | request → 1..N fills/cancel → resolved entry。tests/tick_shock/expected/TS-RESTART-001_expected.csvの全field | first partial dealでclose、未観測をPASS、他Magic/positionの集約 | 現行helper/定義は一致予定。Step 3では未実行 → A restart that was not injected is SKIP NOT_OBSERVED and never increments PASS. | 03 oracle §Order。production関数不使用 |
| TS-RESTART-002<br>REQ-ORDER-005<br>TS-KD-010 | phase A snapshotまたは未注入状態 | tests/tick_shock/fixtures/TS-RESTART-002_ticks.csv + TS-RESTART-002_config.csv | snapshot/terminal state → managed recovery。tests/tick_shock/expected/TS-RESTART-002_expected.csvの全field | first partial dealでclose、未観測をPASS、他Magic/positionの集約 | 現行はproduction注入seam不足または既知欠陥のためXFAIL予定 → Injected two-phase restart restores an owned live position then continues management. | 03 oracle §Order。production関数不使用 |

## 共通PASS条件

1. fixture/expected/configが全Test IDに存在し、case registryと1対1である。
2. actualに未定義field、NaN、無言の0代入、時刻逆転がない。
3. expected_valueとactualの差が数値tolerance以下、文字列/状態/countは完全一致。
4. 禁止出力が1件でもあればFAIL。invariant counterはexpectedが0なら欠損もFAIL。
5. Long/Short pairは価格side以外の状態順・件数・境界包含が対称。
6. Strategy Testerの未観測項目はSKIP/NOT_OBSERVEDで、PASS countに含めない。
7. test runnerはexpectedを更新しない。変更は仕様review commitでのみ行う。

## Step 4/5境界

Step 4はproduction behaviorを注入可能なmodule/adapterへ抽出する。Step 5はこの仕様をコード化する。Step 4でテストを通すためにthresholdやfixture/expectedを変更してはならない。既知bugを直す場合は対応Defect IDとXFAILを個別commitで解消し、XPASS理由をreviewする。
