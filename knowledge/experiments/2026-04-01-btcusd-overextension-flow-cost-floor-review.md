# BTCUSD Overextension Flow Cost Floor Review

## What Was Built

- Added a focused flow-filter probe on top of the latest BTCUSD M5 feature dump.
- Built a new prototype EA:
  - `mql/Experts/btcusd_20260401_overextension_flow.mq5`
- Tested three actual MT5 variants:
  - baseline short-highbreak
  - baseline OOS 3m
  - flow-only short candidate

## What The Data Said Before Trading Costs

- The feature lab and flow probe found attractive bar-data edges:
  - long `roc_atr_6 <= -1.3739` + `rsi7 <= 29.5772`
  - short `rsi7 >= 70.3714` + `ret_6 >= 0.0017` + positive `tick_flow_signed_3`
- Those edges looked high-turnover in bar space:
  - often `17` to `45` trades/day in the train/test analysis

## What Actual MT5 Said

- Baseline 1y actual:
  - net `-1186.30`
  - PF `0.53`
  - trades `116`
- Baseline OOS 3m actual:
  - net `-886.83`
  - PF `0.53`
  - trades `82`
- Flow-only short 1y actual:
  - net `-1165.68`
  - PF `0.22`
  - trades `52`

## Why The Bar Edge Did Not Survive

- The current broker's BTCUSD M5 spread is too large for the first high-turnover pair rules.
- Spread in ATR terms from the feature dump:
  - mean `0.2263 ATR`
  - median `0.1904 ATR`
  - 75th percentile `0.2724 ATR`
- That cost floor is larger than most of the attractive pair-rule OOS expectancies:
  - many pair rules were only `0.03` to `0.18 ATR`
- Conclusion:
  - the pair-rule family looked good in raw chart behavior,
  - but it was not large enough to beat execution costs on this broker feed.

## Volume / Flow Judgement

- Volume and flow still mattered.
- They were useful for explaining market behavior and ranking exhaustion quality.
- But they did **not** rescue the first M5 pair-rule family once real spread was applied.
- The best use of volume/flow in this cycle was diagnostic:
  - it helped identify crowded upside conditions,
  - but the move size was still too small after costs.

## Decision

- Park `btcusd_20260401_overextension_flow` as a rejected first mainline prototype.
- Do not keep tuning this exact family.
- Open the next mainline only from features whose OOS expectancy is comfortably above the broker cost floor.

## Next Research Gate

- On this broker, BTCUSD M5 mainline candidates should usually clear at least:
  - `test_expectancy >= 0.25 ATR`
  - preferably `>= 0.30 ATR`
- Before the next EA prototype:
  - re-rank the feature lab with spread-aware screening,
  - prefer `12-bar` horizon rules and larger-move continuation / regime signals,
  - do not promote another high-turnover M5 pair rule unless it clears the cost floor first.
