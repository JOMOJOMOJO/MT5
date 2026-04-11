# USDJPY Method2 Triple Structure Spec

## 1. 戦略の考え方

### 目的

- `USDJPY` を対象に、`フラクタル構造 + ダウ理論 + トリプルトップ / 逆トリプルトップ` を土台にした `Method2` を作る。
- 単なる見た目パターンではなく、`状態遷移` として実装する。
- `上位足で文脈を決める`、`下位足で構造完成を確認する`、`score が一定以上なら入る` という構造にする。
- `高精度だが月数回` を避け、`M1-M15` の現実的な回転数を残す。

### 中核の考え方

- トリプルトップは `上昇継続の失敗` であり、以下の3段で扱う。
  - `上位足で上方向の波が成熟している`
  - `下位足で高値更新失敗が3回近い価格帯で起きる`
  - `ネックライン割れで上昇構造が壊れる`
- 逆トリプルトップはその反転であり、以下の3段で扱う。
  - `上位足で下方向の波が成熟している`
  - `下位足で安値更新失敗が3回近い価格帯で起きる`
  - `ネックライン上抜けで下降構造が壊れる`
- エントリーは `全条件一致` にしない。
  - `上位足文脈`
  - `パターン形状`
  - `ネックライン品質`
  - `ブレイク品質`
  - `実行環境`
  をスコア化し、一定点数以上で入る。

### 推奨する最初の基準

- Symbol: `USDJPY`
- HTF: `M15`
- LTF: `M5`
- 方向:
  - short: `triple top`
  - long: `inverse triple bottom`
- baseline は `M15 x M5` 固定で actual MT5 を通す。
- `M30 x M5`, `H1 x M15`, `M15 x M1` は二段階目で比較する。

## 2. 実装ルール一覧

### A. 上位足分析

- `confirmed pivot` だけを使う。
- `PivotSpan = 2` か `3` を初期候補にする。
- 直近2つの pivot high と pivot low でダウ判定する。
- Bull:
  - `latestHigh > previousHigh`
  - `latestLow > previousLow`
- Bear:
  - `latestHigh < previousHigh`
  - `latestLow < previousLow`
- Trend filter は厳格な通行証にしない。
  - triple top short なら `最近は上に伸びていた / 上位レンジ上部にいる / EMA がまだ上向き` でも可
  - inverse triple bottom long ならその反転
- 補助情報として以下を保持する。
  - `EMA20`, `EMA50`
  - `ATR`
  - `recent range high/low`
  - `range position`

### B. 下位足分析

- `confirmed pivot` で直近の swing 列を作る。
- triple top short は `H-L-H-L-H` の並びを探す。
- inverse triple bottom long は `L-H-L-H-L` の並びを探す。
- 3つの頂点 / 底値は `完全一致` ではなく `tolerance zone` で扱う。
- tolerance は以下で決める。
  - `max(MinPatternPips, ATR(LTF) * PatternToleranceATR)`

### C. トリプルトップ / 逆トリプルトップの構造定義

#### Triple top short

- 前提:
  - 直前に `上昇波` がある
  - 上位足で価格が `range upper half` にある
- 構造:
  - `peak1`, `peak2`, `peak3` が tolerance 内にある
  - `valley1`, `valley2` がそれぞれ明確に形成される
  - 3回目の高値で `明確な上抜け継続` が出ない
- ネックライン:
  - `min(valley1, valley2)` を baseline neck とする
- 確認:
  - `close < neckline - breakBuffer` を baseline confirmation とする

#### Inverse triple bottom long

- 前提:
  - 直前に `下降波` がある
  - 上位足で価格が `range lower half` にある
- 構造:
  - `bottom1`, `bottom2`, `bottom3` が tolerance 内にある
  - `reactionHigh1`, `reactionHigh2` が形成される
  - 3回目の安値で `明確な下抜け継続` が出ない
- ネックライン:
  - `max(reactionHigh1, reactionHigh2)` を baseline neck とする
- 確認:
  - `close > neckline + breakBuffer` を baseline confirmation とする

### D. エントリー判定

- `score >= InpMinimumPatternScore` で entry candidate にする。
- 方向ごとの baseline entry:
  - short:
    - triple top candidate
    - neckline close break
    - spread / session / risk guard pass
    - 次バーで sell
  - long:
    - inverse triple bottom candidate
    - neckline close break
    - spread / session / risk guard pass
    - 次バーで buy

### E. 損切り

- short:
  - `stop = max(peak1, peak2, peak3) + stopBuffer`
