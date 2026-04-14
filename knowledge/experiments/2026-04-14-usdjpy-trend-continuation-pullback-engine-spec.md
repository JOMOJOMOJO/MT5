# USDJPY Trend Continuation Pullback Engine Spec

## 1. 再利用部品 / 捨てる部品

再利用する部品:
- `PivotPoint` と confirmed pivot 収集
- HTF/LTF の `EMA` / `ATR` handle 管理
- recent range と fib helper
- risk sizing
- global guards
- telemetry CSV
- partial exit と transaction logging の枠組み

捨てる部品:
- failed breakout / sweep / reclaim failure の short ロジック
- reversal 前提の phase bias
- short 専用の entry / stop / acceptance exit
- `failureType` ベースの naming

今回残す方針:
- `phase -> state -> entry type` を telemetry で読める設計
- bar-close ベース
- tiered / gated rule
- standalone family

## 2. 新 family の仕様

family 名:
- `Trend Continuation Pullback Engine`

前提:
- long-only first
- reversal ではなく parent up wave の continuation を取る

HTF rule:
- `hh_hl` かつ `EMA20 > EMA50` を親波の土台に使う
- active wave は `previous low -> latest high`
- HTF close の retracement と range position で phase を分類する

LTF rule:
- HTF latest high の後に pullback が発生すること
- pullback が fib retracement zone に入ること
- その後に `higher low` / `reclaim` / `continuation break` / `retest continuation` を状態遷移で読む

fib の意味:
- shallow: `< 0.382`
- natural: `0.382 - 0.618`
- deep: `> 0.618`
- entry filter は pullback low の retracement を使う
- target は active wave high からの fib extension を使う

entry type:
- `ENTRY_ON_PULLBACK_RECLAIM`
- `ENTRY_ON_HIGHER_LOW_BREAK`
- `ENTRY_ON_RETEST_CONTINUATION`

stop basis:
- `STOP_PULLBACK_LOW`
- `STOP_HIGHER_LOW`

target basis:
- `PRIOR_SWING`
- `FIXED_R`
- `FIB`
- `HYBRID_PARTIAL`

partial exit:
- `HYBRID_PARTIAL` のみ
- first take at prior swing high front-run
- remainder target at fib extension
- partial 実行後は break-even stop

## 3. HTF / LTF state design

HTF phase:
- `HTF_UP_IMPULSE`
- `HTF_UP_PULLBACK`
- `HTF_UP_EXHAUSTION`
- `HTF_RANGE`
- `HTF_DOWN_IMPULSE`
- `HTF_DOWN_PULLBACK`
- `HTF_DOWN_EXHAUSTION`

HTF phase の使い方:
- promotion 対象は `HTF_UP_PULLBACK`
- `HTF_UP_IMPULSE` は Tier B に限定
- `HTF_UP_EXHAUSTION` と down / range は offside 扱い寄り

LTF state:
- `LTF_PULLBACK_IN_PROGRESS`
- `LTF_IN_FIB_ZONE`
- `LTF_HIGHER_LOW_FORMED`
- `LTF_RECLAIM_CONFIRMED`
- `LTF_CONTINUATION_BREAK`
- `LTF_RETEST_CONTINUATION`

狙う構造:
- `HTF_UP_PULLBACK`
- `LTF_IN_FIB_ZONE -> LTF_HIGHER_LOW_FORMED -> LTF_RECLAIM_CONFIRMED`
- そこから `ENTRY_ON_PULLBACK_RECLAIM` か `ENTRY_ON_HIGHER_LOW_BREAK`
- breakout 後の押し直しは `ENTRY_ON_RETEST_CONTINUATION`

## 4. 関数分割案

- `BuildHtfPhaseContext`
- `BuildLtfStateMachine`
- `DetectContinuationSetup`
- `ComputeFibRetracement`
- `ComputeFibExtension`
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

  setup = DetectContinuationSetup(htf)
  if not setup.valid:
    return

  plan = BuildEntryPlan(setup)
  if not plan.valid:
    return

  volume = CalculateVolumeByRisk(plan.entry, plan.stop)
  if volume <= 0:
    return

  execute long
  telemetry logs on transaction
```

## 6. 初期 tester plan

window:
- locked train: `2025-04-01` to `2025-12-31`
- OOS: `2026-01-01` to `2026-04-01`
- actual: `2024-11-26` to `2026-04-01`

順番:
1. `M15 x M5`, Tier A strict
2. `M15 x M5`, Tier A + Tier B
3. target mode ablation
4. stop basis ablation
5. timeframe pair ablation
   - `M30 x M5`
   - `M15 x M1`
   - `H1 x M5`

telemetry review:
- phase
- context bucket
- wave label
- fib depth bucket
- ltf state
- entry type
- target mode
- stop basis
- volatility bucket
- hour bucket
- exit reason

## 7. reject / continue criteria

continue:
- actual が致命的でない
- latest OOS が完全崩壊していない
- telemetry で `HTF_UP_PULLBACK -> LTF_HIGHER_LOW / RECLAIM / CONTINUATION` の勝ち筋が読める
- Tier B が weak inventory ではなく additive

reject:
- enough trades があるのに `PF < 1`
- OOS 崩壊
- traded path が 1 subtype に縮退し、その subtype も repeatability が弱い
- sparse survivor しか残らない

## 8. 初期判断

この family の狙いは failed breakout short より筋が良いです。理由は、逆張り reversal ではなく parent trend continuation を扱うからです。

ただし、これも `HTF_UP_PULLBACK` 以外で inventory を無理に広げると弱くなります。初期検証では Tier A strict を基準にして、Tier B は additive かどうかだけを見るべきです。
