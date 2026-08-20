# TRENDLINE_WAVE2_FAILURE Initial Validation

- Date: 2026-08-15
- Hypothesis: H4の構造破壊を伴う急変後、H1の成熟とトレンドライン突破を経て、M15の旧方向継続失敗を取れば、固定2Rで検証可能な反転bucketになる。
- Target EA: `ExpectedValue_MultiCurrency_FractalWave2TransitionTrader.mq5`
- Symbols: USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD
- Timeframe: H4 / H1 / M15
- Tags: reversal, closed-bar, state-machine, multi-currency, initial-research

## Planned Change

- 既存H1/M15/M5 bucketを残し、`TRENDLINE_WAVE2_FAILURE` を独立状態・独立Magic・独立CSVで追加する。
- `LEGACY_ONLY / NEW_ONLY / COMBINED` と `LONG / SHORT / BOTH` を切り替え可能にする。
- 確定足、pivot time、confirmation timeを分け、後から確定したスイングを過去の判定へ使わない。

## Rule Classification

- `SOURCE_RULE`: H4急変、H1の複数波成熟、H1トレンドライン突破、第2波候補、M15旧トレンド失敗、保護スイング突破。
- `OPERATIONAL_DEFINITION`: SMA20の傾き区間でスイングを確定し、H4構造・H1成熟・M15転換を閉じたバーの状態遷移へ変換した。
- `RESEARCH_PARAMETER`: ATR倍率、95パーセンタイル、2本傾き確認、72/32本失効、SLバッファ、固定2R、0.5% per trade等。

## Validation

- MT5 Strategy Tester、Every tick based on real ticks、M15チャート、USD 10,000、1:100。
- 2024 / 2025 / 2026-01-01〜2026-08-14を、Baseline / New only / Combinedで固定run。
- 2026を見る前にソース・include・presetのSHA-256を [OOS lock](../../reports/backtest/runs/20260815_trendline_wave2_failure/oos_lock.json) へ保存した。
- 詳細: [summary](../../reports/backtest/runs/20260815_trendline_wave2_failure/summary.md)、[comparison](../../reports/backtest/runs/20260815_trendline_wave2_failure/comparison.csv)、[funnel](../../reports/backtest/runs/20260815_trendline_wave2_failure/new_bucket_funnel.csv)。

## Result

- New bucket orders: 2024=0、2025=0、2026=0。
- Funnel:
  - 2024: H4 impulse 80 → H1 mature 4 → TL break 1 → M15 pullback 0。
  - 2025: 48 → 3 → 2 → 2 → M15 continuation failure 0。
  - 2026: 40 → 1 → 1 → M15 pullback 0。
- New-onlyとCombinedの新bucket funnelは全期間一致した。
- MT5約定数と独自取引CSVは9runすべて一致した。新bucketは双方0件。
- Baselineは2024 PF 0.986、2025 PF 0.686、2026 PF 1.115。Combinedは新bucket注文がないためほぼ同じで、2025のみ同方向上限が既存候補1件を拒否した。

## Systematic EA Trader Review

- Setup: 急変後の反転を複数時間足の構造で絞る、低頻度reversal設計。
- Market fit: H4の極端な急変後にH1が十分成熟し、さらにM15で旧方向失敗が明確になる局面だけを対象とする。
- Rule quality: future reference防止と状態分離は明確。一方、現在のゲート積は年単位でも注文へ到達しない。
- Cost sensitivity: entry gateへ到達していないため未評価。実装はspreadを必須計上し、推定往復コスト0.10R上限を持つ。
- Decision: 期待値不足ではなく標本不足。promotion不可、research bucketのまま維持する。

## Risk Map

- Per trade: equityの0.5%。
- Planned reward: fixed 2R。
- Total open risk: 2.0%。
- Currency-direction risk: 1.0%。
- Position caps: total 4 / symbol 1 / same direction 3 / setup 1。
- Stops: daily equity -2%、weekly -4%、high-water -10%。全体停止は自動解除しない。
- Margin: projected margin level 200%以上。
- Missing empirical guards: 新bucket注文0件のため、最小lot拒否、SL補正後risk、post-fill 2R、margin/currency-risk拒否は実注文で未到達。
- Kill criterion: 実注文標本が得られる前に成績最適化へ進まない。構造ゲートを無断で緩和しない。

## Next Experiments

1. 2024/2025だけで、H4反対構造更新の代替定義（現在の終値更新 vs 確定H4スイング更新）を1要因比較する。2026は再利用してOOSと呼ばない。
2. M15 protected swing未成立、pattern age、pattern height、failure classificationを非取引診断として個別集計する。
3. 注文件数が得られた場合のみ、FULL_PATTERN_EXTREME固定のままcost/lot/risk実経路を検証する。TP、session、symbol、directionは同時に変更しない。
