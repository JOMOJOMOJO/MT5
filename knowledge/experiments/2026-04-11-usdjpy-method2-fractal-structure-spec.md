# USDJPY Method2 Fractal Structure Spec

## 1. 戦略のロジック説明

### 目的

- 裁量でいう
  - `上位足の方向を見る`
  - `下位足の押し目/戻りを待つ`
  - `少し抜けて戻す`
  - `短期ダウ転換で3波に乗る`
- これを `MT5 actual backtest` で検証しやすい、非リペイント寄りのルールへ落とす。

### 戦略の中核

- Method2 は `フラクタル構造ベースの pullback continuation` とする。
- 方向は `上位足のダウ構造` で決める。
- 仕掛けは `下位足の sweep + reclaim + 短期ダウ転換` で決める。
- エントリーは `押し安値/戻り高値タッチ` ではなく、`一度抜けてから戻す` を必須にする。

### 買いの流れ

1. 上位足で `HH/HL` が確認されている。
2. 下位足で逆行の下降波が進み、上位足の押し目候補ゾーンへ入る。
3. 下位足で一度、直近安値または押し目候補を少し下抜く。
4. その下抜き後、下位足で
   - `安値切り上げ`
   - `直近戻り高値更新`
   - `短期ダウ転換`
   のどれかではなく、`安値切り上げ + 直近戻り高値更新` を揃えて買う。

### 売りの流れ

1. 上位足で `LL/LH` が確認されている。
2. 下位足で逆行の上昇波が進み、上位足の戻り候補ゾーンへ入る。
3. 下位足で一度、直近高値または戻り候補を少し上抜く。
4. その上抜き後、下位足で
   - `高値切り下げ`
   - `直近押し安値更新`
   - `短期ダウ転換`
   のどれかではなく、`高値切り下げ + 直近押し安値更新` を揃えて売る。

### 狙う「3波」の定義

- 本戦略で狙う3波は、エリオット厳密定義ではなく、実装上は以下で十分。
- 買い:
  - 波1: 上位足で新高値を作った推進
  - 波2: 下位足での押し目形成
  - 波3: 押し目完了後のトレンド再開
- 売り:
  - 波1: 上位足で新安値を作った推進
  - 波2: 下位足での戻り形成
  - 波3: 戻り完了後のトレンド再開

### Method2 としての推奨初期形

- Symbol: `USDJPY`
- HTF: `M15`
- LTF: `M5`
- さらに execution を細かくする派生:
  - HTF `M15` x LTF `M1`
  - HTF `H1` x LTF `M5`
- 最初の actual MT5 候補は
  - `HTF=M15`
  - `LTF=M5`
  - `1 logic`
  - `1 setup`
  に固定する。

## 2. 実装ルール一覧

### A. 上位足トレンド判定

- 上位足では `確定済み pivot high / pivot low` を使う。
- `PivotSpan = 2` なら
  - 高値 pivot:
    - `High[i] > High[i-1], High[i-2], High[i+1], High[i+2]`
  - 安値 pivot:
    - `Low[i] < Low[i-1], Low[i-2], Low[i+1], Low[i+2]`
- 最新の確定済み swing を 2 組取り、以下を判定する。
- Bull trend:
  - `latestHigh > previousHigh`
  - `latestLow > previousLow`
- Bear trend:
  - `latestHigh < previousHigh`
  - `latestLow < previousLow`
- どちらでもなければ `TrendNone`

### B. 上位足の押し目/戻り候補ゾーン

- 買いゾーン:
  - 基本は `latestLow` 周辺
  - 補助として `EMA20/EMA50` の近接も許容
- 売りゾーン:
  - 基本は `latestHigh` 周辺
  - 補助として `EMA20/EMA50` の近接も許容
- ゾーン幅:
  - `max(固定 pips, ATR(HTF) * ZoneATRMult)`
- 初期推奨:
  - `ZoneATRMult = 0.25`
  - `MinZonePips = 4.0`

### C. 下位足の押し目/戻り判定

- 買い:
  - LTF で直近 `n` 本の中に lower-low 系の correction がある
  - 現在価格が HTF buy zone 内または zone 下へ軽く overshoot
