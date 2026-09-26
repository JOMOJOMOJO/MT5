# M1 EMA alignment entry gate

## Rule
Standard USDJPY_M1_M5_3WaveIn3Wave_Long v1.03 only. On each fresh READY, require closed M1 EMA20 > EMA50 > EMA100. Default additionally requires each EMA at shift 1 > its own shift 2. Equality fails. This is bullish ordering and positive slopes, not equal-angle parallelism. User requested alignment; slope definition was asked asynchronously, then the recommended default was explicitly announced while awaiting an answer. `InpEMARequireRising=false` selects ordering only. `InpUseEMAFilter=false` restores the previous entry path.

EMA uses native iMA MODE_EMA PRICE_CLOSE, shift 1/2 only. Missing data rejects the candidate. No delayed retry of a rejected READY. Existing position management is unchanged. Display and filter switches are independent; hidden calculation handles avoid duplicate native EMA lines in visual tester. Inputs/Shared and CC variant are untouched.

## Evidence
- [Compile](compile.log): 0 errors, 0 warnings.
- [Final ON native Model4 January 2025](../ema_filter_final/tester.log), RR1.
- [OFF comparison](../ema_filter_off/tester.log), same final binary, period and inputs except gate.
- [Independent audit](audit.json): recorded EMA values checked against archived M1 close data using pandas EWM; previous and current closed-bar values and gate results checked. Candidate IDs must match ON/OFF; blocked candidates must have no orders.
- Final build differs from the initial smoke build only by hiding the calculation handles. Final build rerun is authoritative.
- Source and binary before changes: before.mq5, before.ex5.

## Presets
Original RR10/RR12 presets now explicitly disable the gate so that loading them preserves the historical strategy. New EMAAligned RR10/RR12 presets enable ordering and rising; all optimize flags off. MQL5/Profiles/Tester copies updated. Other settings match Original.

## Limits / plateau review
January ON: 23 READY, 12 orders, 11 rejected for EMA ordering. This fails the minimum 20/month frequency goal. A single month is functional validation, not evidence of improved profitability or promotion. January did not exercise the ordered-but-not-all-rising or missing-data branches. Visual UI inspection and multi-period OOS profitability comparison were not performed. No threshold optimization.
