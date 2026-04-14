# USDJPY failed breakout short structure engine redesign

## 1. 現 scaffold の評価

- 良い点:
  - `M15 x M5` を基準にしており、sample を出しやすい
  - pivot / swing 検出、EMA / ATR、telemetry の骨格は再利用価値がある
  - short-only standalone として切れている
- 弱い点:
  - HTF が `trend context` 止まりで、親波の段階を読む engine になっていなかった
  - LTF が `条件成立` に寄っていて、`sweep -> failed acceptance -> reclaim -> breakdown` の遷移が薄かった
  - fib が filter にはなっていたが、戻りの意味づけに十分使えていなかった
  - entry type が 1 種類に近く、どの崩れを取ったのか review しづらかった

## 2. 再利用する部品 / 捨てる部品

### 再利用

- pivot / swing 検出
- HTF / LTF のバー確定ベース処理
- EMA / ATR handle 管理
- risk sizing
- telemetry-first の CSV ログ
- standalone で評価してから統合する方針

### 捨てる

- `構造っぽい条件を並べる` 発想
- HTF を continuation / weakening / range の浅い分類で済ませること
- LTF を単発イベントで読むこと
- flat additive score に戻ること

## 3. 新しい structure engine 仕様

### HTF phase definition

- `HTF_UP_IMPULSE`
- `HTF_UP_PULLBACK`
- `HTF_UP_EXHAUSTION`
- `HTF_RANGE_TOP`
- `HTF_RANGE_MIDDLE`
- `HTF_RANGE_BOTTOM`
- `HTF_DOWN_IMPULSE`
- `HTF_DOWN_PULLBACK`
- `HTF_DOWN_EXHAUSTION`

判定要素:
- `HH / HL`
- `LH / LL`
- `EMA fast / slow`
- `range position`
- `active wave`
- `fib retracement`

short の baseline は以下を主に使う:
- Tier A:
  - `HTF_UP_EXHAUSTION`
  - `HTF_RANGE_TOP`
- Tier B:
  - `HTF_UP_PULLBACK`
  - `HTF_UP_EXHAUSTION`
  - `HTF_RANGE_TOP`

### LTF state machine

- `SWEEP_ONLY`
- `FAILED_ACCEPTANCE`
- `RECLAIM_CONFIRMED`
- `LOWER_HIGH_FORMED`
- `BREAKDOWN_CONFIRMED`
- `RETEST_FAILURE`

short では、上抜けの失敗を見たあとに、どこまで売り構造へ進んだかを state として持つ。

### setup definition

- HTF で親波 phase を決定する
- HTF の高値帯を `reference level` とする
- LTF で `sweep -> failed acceptance -> breakdown` のどこまで進んだかを見る
- fib で `shallow / natural / deep` を分類する

### entry types

- `ENTRY_ON_RECLAIM_FAILURE`
- `ENTRY_ON_LOWER_HIGH_BREAKDOWN`
- `ENTRY_ON_RETEST_FAILURE`

### stop basis

- baseline:
  - `sweep high`
- ablation:
  - `failure pivot`

### target basis

- `previous swing`
- `fixed R`
- `fib target`
- `hybrid partial`

### partial exit logic

- `hybrid partial` のとき、fib target 付近で一部利確
- 残りは prior swing か fallback R を狙う
- partial 後は stop を entry 近辺に寄せる

### reject conditions

- enough trades が出ているのに `PF < 1`
- OOS 崩壊
- Tier B を足すと weak inventory だけ増える
- telemetry 上、勝ち筋が sparse pocket にしか残らない

## 4. 関数分割案

- `BuildHtfPhaseContext`
- `BuildLtfStateMachine`
- `DetectFailedBreakoutState`
- `ComputeFibRetracement`
- `EvaluateTierA`
- `EvaluateTierB`
- `BuildEntryPlan`
- `ManageOpenPositions`
- `LogTelemetry`

## 5. 疑似コード

```text
OnTick():
  if not new LTF bar:
    return

  ManageOpenPositions()

  if global guards fail:
    return

  htf = BuildHtfPhaseContext()
  if not htf.valid:
    return

  setup = DetectFailedBreakoutState(htf)
  if not setup.valid:
    return

  plan = BuildEntryPlan(setup)
  if not plan.valid:
    return

  volume = CalculateVolumeByRisk(plan.entry, plan.stop)
  if volume <= 0:
    return

  execute short
  telemetry logs on transaction
```

## 6. EA scaffold code

- [usdjpy_20260413_failed_breakout_short_scaffold.mq5](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/mql/Experts/usdjpy_20260413_failed_breakout_short_scaffold.mq5)

## 7. preset 候補

- [tierA](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/presets/usdjpy_20260413_failed_breakout_short_scaffold-tierA.set)
- [tierAB](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/presets/usdjpy_20260413_failed_breakout_short_scaffold-tierAB.set)

## 8. tester plan

- locked train:
  - `2025-04-01` to `2025-12-31`
- OOS:
  - `2026-01-01` to `2026-04-01`
- actual:
  - `2024-11-26` to `2026-04-01`

telemetry review:
- phase bucket
- entry type
- fib depth bucket
- stop basis
- target type
- hour bucket
- volatility bucket
- exit reason

ablation:
- entry type 比較
- stop basis 比較
- target mode 比較
- timeframe pair 比較
  - `M15 x M5`
  - `M30 x M5`
  - `M15 x M1`
  - `H1 x M5`

## 9. reject / continue criteria

### reject

- enough trades が出ているのに `PF < 1`
- OOS で崩れる
- Tier B を足しても quality が改善しない
- session を削らないと正にならない

### continue

- long-window actual が正
- latest OOS が正
- telemetry で勝ち筋が phase / state / entry type で説明できる

## 判断メモ

- 今回の再設計は `triple-top rescue` ではない。
- それでも `USDJPY short` の failed breakout は、強い up impulse を逆張りする危険を常に持つ。
- したがって、phase が弱いまま count だけ出るなら即 kill する。