- 売り:
  - LTF で直近 `n` 本の中に higher-high 系の correction がある
  - 現在価格が HTF sell zone 内または zone 上へ軽く overshoot
- 初期推奨:
  - `PullbackLookbackBars = 24`

### D. Sweep 判定

- 買い sweep:
  - `currentLow < referenceLow - SweepBuffer`
  - ただし終値は安値引け一辺倒ではなく、`closeLocation >= 0.35`
- 売り sweep:
  - `currentHigh > referenceHigh + SweepBuffer`
  - ただし終値は高値引け一辺倒ではなく、`closeLocation <= 0.65`
- `referenceLow/referenceHigh` は
  - LTF 直近 swing
  - または HTF zone anchor
- 初期推奨:
  - `SweepBuffer = max(1.5 pips, ATR(LTF) * 0.10)`

### E. 短期転換判定

- 買い:
  - sweep 後に LTF で `higher low` が出る
  - その後、`直近戻り高値` を終値で上抜く
- 売り:
  - sweep 後に LTF で `lower high` が出る
  - その後、`直近押し安値` を終値で下抜く
- ここでいう短期ダウ転換は
  - 買い: `LL/LH` correction が `HL + breakout high` へ変わる
  - 売り: `HH/HL` correction が `LH + breakdown low` へ変わる

### F. エントリー確定条件

- 買い:
  - HTF bull trend
  - LTF pullback active
  - LTF sweep done
  - LTF higher low confirmed
  - LTF trigger high breakout on close
- 売り:
  - HTF bear trend
  - LTF retrace active
  - LTF sweep done
  - LTF lower high confirmed
  - LTF trigger low breakdown on close

### G. だまし削減ルール

- `spread guard`
- `session filter`
- `minimum target distance`
- `minimum trigger body`
- `max wick imbalance`
- `ATR regime`
- `no entry if HTF trend just flipped on the current bar`
- `1 setup per HTF swing`

### H. 損切り

- 買い:
  - `min(sweep low, trigger HL low) - StopBuffer`
- 売り:
  - `max(sweep high, trigger LH high) + StopBuffer`
- 初期推奨:
  - `StopBuffer = max(1.5 pips, ATR(LTF) * 0.08)`

### I. 利確

- 第一候補:
  - 前回 HTF swing high/low の手前
- 第二候補:
  - 固定 `R`
- 初期形は単純化のため、以下のどちらか一択で始める。
- Option A:
  - `TP = 1.5R`
- Option B:
  - `TP = previous HTF swing +/- buffer`
- 初回 actual は `1.2R` から `1.8R` の少数候補に限定する。

## 3. MQL5用の関数設計

### 推奨データ構造

```cpp
struct PivotPoint
{
   bool     valid;
   int      shift;
   double   price;
   datetime time;
};

struct TrendContext
{
   int      direction; // 1 bull, -1 bear, 0 none
   PivotPoint latestHigh;
   PivotPoint previousHigh;
   PivotPoint latestLow;
   PivotPoint previousLow;
   double   ema20;
   double   ema50;
   double   atr;
};

struct PullbackContext
{
   bool     zoneTouched;
   bool     sweepDone;
   double   sweepExtreme;
   double   triggerLevel;
   PivotPoint internalHigh;
   PivotPoint internalLow;
};

struct EntryPlan
{
   bool     valid;
   int      direction;
   double   entry;
   double   stop;
   double   target;
   string   reason;
};
```

### 関数一覧

