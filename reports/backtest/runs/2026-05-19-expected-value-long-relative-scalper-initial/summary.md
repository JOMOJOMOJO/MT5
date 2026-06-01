# ExpectedValue Long-Only Relative Scalper Initial Validation

## Purpose

Build a separate long-only EA candidate for small-capital testing without touching the live short-only `ExpectedValue_NWave_Scalper`.

## EA

- Source: `mql/Experts/ExpectedValue_LongOnly_RelativeScalper.mq5`
- Symbol / timeframe: `USDJPY / M5`
- Direction: long-only
- Logic reused from prior long-side work:
  - `EMA13 / EMA100` trend continuation
  - pullback / dip-continuation entries
  - stop-first sizing
  - time stop
  - hard risk guards

## Implementation Notes

- Fixed-lot mode below an equity threshold:
  - `InpFixedLot`
  - `InpFixedLotEquityThreshold`
- Risk-percent sizing above the threshold:
  - `InpRiskPercent`
- Broker volume constraints:
  - symbol min lot
  - symbol max lot
  - symbol lot step
  - optional `InpMaxLotCap`
- Margin insufficiency blocks entry.
- Native SL and TP are always sent with the order.
- TP defaults to `1.5R`.
- SL is derived from ATR and recent swing low:
  - `max(structural swing-low stop, ATR stop, minimum ATR stop)`
- Safety controls:
  - daily max loss
  - weekly max loss
  - max account drawdown
  - max consecutive losses
  - max open positions
  - total open risk cap
  - averaging-down block
  - cooldown bars
  - risk-stop flattening
- Logs include:
  - entry
  - exit reason: `TP`, `SL`, `TIMEOUT`, `RISK_STOP`, `MANUAL_OR_UNKNOWN`
  - stop-condition trigger timing
  - filter reject reason
  - relative metrics such as `Spread/ATR`, `EMA distance/ATR`, `Body/ATR`, `ATR ratio`, and range position

## Compile

- Log: `reports/compile/ExpectedValue_LongOnly_RelativeScalper.log`
- Result: `0 errors, 0 warnings`

## 2025 IS Results

| Preset | Spread/ATR cap | Trades | Trades/day approx | ExpectancyR | PF | MaxDD% | Max loss streak | Result |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| strict | 0.12 | 23 | 0.09 | +0.2203 | 1.7616 | 7.21 | 4 | profitable but far too sparse |
| balanced | 0.20 | 176 | 0.68 | -0.0177 | 0.9590 | 24.23 | 10 | non-ruin, but not profitable |
| high-turnover | 0.35 | 128 | stopped early | -0.3368 | 0.4619 | 45.00 | 9 | rejected; max DD stop triggered |

The high-turnover setting proved why spread looseness cannot be used as the main way to reach the trade-count target. It increased signal count but quickly moved into ruin-risk behavior.

## 2026 Jan-Apr OOS

The OOS run was executed only after selecting the `balanced` probe from 2025 as the non-ruin frequency test.

| Preset | Trades | ExpectancyR | PF | MaxDD% | Max loss streak | Result |
|---|---:|---:|---:|---:|---:|---|
| balanced | 11 | -0.6064 | 0.1156 | 11.47 | 5 | rejected; OOS edge failed |

## Monthly Readout

- `balanced 2025`: profits were not concentrated in one month, but edge quality was weak. Positive months existed in Apr, Jun, Sep, Oct, Dec, while Jan-Mar and several later months were negative.
- `balanced 2026 Jan-Apr`: only Jan-Mar had closed trades; all three active months were negative.

## Diagnostics

Main reject reasons:

- strict 2025:
  - `spread_atr_too_wide`: 44,379
  - `session_filter_failed`: 27,857
  - `ema_trend_filter_failed`: 1,111
- balanced 2025:
  - `spread_atr_too_wide`: 34,667
  - `session_filter_failed`: 27,857
  - `ema_trend_filter_failed`: 6,652
- balanced 2026 Jan-Apr:
  - `spread_atr_too_wide`: 13,952
  - `session_filter_failed`: 9,072
  - `ema_trend_filter_failed`: 748

Stop-condition logging was confirmed. Examples:

- `max_consecutive_losses` triggered in `balanced 2025`
- `max_drawdown` triggered in `high-turnover 2025`

## Evidence

- Initial strict preset:
  - `reports/presets/ExpectedValue_LongOnly_RelativeScalper_usd100_research_2025.set`
  - `reports/presets/ExpectedValue_LongOnly_RelativeScalper_usd100_research_2026_jan_apr.set`
- Balanced preset:
  - `reports/presets/ExpectedValue_LongOnly_RelativeScalper_usd100_balanced_2025.set`
  - `reports/presets/ExpectedValue_LongOnly_RelativeScalper_usd100_balanced_2026_jan_apr.set`
- High-turnover rejected preset:
  - `reports/presets/ExpectedValue_LongOnly_RelativeScalper_usd100_high_turnover_2025.set`
  - `reports/presets/ExpectedValue_LongOnly_RelativeScalper_usd100_high_turnover_2026_jan_apr.set`
- Tester INI:
  - `reports/backtest/runs/2026-05-19-expected-value-long-relative-scalper-initial/ini/`
- Tester reports:
  - `reports/backtest/runs/2026-05-19-expected-value-long-relative-scalper-initial/*.htm`
- EA CSV logs copied from `FILE_COMMON`:
  - `reports/backtest/runs/2026-05-19-expected-value-long-relative-scalper-initial/raw/`

## Decision

This EA scaffold is implemented and usable for further research, but no current preset is demo/live ready.

- strict: positive but too sparse for the user's target
- balanced: better frequency but no edge
- high-turnover: rejected by drawdown stop

Next research should not loosen spread further. A new long-only bucket or a different market-state split is needed to approach `5 trades/day` without pushing the account into drawdown-stop behavior.
