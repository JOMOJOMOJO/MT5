# BTCUSD Feature Lab

- Symbol: `BTCUSD`
- Timeframe: `M15`
- Analysis window: `2025-04-01T14:00:00` -> `2026-04-01T14:00:00`
- Train / OOS split: `2025-04-01T14:00:00` -> `2026-01-02T13:45:00` / `2026-01-02T14:00:00` -> `2026-04-01T14:00:00`
- Full feature count: `60`
- Single-feature rule count: `847`
- Pair-rule count: `18`

## Top Correlations

- `spread_z` horizon `12`: train spearman `0.0657`, test spearman `-0.1519`
- `body_atr` horizon `3`: train spearman `-0.0520`, test spearman `-0.0564`
- `ret_1` horizon `3`: train spearman `-0.0478`, test spearman `-0.0510`
- `close_location` horizon `3`: train spearman `-0.0445`, test spearman `-0.0458`
- `tick_flow_signed_3` horizon `3`: train spearman `-0.0431`, test spearman `-0.0479`
- `stoch_spread` horizon `3`: train spearman `-0.0420`, test spearman `-0.0435`
- `stoch_k` horizon `3`: train spearman `-0.0357`, test spearman `-0.0547`
- `close_vs_ema50` horizon `6`: train spearman `-0.0350`, test spearman `-0.0386`

## Top Long Rules

- `ema_gap_20_50 >= 1.0387` horizon `12`: context `ny`, train `6.47/day PF-like exp 0.0838`, test `5.11/day exp 0.7583`, hit `55.51%`
- `close_vs_ema50 <= -1.6893` horizon `12`: context `late`, train `3.52/day PF-like exp 0.2535`, test `4.57/day exp 0.5114`, hit `72.37%`
- `macd_line_atr <= -0.5521` horizon `12`: context `late`, train `3.86/day PF-like exp 0.2120`, test `4.91/day exp 0.5264`, hit `70.34%`
- `ema_gap_10_20 <= -0.4398` horizon `12`: context `late`, train `3.70/day PF-like exp 0.1912`, test `4.69/day exp 0.4993`, hit `70.26%`
- `ema50_slope_6 <= -0.3968` horizon `12`: context `late`, train `3.71/day PF-like exp 0.1574`, test `4.83/day exp 0.4402`, hit `69.40%`

## Top Short Rules

- `ema_gap_50_100 >= 1.9019` horizon `12`: context `asia`, train `3.80/day exp 0.0160`, test `3.42/day exp 0.9562`, hit `75.55%`
- `spread_atr >= 0.1494` horizon `12`: context `ny`, train `6.07/day exp 0.1153`, test `7.46/day exp 0.8927`, hit `59.17%`
- `ema_gap_50_100 <= -1.0353` horizon `12`: context `ny`, train `6.06/day exp 0.1372`, test `9.63/day exp 0.8505`, hit `57.51%`
- `close_vs_ema50 >= 1.9306` horizon `12`: context `asia`, train `6.06/day exp 0.0388`, test `5.17/day exp 0.7065`, hit `65.79%`
- `tick_flow_signed_3 >= 0.4033` horizon `12`: context `all`, train `19.05/day exp 0.0147`, test `18.71/day exp 0.3513`, hit `55.60%`

## Top Long Pair Rules

- `late:close_vs_ema50 <= -1.6893` + `late:macd_line_atr <= -0.5521` horizon `12`: train `3.11/day exp 0.2291`, test `4.14/day exp 0.5547`, hit `74.42%`
- `late:close_vs_ema50 <= -1.6893` + `late:ema_gap_10_20 <= -0.4398` horizon `12`: train `3.04/day exp 0.2280`, test `4.05/day exp 0.5362`, hit `74.18%`
- `late:close_vs_ema50 <= -1.6893` + `late:ema50_slope_6 <= -0.3968` horizon `12`: train `3.05/day exp 0.2025`, test `4.18/day exp 0.5320`, hit `73.85%`
- `late:macd_line_atr <= -0.5521` + `late:ema_gap_20_50 <= -0.8779` horizon `12`: train `3.07/day exp 0.1306`, test `4.21/day exp 0.5583`, hit `73.14%`
- `late:ret_24 <= -0.0057` + `late:high_break_24 <= -4.0104` horizon `12`: train `3.06/day exp 0.2229`, test `3.50/day exp 0.5247`, hit `71.48%`

## Top Short Pair Rules

- `ny:ema_gap_50_100 <= -1.0353` + `ny:ema_gap_20_50 <= -0.8779` horizon `12`: train `3.24/day exp 0.0612`, test `6.14/day exp 1.1323`, hit `60.37%`
- `asia:close_vs_ema50 >= 1.9306` + `asia:ema_gap_20_50 >= 1.0387` horizon `12`: train `4.27/day exp 0.2096`, test `3.51/day exp 0.6147`, hit `69.26%`
- `all:bb_z <= -1.1809` + `all:macd_hist <= -0.1874` horizon `12`: train `11.77/day exp 0.1319`, test `12.42/day exp 0.3216`, hit `51.27%`
- `all:bb_z <= -1.1809` + `all:roc_atr_6 <= -1.2139` horizon `12`: train `13.28/day exp 0.0486`, test `14.67/day exp 0.3185`, hit `49.11%`
- `all:macd_hist <= -0.1874` + `all:roc_atr_6 <= -1.2139` horizon `12`: train `11.34/day exp 0.1019`, test `11.57/day exp 0.2405`, hit `50.63%`

## Next Step

- Use the best pair rules as the first entry masks for a new mainline prototype.
- Keep stop, reward, and capital doctrine fixed while validating the pair rules in MT5.