```cpp
bool IsNewBar(ENUM_TIMEFRAMES tf, datetime &barTime);
bool LoadAtr(int handle, int shift, double &value);
bool LoadEma(int handle, int shift, double &value);

bool FindLatestConfirmedPivots(
   string symbol,
   ENUM_TIMEFRAMES tf,
   int pivotSpan,
   int scanBars,
   PivotPoint &latestHigh,
   PivotPoint &previousHigh,
   PivotPoint &latestLow,
   PivotPoint &previousLow);

int DetectDowTrend(
   const PivotPoint &latestHigh,
   const PivotPoint &previousHigh,
   const PivotPoint &latestLow,
   const PivotPoint &previousLow);

bool BuildTrendContext(
   string symbol,
   ENUM_TIMEFRAMES htf,
   TrendContext &ctx);

bool IsPriceInsideBuyZone(
   const TrendContext &ctx,
   double price,
   double zoneWidth);

bool IsPriceInsideSellZone(
   const TrendContext &ctx,
   double price,
   double zoneWidth);

bool DetectBullSweepAndReclaim(
   string symbol,
   ENUM_TIMEFRAMES ltf,
   const TrendContext &htfCtx,
   PullbackContext &pbCtx);

bool DetectBearSweepAndReclaim(
   string symbol,
   ENUM_TIMEFRAMES ltf,
   const TrendContext &htfCtx,
   PullbackContext &pbCtx);

bool ConfirmShortTermBullShift(
   string symbol,
   ENUM_TIMEFRAMES ltf,
   PullbackContext &pbCtx);

bool ConfirmShortTermBearShift(
   string symbol,
   ENUM_TIMEFRAMES ltf,
   PullbackContext &pbCtx);

bool BuildLongEntryPlan(
   const TrendContext &htfCtx,
   const PullbackContext &pbCtx,
   EntryPlan &plan);

bool BuildShortEntryPlan(
   const TrendContext &htfCtx,
   const PullbackContext &pbCtx,
   EntryPlan &plan);

bool PassExecutionFilters(
   const EntryPlan &plan);

double CalculateVolumeByRisk(
   string symbol,
   double entry,
   double stop,
   double riskPercent);

bool ExecuteEntry(
   const EntryPlan &plan);

void ManageOpenPositions();
```

### 実装方針

- `HTF context` と `LTF trigger` は必ず分離する。
- `trend detection` と `execution trigger` を同一関数に混ぜない。
- pivot 取得は `closed bars only` に限定する。
- `shift=0` の未確定足で swing 判定しない。

## 4. 疑似コード

```text
OnTick():
  if not IsNewBar(LTF):
    return

  UpdateRiskState()
  ManageOpenPositions()

  if HasManagedPosition():
    return

  if not PassGlobalGuards():
    return

  htfCtx = BuildTrendContext(symbol, HTF)
  if htfCtx.direction == none:
    return

  if htfCtx.direction == bull:
    pbCtx = DetectBullSweepAndReclaim(symbol, LTF, htfCtx)
    if not pbCtx.sweepDone:
      return

    if not ConfirmShortTermBullShift(symbol, LTF, pbCtx):
      return

    plan = BuildLongEntryPlan(htfCtx, pbCtx)
    if not plan.valid:
      return

    if PassExecutionFilters(plan):
      ExecuteEntry(plan)

  if htfCtx.direction == bear:
    pbCtx = DetectBearSweepAndReclaim(symbol, LTF, htfCtx)
    if not pbCtx.sweepDone:
      return

    if not ConfirmShortTermBearShift(symbol, LTF, pbCtx):
      return

    plan = BuildShortEntryPlan(htfCtx, pbCtx)
    if not plan.valid:
      return

    if PassExecutionFilters(plan):
      ExecuteEntry(plan)
```

### Long side trigger 詳細

```text
DetectBullSweepAndReclaim():
  find LTF internal pivots inside last N bars
  locate latest correction low near HTF buy zone
  if current confirmed bar swept below correction low by SweepBuffer:
    mark sweepExtreme
  after sweep:
    wait for a higher low pivot
    define triggerLevel = latest internal high between sweep low and higher low
  if close breaks above triggerLevel:
    sweepDone = true
```

### Short side trigger 詳細

```text
DetectBearSweepAndReclaim():
  find LTF internal pivots inside last N bars
  locate latest correction high near HTF sell zone
  if current confirmed bar swept above correction high by SweepBuffer:
    mark sweepExtreme
  after sweep:
    wait for a lower high pivot
    define triggerLevel = latest internal low between sweep high and lower high
  if close breaks below triggerLevel:
    sweepDone = true
```

### 損切り・利確

