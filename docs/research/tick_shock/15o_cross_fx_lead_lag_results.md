# Step 15O Cross-FX Lead-Lag Direction Study 結果

## 結論

2025年4月のdevelopment検証では、Cross-FX情報に条件付きの方向構成差は見つかったが、実行可能な売買edgeには変換できなかった。

- `CROSS_FX_BREADTH_SIGNAL_NOT_FOUND`
- `CROSS_FX_LEAD_LAG_SIGNAL_NOT_FOUND`
- `TARGET_RESIDUAL_SIGNAL_WEAK`
- `CROSS_FX_NO_TRADE_SIGNAL_WEAK`
- `CROSS_FX_DIRECTION_SIGNAL_WEAK`
- `CROSS_FX_TRADE_EDGE_NOT_FOUND`
- `OOS_VALIDATION_NOT_JUSTIFIED`
- `PRODUCTION_NOT_ELIGIBLE`

AprilはTick-shock / Cross-FX lead-lag系列では未使用だったが、別EAで利用済みなのでOOSではない。結果を見て月、detector、1/3/5/10秒窓、0.10 ATR lead閾値、H1-H4、TP 0.40 ATR、SL 0.25 ATR、15分deadline、model設定を変更していない。

## Formal MT5 run

- Run: `reports/backtest/runs/20260908_ts15o_cross_fx_lead_lag_r2_202504/`
- Period: 2025-04-01 00:00:00 から 2025-05-01 00:00:00（end exclusive）
- Driver/model: EURUSD M1 / real ticks
- Symbols: EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF
- Runtime: 28分18.521秒
- Total ticks: 14,085,619
- Tester memory: 624 MB（history 48 MB、tick data 320 MB）
- Compile: research EA 0 errors / 0 warnings
- Actual orders/trades: 0 / 0
- 全tick CSV、1秒CSV: 出力なし

r1はraw current/anchor価格が不足して独立再計算できなかったため、正式解釈には使っていない。r2は列を追加しただけであり、IDを正規化したr1/r2比較は3 artifact、差分0だった。

## Population

| Stage | Episodes | Market clusters |
|---|---:|---:|
| Cross-FX feature rows | 3,967 | 3,746 |
| TARGET_STALE | 3,024 | 2,940 |
| CROSS_SYMBOL_STALE | 555 | 546 |
| ELIGIBLE | 388 | 356 |
| Action rows | 7,934 | 3,746 |

正式なPhase A/Bは、targetと他5通貨が500ms以内で揃った388 episode / 356 market clustersだけを使用した。feature行の約90.2%はfreshness要件を満たさず、削除せずstatusとして保存した。この低いeligible率は、Cross-FX featureを現行global merge上でリアルタイム利用する際の重要な制約である。

generated fallback minutesとmissing intervalは今回も`NOT_OBSERVED`であり、ゼロと主張しない。全6通貨でtester journal上のreal-tick discard warningは0だった。

## Phase A

Baseline 388件では、Continuation TP 46、Reversal TP 47、Both-SL 295（76.03%）だった。Continuation固定は平均−1.117R、PF 0.145、Reversal固定は平均−1.153R、PF 0.144である。OracleはNo Tradeを許すため平均+0.384Rだが、これは実装可能policyの成績ではない。

| Strategy/state | Episodes | Clusters | TP | SL | Both-SL | Gross expectancy | Net expectancy at 0.05R | PF | Positive folds |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| All shocks Continuation | 388 | 356 | 46 | 342 | 295 | −1.117R | −1.167R | 0.145 | n/a |
| All shocks Reversal | 388 | 356 | 47 | 341 | 295 | −1.153R | −1.203R | 0.144 | n/a |
| H1 confirmation / Continuation | 214 | 203 | 24 | 190 | 157 | −0.999R | −1.049R | 0.152 | n/a |
| H2 isolated / Reversal | 52 | 51 | 2 | 50 | 40 | −1.351R | −1.401R | 0.044 | n/a |
| H3 lagging / Continuation | 10 | 10 | 3 | 7 | 7 | −0.784R | −0.834R | 0.380 | n/a |
| H4 overextended / Reversal | 260 | 239 | 28 | 232 | 207 | −1.295R | −1.345R | 0.117 | n/a |

