# Wave33 DayTrade Partial v1.91

状態：ビルド・静的確認後に、短いnative QAを1回だけ起動する。実行の完了・PASSはユーザーの呼びかけ後に確認する。年間収益テストではない。

ユーザーの分析依頼による再開後、既存結果を収集：純粋判定 **98/98 PASS**、native注文経路 **41/41 PASS**。[確認記録](native_result_review.json)。合成fixtureでの注文処理の合格であり、戦略損益や年間成績の合格ではない。再実行はしていない。

EA・純粋判定script・native harnessはいずれも **0 errors / 0 warnings**。静的確認63件PASS、既存23ファイルのSHA256が作業前と一致した。[検証記録](build_static_verification.json)、[ビルドログ](compile/Wave33DayTradePartialVerifier.log)。MetaEditor終了code1をログ成功で扱う既存helperのPowerShell表示はMQLの警告件数とは異なる。nativeでの判定テストと約定処理の結果は未確認。

新EA：[Wave33DayTradePartialVerifier.mq5](../../../mql/Experts/Wave33DayTradePartialVerifier.mq5)。旧v1.90などの既存EAと共有headerを変更しない。[出口仕様](../../../knowledge/experiments/2026-10-26-wave33-half-and-step-plan.md)。

| 到達価格利益 | 初期数量に対する操作 | 残りのSL |
|---|---|---|
| 1R | 半分を成行利確 | 初期SLのまま |
| 1.5R | 保有 | +1R |
| 2R | 保有 | +1.5R |
| 2.5R | 保有 | +2R |

1Rは最初の平均約定価格と初期SLで固定。部分利確と段階SLで分母は変えない。SLはbrokerの実ポジションで変更を確認してから確定し、Stops/Freezeで不可能なら理由を残して再試行する。固定の全量TPは置かず、黄色の有限線はEA管理の半分利確目標。SLの変更履歴は赤い有限点線、実部分約定は黄色の印で残す。

`InpScaleOut=true`、`InpPartialAtR=1`、`InpStepSL=true`、`InpStepStartR=1.5`、`InpStepSizeR=0.5`、`InpStepLagR=0.5`。24時間・週末前・逆①利益決済は維持。半分を約定確認する前には段階SLを変更しない。1Rで半分を決済した後、1.5Rへ届かず初期SLに戻れば手数料前の合計は概ね0Rとなる。

リスク予算内で偶数のロットステップへ切り下げ、二等分できない小ロットは発注前に見送る。実入口の部分約定で二等分不能になった場合は明示ログと初期SL・時間・逆①決済を残す。自動全量利確へ置換しない。レポートの純損益Rは初回全量の元リスク額を分母にする。

テスターで `dev\mql\Experts\Wave33DayTradePartialVerifier` を選び、次の設定を読み込む。EA単体の注文初期値はOFF、安全な通常チャート非発注ガードを維持。プリセットはテスター注文ON。

- [M15×M5、表示M5](../../../presets/wave33/Wave33DayTradePartial_v191_A_Visual.set)
- [M5×M1、表示M1](../../../presets/wave33/Wave33DayTradePartial_v191_B_Visual.set)

ログはMT5共通Filesの `<tag>_partial.csv`、`<tag>_daytrade.csv`、`<tag>_raw_deals.csv`、既存のevents/config等。`DAY_PARTIAL_FROZEN` → `DAY_PARTIAL_TOUCH` → `DAY_PARTIAL_REQUEST` → `DAY_PARTIAL_FILLED` → `STEP_SL_STAGE` → `STEP_SL_CONFIRMED` を確認する。送信受理だけではFILLEDにしない。

## QAの範囲

- 純粋判定：[テストheader](../../../mql/Include/Wave33Visual/DayTradePartialPolicyTests.mqh)でLONG/SHORTの価格、実行側spread、半分数量、重複禁止、部分約定後の残数、0.5R段階、初期R固定、24h境界、小ロット・不正値を確認する。実行前にPASSを宣言しない。
- [native harness](../../../mql/Experts/tests/Wave33DayTradePartialHarness.mq5)は同じEAを読み込み、LONG/SHORT各1件について半分決済・SL変更・残量時間決済をnative APIで確認する。拒否後再試行、競合lock、元リスク額と数量の保存も確認する。
- 価格がたまたま到達するまで待つ試験にしないため、半分トリガーを現在の実行可能価格へ置く人工fixtureを明記する。SL経路は合成MFE1.5Rと一時lag2Rで市場内の安全な位置へ変更し、時間経路は時刻を24時間古くしたfixture。純粋テストが本来の1R/1.5R/.5Rの数式を検証し、nativeは注文経路を検証する。利益や実際の24時間保有を証明しない。
- 旧QAの226件FAILは保存する。原因は旧journalの2020-01-02 01:00台の226件すべてが `[Market closed]`、01:01から発注成功。新harnessはこの待機を `WAIT_READINESS` に記録し、600秒のsource-time watchdogで無限待機しない。
- [prepare-smoke.ps1](prepare-smoke.ps1)は専用portable・専用port39391を使い、既存端末や実行中テスターを変更しない。過去HCCから生成するtickでの注文処理QA。リアルティックの年間評価ではない。
- [launch-smoke.ps1](launch-smoke.ps1)は1回だけ起動して `LAUNCHED_AWAIT_USER_RESUME` を保存し、以降の待機・集計を行わない。

注文受理と約定確認を分ける根拠：[MQL5 OrderSend](https://www.mql5.com/en/docs/trading/ordersend)。対象ポジションをticketで指定する：[MqlTradeRequest](https://www.mql5.com/en/docs/constants/structures/mqltraderequest)。
