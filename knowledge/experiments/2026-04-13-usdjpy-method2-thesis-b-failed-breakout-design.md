# USDJPY Method2 Thesis B Failed-Breakout Short Design

## 1. 現 Method2 の失敗診断

- `entry` が遅かった。
  - 旧 Method2 は `neckline close break -> market entry` が中心で、`M5` では breakout の初動をかなり食ってから入る形だった。
  - そのため、すでに良い値段は終わっていて、残るのは薄い follow-through だけになりやすかった。
- `stop` が重すぎた。
  - `3山最高値の上` は classical top reversal には自然でも、短期の failed move を取るには遠すぎた。
  - `M5` の初動に対して stop が広く、1勝で取り返しにくい構造だった。
- `target` が遠すぎた。
  - `1.6R` 固定は、failed breakout のような短い rotation move には重かった。
  - 実際には `TP` より `time_stop` と `SL` が先に出やすかった。
- `HTF context` が top reversal とずれていた。
  - 旧実装は `uptrend の天井を売る` つもりで始まったが、context を修正していくと `弱い戻り売り` family に変質した。
  - つまり thesis が途中で別物になっていた。
- `score` が edge を序列化できていなかった。
  - flat additive score は、条件の寄与が独立していないのに単純加算していた。
  - 高得点がそのまま高期待値にならず、selector として機能しなかった。

## 2. 再利用できる部品 / 捨てる部品

### 再利用できる部品

- pivot / swing 検出
- HTF / LTF のバー確定ベース処理
- EMA / ATR handle 管理
- position sizing
- spread / session などの global guard
- telemetry-first の CSV ログ
- `M15 x M5` を最初の research pair にする方針
- standalone で評価してから統合する運用

### 捨てる部品

- `TriplePattern` の 5 pivot 固定構造
- flat additive score
- `default stop = 3 peaks high`
- `Strong + Standard` で在庫を広げる発想
- 三尊という名前を前提にした selector
- session filter だけで rescue しようとする考え

## 3. Thesis B の仕様

### 概要

- Thesis B は `triple-top short` ではない。
- 狙うのは `failed breakout / failed acceptance above level / liquidity sweep short`。
- つまり、意味のある prior high / swing zone / range upper edge を上抜いたあと、
  その上で受け入れられず、内側へ戻され、さらに下位足で break が出る局面を売る。

### HTF context

- HTF は entry ではなく、どの波の中で failed breakout を売るかを決める。
- `M15` では以下のダウ状態を分類する。
  - `上昇継続`
  - `下降継続`
  - `上昇弱化`
  - `下降弱化`
  - `レンジ`
- short の Thesis B で主に使うのは以下。
  - Tier A:
    - `上昇弱化`
    - `レンジ上限`
  - Tier B:
    - `上昇継続`
    - `上昇弱化`
    - `レンジ`
- HTF の `reference level` は直近の意味ある高値帯。
  - baseline は `latest confirmed high` と `previous confirmed high` の zone。

### LTF failed breakout detection

- LTF では以下の状態遷移を扱う。
  - `swing high / swing low`
  - `sweep`
  - `failed acceptance`
  - `break`
  - `reclaim / reject`
- short の基本形は以下。
  1. HTF reference level を LTF が上抜く
  2. その上で close を維持できない
  3. 次に内側へ戻す
  4. 直近の LTF low / reclaim bar low を割る
  5. 次バー始値で short

### Entry trigger

- all-conditions-must-match の全一致型にはしない。
- flat score も使わない。
- `Tier A / Tier B` の gated rule にする。

#### Tier A

- HTF が `上昇弱化` または `レンジ上限`
- HTF range position が高い
- LTF の sweep が十分大きい
- reclaim close が bar 下側にある
- failed acceptance 後に break 確認がある
- Fib entry filter では `38.2% - 61.8%` の zone を使う

#### Tier B

- HTF が `上昇継続 / 上昇弱化 / レンジ`
- Tier A より浅い sweep も許容
- close location を少し緩める
- ただし `break` は必須
- weak inventory を増やさないため、単に sweep しただけでは入らない

### Stop basis

- default は `sweep high`
- ablation では `failure pivot high`
- 旧 Method2 のような `3山最高値` は使わない

### Target basis

- baseline 候補:
  - `prior swing low front-run`
  - `fixed R`
  - `fib target`
  - `hybrid partial exit`
- fib では最低限以下を比較可能にする。
  - `38.2%`
  - `50.0%`
  - `61.8%`