```text
BuildLongEntryPlan():
  entry = Ask
  stop = min(sweepExtreme, higherLow.price) - StopBuffer
  risk = entry - stop
  target1 = entry + risk * TargetR
  target2 = previous HTF swing high - TpBuffer
  target = smaller(target1, target2) if both valid

BuildShortEntryPlan():
  entry = Bid
  stop = max(sweepExtreme, lowerHigh.price) + StopBuffer
  risk = stop - entry
  target1 = entry - risk * TargetR
  target2 = previous HTF swing low + TpBuffer
  target = larger(target1, target2) if both valid
```

## 5. 注意点（リペイント、約定、スプレッド、最適化）

### リペイント

- `ZigZag` は最後の足が更新され続けるので、主判定には使わない。
- `Fractals` も確定まで待つ必要がある。
- 実運用では
  - `confirmed pivot`
  - `closed bar only`
  を徹底する。

### 約定

- `M1-M15` では spread と slippage の影響が大きい。
- trigger は見えても `R` が小さすぎると死ぬ。
- 初期設計では
  - `stop < 4 pips` の setup は飛ばす
  - `target < spread * 4` の setup は飛ばす
  が安全。

### スプレッド

- `USDJPY` でも時間帯で spread は変わる。
- `blocked entry hours`
  - ロールオーバー前後
  - 指標直前後
  を無視できる設計にする。
- 少なくとも
  - `InpMaxSpreadPips`
  - `InpAllowedWeekdays`
  - `InpBlockedEntryHours`
  は入れる。

### 最適化

- 最適化対象は 1 cycle で多くても 5 個まで。
- 最初に触るべきは以下だけ。
  - `PivotSpan`
  - `SweepBuffer`
  - `ZoneATRMult`
  - `TargetR`
  - `MaxHoldBars`
- 逆に最初から最適化しないもの:
  - EMA period を大量に振る
  - zone 条件を多段にする
  - candle filter を増やしすぎる

### テスターでの実務注意

- HTF/LTF 併用ロジックは `new bar` 制御が崩れると結果が壊れる。
- `iBarShift`, `CopyTime`, `CopyBuffer` の整合を毎回確認する。
- signal 判定時は `LTF shift=1`、pivot 判定はさらに右側確定本数を見たバーまで下げる。

## 6. 改善案

### 改善案 1

- 初号機は `long/short 両対応` で書くが、検証は `direction split` を必須にする。
- 先に
  - `long-only`
  - `short-only`
  - `both`
  を別々に actual MT5 で見る。

### 改善案 2

- sweep の質を上げるために `volume proxy` を入れる。
- ただし first build では tick volume は補助に留める。
- 例:
  - sweep bar が `volume mean * 1.2` 以上

### 改善案 3

- breakout を `終値突破` に限定すると遅すぎる場合がある。
- 次段階で
  - `stop order at trigger high/low`
  - `close breakout`
  の二択比較を行う。

### 改善案 4

- 利確は固定 `R` と `HTF swing target` の二本立てで比較する。
- 先に複雑な partial exit は入れない。

### 改善案 5

- 実装上の第一候補は `custom confirmed pivot`。
- 比較対象として
  - `built-in Fractals`
  - `pivot-only`
  を残す。
- ただし `ZigZag` は分析用にとどめ、主ロジックには使わない。

## 初回仕様書としての結論

- Method2 の初回実装は以下で固定する。
- Symbol:
  - `USDJPY`
- HTF:
  - `M15`
- LTF:
  - `M5`
- Trend:
  - `confirmed pivot based HH/HL or LL/LH`
- Pullback:
  - `LTF correction into HTF zone`
- Trigger:
  - `sweep -> reclaim -> short-term Dow shift`
- Stop:
  - `sweep extreme / trigger pivot + buffer`
- Target:
  - `1.5R` baseline
- Guards:
  - `spread`
  - `session`
  - `daily loss cap`
  - `equity DD cap`
  - `1 position max`
  - `max trades/day`
- Validation order:
  - `long-only`
  - `short-only`
  - `both`
  - `9m actual`
  - `3m OOS`

この仕様なら、次の turn でそのまま `MQL5 EA` に落とせる。