- long:
  - `stop = min(bottom1, bottom2, bottom3) - stopBuffer`
- `stopBuffer = max(MinStopBufferPips, ATR(LTF) * StopBufferATR)`

### F. 利確

- baseline:
  - `target = entry +/- risk * TargetR`
- 二段階目の比較:
  - `previous HTF swing`
  - `partial at 1R, final at 1.8R`
- 最初の検証では `fixed R` に固定する。

### G. スコアリング

#### short / long 共通の score 項目

- `HTF context`
  - range edge に近い: `+2`
  - prior trend maturity: `+1`
- `pattern geometry`
  - 3頂点 / 3底値が tolerance 内: `+3`
  - 2つだけ強く近い / 1つは準パターン: `+2`
- `neckline quality`
  - valley / reaction high の深さが十分: `+1`
- `failure quality`
  - 3回目で更新失敗が明確: `+1`
- `break quality`
  - close break with body: `+2`
  - low/high break only: `+1`
- `execution quality`
  - spread / active session / minimum target distance pass: `+1`

#### grade

- `Strong`: `score >= 8`
- `Standard`: `score >= 6`
- `Soft`: `score >= 5`
- baseline entry は `score >= 6`
- 回数重視の probe は `score >= 5`

## 3. 回数が減りすぎる原因分析

### 優先順位つきの原因

1. `上位足条件を厳しくしすぎる`
   - `HTFが完全に反転済み` まで待つと triple reversal の早い優位性が消える
2. `下位足確認を入れすぎる`
   - triple top 完成
   - neckline break close
   - retest
   - 追加 candle filter
   を全部積むと回数が消える
3. `トリプルトップの定義を exact pattern にしすぎる`
   - 高値3点がほぼ同値
   - 谷2点も明確
   - しかも spacing も固定
   は sparse になりやすい
4. `ネックライン確定を待ちすぎる`
   - `close break + next close confirmation + retest` まで待つと良い局面も失う
5. `時間帯 / spread / volatility の除外が重なりすぎる`
6. `1 swing 1 entry` 制限が厳しすぎる
7. `stop width / target distance` の下限が高すぎる
8. `全条件一致型` で partial edge を拾えない

### 何を緩めると回数が増えるか

- `exact equal highs/lows` をやめて tolerance zone にする
- `strict pass/fail` をやめて score 方式にする
- `Strong` と `Standard` を分ける
- `close break only` のままでも、retest 必須をやめる
- `HTF fully reversed` を要求せず、`成熟した伸び + range edge` でも許可する
- `blocked hours` は event study ベースで外す

### どこを緩めると質が落ちやすいか

- `spread guard`
- `minimum stop distance`
- `breakout body quality`
- `pattern tolerance` を広げすぎること
- `session guard` を無差別に広げること
- `max simultaneous filters` を減らしすぎて、単なる逆張りになること

### 安全に回数を増やす順番

1. `score threshold` を `8 -> 6` へ下げる
2. `exact pattern` を `zone pattern` にする
3. `retest 必須` をやめる
4. `時間帯` を event study で最適化する
5. `HTF strict reversal` を `mature trend + range edge` に緩める
6. それでも不足するなら `HTF/LTF` 組み合わせを増やす

## 4. 回数を確保するための改善案

### 完全形と準パターンを分ける

- `Strong`
  - 3頂点 / 3底値が tight
  - neckline 深さも十分
  - break body も良い
- `Standard`
  - 3つのうち1つがややずれる
  - それでも break quality が良い

### 全条件一致ではなく score 合計型

- entry trigger は `all true` ではなく `score >= threshold`
- こうすると以下が可能になる
  - complete でないが有望な局面を拾う
  - 回数と質の tradeoff を段階的に比較できる
  - 各条件の寄与度を tester で見やすい

### 時間帯を構造の一部として扱う

- `USDJPY` は時間帯ごとに spread と follow-through が変わる
- pattern quality より `execution environment` が結果を壊すことがある
- したがって filter は追加条件ではなく `execution score` として扱う

### 組み合わせの優先順位

- 1段目:
  - `M15 x M5`
- 2段目:
  - `M30 x M5`
  - `H1 x M15`
- 3段目:
  - `M15 x M1`

## 5. MQL5向け関数設計

### データ構造