H2ではtradeable 12件中Continuation-onlyが10件、Reversal-onlyが2件で、baselineからのContinuation share差は+33.87pp、cluster bootstrap 95% CIは+10.55から+54.43ppだった。これは事前仮説の「isolatedならReversal」と逆向きである。H3はtradeable 3件がすべてContinuation-onlyでgateを通過したが、10 clustersしかない。両者はPhase Bを開始するための固定gateを満たしたものの、利益を示していない。

H1のBoth-SL低下は2.67pp（CI −1.23から+6.53pp）でgate未達。H4はBoth-SLが逆に3.58pp増え、その差のCIも悪化側だった。breadth 5/5はBoth-SL 71.94%だが、H1全体として頑健な低下ではない。lead bucketのBoth-SLは70.97%から78.95%の範囲で、事前定義した明確なlead-lag順序効果は確認できなかった。

## Phase B

Phase A gate通過後にのみ、固定したchronological market-cluster splitでPhase Bを実行した。各foldのthresholdはtraining rowsだけで決め、validation結果から変更していない。

| Feature/model | Trades | Clusters | TP | SL/TIME | Gross expectancy | Net expectancy at 0.05R | Positive folds |
|---|---:|---:|---:|---:|---:|---:|---:|
| MODEL_X / LightGBM | 47 | 46 | 7 | 40 | −0.800R | −0.850R | 0/4 |
| MODEL_X / Logistic | 106 | 103 | 12 | 94 | −1.062R | −1.112R | 0/4 |
| MODEL_X_PLUS_EXISTING / LightGBM | 42 | 41 | 6 | 36 | −0.688R | −0.738R | 0/4 |
| MODEL_X_PLUS_EXISTING / Logistic | 69 | 67 | 7 | 62 | −0.933R | −0.983R | 0/4 |

全model、全foldでnet expectancyは負だった。0.02R、0.05R、0.10Rのcommission sensitivityでも符号は変わらない。APは0.176から0.211程度、AUCは0.588から0.697程度だが、今回のprimary判定は実現Rであり、分類指標だけをedgeとみなさない。

## QAと独立再計算

- QA: 18 PASS / 0 FAIL
- deterministic rerun: 主要CSV 20/20 SHA一致
- r1/r2 behavior: 3/3一致、差分行0
- entry causality、future quote、future processing、hindsight anchor、future cluster source: 違反0
- duplicate episode/action、split overlap、chronology violation: 0
- TP R、SL optimism、actual trade、production order call: 違反0
- raw return、consensus、residual、lead state、H1-H4: 独立再計算一致
- TP/SL/TIMEOUT: horizon summaryが利用可能な7,876 actionで独立再計算一致

制約として、CSV表示精度ではゼロになったUSDCHF 1秒returnが1件あり、その符号だけはMQL内部値から独立復元できなかった。またrun終端の29 episode / 58 actionは900秒excursion summaryがcensorされ、保存済みsummaryだけでは独立再分類できない。いずれもPASSへ数えず`NOT_OBSERVED`として記録した。formal action engine自体の結果は保持されている。

## 判断

Cross-FXには「tradeableだった場合の方向構成」を変える小さな兆候がある。しかし、事前固定actionは全て大幅な負期待値で、Phase Bも全fold負だった。加えてfreshness適格が388件に限られ、H3は10 clustersしかない。このため、別の完全未使用期間を消費する価値がある段階には達していない。

次に許されるのは、追加月で成績を探すことではなく、今回の情報不足をレビューして新しい研究仮説を事前登録するか、この方向系列を停止する判断である。現行結果からEA化、OOS昇格、production化は行わない。