### Time stop / management

- `M5` baseline は short hold に寄せる
- `time stop`
- `acceptance back above level` exit
- `hybrid partial` の場合は partial 後に stop を建値近辺へ寄せる

### Reject conditions

- enough trades が出ているのに `PF < 1`
- OOS で崩れる
- Tier B を足した結果、弱い在庫が増えるだけ
- session を削った sparse survivor しか残らない

### ダウ理論とフラクタル構造の扱い

- HTF は `どの大波のどこか` を分類する
- LTF は `その大波の中の短い失敗構造` を捉える
- つまり code 上では
  - HTF:
    - `state`
    - `referenceLevel`
    - `activeWaveHigh / activeWaveLow`
  - LTF:
    - `sweepHigh`
    - `failurePivotHigh`
    - `reclaimClose`
    - `targetSwingLow`
  を明示的に持つ

## 4. 関数分割案

- `BuildHtfContext()`
  - HTF のダウ状態、range position、reference level、active wave、fib を構築する
- `BuildLtfStructure()`
  - LTF の swing / sweep / reclaim / break を組み立てる
- `DetectFailedBreakout()`
  - HTF と LTF をつなぎ、Tier A / Tier B を評価する
- `EvaluateTierA()`
  - 強い完全形の gate
- `EvaluateTierB()`
  - 準パターンの gate
- `ComputeFibRetracement()`
  - HTF wave から `38.2 / 50.0 / 61.8` を返す
- `BuildEntryPlan()`
  - stop basis / target basis / partial target を決める
- `ManageOpenPositions()`
  - time stop / acceptance exit / hybrid partial
- `LogTelemetry()`
  - entry / partial / exit を記録する

## 5. 疑似コード

```text
OnTick():
  if not new LTF bar:
    return

  ManageOpenPositions()

  if global guards fail:
    return

  ctx = BuildHtfContext()
  if not ctx.valid:
    return

  setup = DetectFailedBreakout(ctx)
  if not setup.valid:
    return

  plan = BuildEntryPlan(setup)
  if not plan.valid:
    return

  volume = CalculateVolumeByRisk(plan)
  if volume <= 0:
    return

  execute short
  telemetry logs on trade transaction
```

## 6. EA scaffold code

- 実装ファイル:
  - [usdjpy_20260413_failed_breakout_short_scaffold.mq5](/c:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/mql/Experts/usdjpy_20260413_failed_breakout_short_scaffold.mq5)
- compile:
  - [usdjpy_20260413_failed_breakout_short_scaffold.log](/c:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/compile/usdjpy_20260413_failed_breakout_short_scaffold.log)

## 7. preset 候補

- Tier A 厳しめ
  - [tierA](/c:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/presets/usdjpy_20260413_failed_breakout_short_scaffold-tierA.set)
- Tier A + Tier B
  - [tierAB](/c:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/presets/usdjpy_20260413_failed_breakout_short_scaffold-tierAB.set)

## 8. tester plan

- locked train
  - `2025-04-01` to `2025-12-31`
- OOS
  - `2026-01-01` to `2026-04-01`
- actual
  - `2024-11-26` to `2026-04-01`
- telemetry review
  - hour bucket
  - HTF state bucket
  - Tier A vs Tier B
  - stop basis
  - target type
  - fib retracement ratio
  - failure type
  - exit reason
- 小さい ablation plan
  1. `score なし binary`
  2. `stop = breakout pivot`
  3. `target = 1.0R-1.2R / prior swing / fib`
  4. `entry = intra-bar break + next-bar failure confirmation`
  5. timeframe pair:
     - `M30 x M5`
     - `M15 x M1`
     - `H1 x M5`

## 9. reject / continue criteria

### reject

- enough trades が出ているのに `PF < 1`
- Tier A も Tier A+B も actual で負ける
- OOS が崩れる
- telemetry review 上、特定 subset を削らないと勝てない
- sparse high-PF survivor しか残らない

### continue

- long-window actual が正
- latest OOS が正
- Tier B を足しても expectancy を壊さない
- trade count が sparse ではない
- telemetry 上、勝ち筋が構造的に説明できる

## 判定メモ

- Thesis B は旧 triple-top family より筋が良い。
- 理由は、pattern 名を売るのではなく `failed acceptance above level` という構造を売っているから。
- ただし、これでも enough trades が出て `PF < 1` なら即 kill する。
- 弱い idea を複雑化して延命する余地は残さない。