```cpp
struct PivotPoint
{
   bool     valid;
   bool     isHigh;
   int      shift;
   double   price;
   datetime time;
};

struct TrendContext
{
   int      direction;
   PivotPoint latestHigh;
   PivotPoint previousHigh;
   PivotPoint latestLow;
   PivotPoint previousLow;
   double   emaFast;
   double   emaSlow;
   double   atr;
   double   rangeHigh;
   double   rangeLow;
   double   rangePosition;
};

struct TriplePattern
{
   bool     valid;
   int      direction;
   int      score;
   string   grade;
   PivotPoint extreme1;
   PivotPoint reaction1;
   PivotPoint extreme2;
   PivotPoint reaction2;
   PivotPoint extreme3;
   double   zoneCenter;
   double   tolerance;
   double   neckline;
   double   stopAnchor;
   bool     breakoutConfirmed;
   string   label;
};

struct EntryPlan
{
   bool     valid;
   int      direction;
   int      score;
   double   entry;
   double   stop;
   double   target;
   string   reason;
};
```

### 関数一覧

```cpp
bool IsNewBar(ENUM_TIMEFRAMES tf, datetime &barTime);
bool IsPivotHigh(string symbol, ENUM_TIMEFRAMES tf, int shift, int span);
bool IsPivotLow(string symbol, ENUM_TIMEFRAMES tf, int shift, int span);
bool CollectConfirmedPivots(string symbol, ENUM_TIMEFRAMES tf, int span, int scanBars, PivotPoint &pivots[]);
bool BuildTrendContext(TrendContext &ctx);
double ComputePatternTolerance(double ltfAtr);
bool EvaluateTripleTop(const TrendContext &ctx, TriplePattern &pattern);
bool EvaluateInverseTripleBottom(const TrendContext &ctx, TriplePattern &pattern);
int ScoreTripleTopCandidate(const TrendContext &ctx, const TriplePattern &pattern);
int ScoreInverseTripleBottomCandidate(const TrendContext &ctx, const TriplePattern &pattern);
bool BuildEntryPlan(const TriplePattern &pattern, EntryPlan &plan);
bool PassGlobalGuards();
bool ExecuteEntry(const EntryPlan &plan);
void ManageOpenPositions();
```

## 6. 疑似コード

```text
OnTick():
  if not new LTF bar:
    return

  update day state
  update equity peak
  manage open positions

  if not pass global guards:
    return

  htf = BuildTrendContext()
  if not htf.valid:
    return

  shortPattern = EvaluateTripleTop(htf)
  if shortPattern.valid and shortPattern.score >= MinPatternScore:
    plan = BuildEntryPlan(shortPattern)
    if plan.valid:
      ExecuteEntry(plan)

  longPattern = EvaluateInverseTripleBottom(htf)
  if longPattern.valid and longPattern.score >= MinPatternScore:
    plan = BuildEntryPlan(longPattern)
    if plan.valid:
      ExecuteEntry(plan)
```

### short side detail

```text
EvaluateTripleTop():
  collect recent LTF pivots
  scan latest H-L-H-L-H sequences
  for each candidate:
    compute tolerance zone
    reject if peaks are too far apart
    compute neckline from the 2 valleys
    check prior rise and HTF range position
    check third failure quality
    check neckline break quality on close
    score candidate
  return best recent candidate
```

### long side detail

```text
EvaluateInverseTripleBottom():
  collect recent LTF pivots
  scan latest L-H-L-H-L sequences
  mirror the short logic
```

## 7. EA骨組みコード

- 骨組みEAは [usdjpy_20260411_triple_structure_method2_scaffold.mq5](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/mql/Experts/usdjpy_20260411_triple_structure_method2_scaffold.mq5) に置く。
- 役割:
  - confirmed pivot 収集
  - HTF trend context 作成
  - triple top / inverse triple bottom 候補評価
  - scoring
  - risk-based order plan
  - minimal position management

## 8. 最適化時に見るべき指標

### 優先指標

- `net profit`
- `profit factor`
- `max balance DD`
- `max equity DD`
- `trade count`
- `avg trade`
- `expectancy in R`
- `latest 3m OOS contribution`

### 回数面の最低ライン

- `9m train` で最低でも `60 trades` は欲しい
- `理想` は `1 trade / 3 days` 以上
- sparse run で `PF 3.0` が出ても promotion しない

### 二次指標

- hour bucket ごとの PF
- long / short 別 PF
- `Strong` / `Standard` 別 PF
- score bucket ごとの勝率と avg trade

### promotion rule

- まず `Strong only`
- 次に `Strong + Standard`
- それでも回数不足なら `HTF/LTF` 組み合わせ比較
- `Soft` は exploration 用で、初回 promotion 対象にはしない
