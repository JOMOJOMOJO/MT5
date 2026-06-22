# Multi-Currency Structure Research Lessons

Date: 2026-06-22

This file preserves reusable lessons from the Phase2 / ThirdWave / Nested N-Wave / Structural BOS research cycle.

## Core Lesson

この研究ファミリーの主な失敗は、パラメータの悪さではなく、entry triggerが上位足の構造edgeを十分に表現していなかったことにある。

M15のブレイク、retest、candle quality、sweep/reclaimを単独で増やしても、H4/H1のcontextが弱いと候補数が増えるほど負ける。

## Keep

- Multi-currencyで最初から見る。
- `SYMBOL_RESEARCH_ALL` / `TRADE_DIRECTION_BOTH` を本線前提にする。
- all-candidates modeで候補の分布を確認する。
- `result_R` / `avg_R` を必ず見る。
- MFE/MAE/R到達率で、TPが遠いのかentry後に伸びないのかを分ける。
- symbol / direction / session / month / regime / labelで分解する。
- short-period gateの後にannual/OOS gateへ進む。
- Python後処理で仮説を作ったら、MT5固定research modeで再現確認する。
- 早期failはsummary counterへ集約し、詳細CSVはentry candidate / order result / execution block中心にする。
- `room_to_1R` / `room_to_2R` は重要な診断として残す。

## Avoid

- XAUUSDだけで良い結果を汎用edgeとみなす。
- LONG_ONLY / SHORT_ONLYだけで良い結果を汎用edgeとみなす。
- USDJPY short除外など、個別symbol/direction回避で本線を作る。
- Friday stopや曜日/時間フィルターを戦略edgeとして混ぜる。
- 2025だけに合わせる。
- M15足のbody/wick/close strength閾値を重ねて改善したように見せる。
- RewardR/SL幅調整でentry thesisの弱さを隠す。
- trade countを減らすだけのfilterをedgeと勘違いする。
- confirmed fractal reclaim/breakdownを「3波初動」と呼ぶ。

## Specific Findings

### Phase2

- Direction split and symbol split are diagnostic tools, not promotion logic.
- LONG branch can look good while BOTH remains weak.
- SHORT weakness cannot be ignored if the intended EA is symmetrical and multi-currency.

### ThirdWave

- Current ThirdWave behaved as trend-continuation/chasing, not true third-wave initial.
- v3 proved that strict entry-position filtering removes most trades, which means the detector was not early enough.
- LowerTF SL and smaller R can help some samples but do not fix weak context.

### Nested N-Wave

- Neckline break without context is false-break prone.
- Retest confirmation reduces some losses but deletes strong break-and-go winners.
- Breakout/router labels are useful diagnostics, but not enough as a standalone edge.
- Clean labels must be audited against human-readable structure, not just condition-pass logic.

### Structural BOS

- True BOS must invalidate a defined countertrend structure.
- Recent high/low break is not enough.
- H4/H1 pivot sequence matters more than M15 candle quality.
- If stricter structure removes almost all trades, the definition may be too narrow or the instrument/timeframe thesis may be wrong.

### FX-only Broad Candidates

- Removing XAUUSD revealed that the structural edge was weak.
- Broad candidate expansion without context produces thousands of losing trades.
- `room_to_2r` reduces damage but is not a standalone edge.

## Next EA Design Rules

1. Define higher-timeframe context before writing entry triggers.
2. Define whose structure is being invalidated.
3. Define where the trade thesis is invalidated before calculating lot size.
4. Label room to target before judging RewardR.
5. Use M15 as execution confirmation, not as the primary thesis.
6. Keep symbol and direction filters out of the mainline.
7. Promote only if the edge survives multiple years and FX/XAUUSD separation.

## Useful Diagnostics To Reuse

- `result_R`
- `avg_R`
- `max_favorable_r`
- `max_adverse_r`
- `reached_0_5R`
- `reached_1R`
- `reached_2R`
- `failure_type`
- `winning_type`
- `setup_failure_layer`
- `wave_audit_label`
- `reversal_signal_type`
- `entry_trigger_type`
- `room_to_1R`
- `room_to_2R`
- `h4_context_label`
- `h1_counter_structure_label`
- `m15_execution_label`

## Stop Rule For Similar Families

If three consecutive branches only improve by:

- reducing trade count,
- concentrating in XAUUSD,
- selecting one direction,
- or adding time/symbol filters,

then park the family and start a new thesis.

That condition has been met for this research family.
