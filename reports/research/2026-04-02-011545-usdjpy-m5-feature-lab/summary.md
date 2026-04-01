# BTCUSD Feature Lab

- Symbol: `USDJPY`
- Timeframe: `M5`
- Analysis window: `2025-04-01T19:15:00` -> `2026-04-01T19:15:00`
- Train / OOS split: `2025-04-01T19:15:00` -> `2025-12-31T19:10:00` / `2025-12-31T19:15:00` -> `2026-04-01T19:15:00`
- Full feature count: `60`
- Single-feature rule count: `1610`
- Pair-rule count: `32`

## Top Correlations

- `spread_z` horizon `12`: train spearman `0.0383`, test spearman `0.0652`
- `spread_change_3` horizon `3`: train spearman `-0.0311`, test spearman `-0.0416`
- `high_break_12` horizon `12`: train spearman `-0.0266`, test spearman `-0.0284`
- `spread_z` horizon `6`: train spearman `0.0261`, test spearman `0.0316`
- `spread_change_3` horizon `6`: train spearman `-0.0253`, test spearman `-0.0309`
- `bb_width` horizon `12`: train spearman `0.0241`, test spearman `-0.0362`
- `roc_atr_12` horizon `12`: train spearman `-0.0237`, test spearman `-0.0262`
- `adx14` horizon `12`: train spearman `0.0242`, test spearman `-0.0235`

## Top Long Rules

- `spread_points <= 15.0000` horizon `12`: context `ny`, train `57.99/day PF-like exp 0.0169`, test `104.95/day exp 0.5907`, hit `57.21%`
- `spread_points <= 15.0000` horizon `12`: context `ny`, train `57.99/day PF-like exp 0.0169`, test `104.95/day exp 0.5907`, hit `57.21%`
- `spread_price <= 0.0150` horizon `12`: context `ny`, train `57.99/day PF-like exp 0.0169`, test `104.95/day exp 0.5907`, hit `57.21%`
- `spread_price <= 0.0150` horizon `12`: context `ny`, train `57.99/day PF-like exp 0.0169`, test `104.95/day exp 0.5907`, hit `57.21%`
- `spread_z >= 0.0000` horizon `12`: context `all`, train `57.68/day PF-like exp 0.1291`, test `126.00/day exp 0.1594`, hit `54.01%`

## Top Short Rules

- `breakout_persist_up_6 >= 1.0000` horizon `12`: context `all`, train `60.61/day exp 0.0144`, test `63.36/day exp 0.0520`, hit `48.32%`
- `breakout_persist_up_6 >= 1.0000` horizon `6`: context `all`, train `60.61/day exp 0.0177`, test `63.38/day exp 0.0113`, hit `47.73%`
- `breakout_persist_up_6 >= 1.0000` horizon `3`: context `all`, train `60.61/day exp 0.0074`, test `63.39/day exp 0.0068`, hit `48.46%`
- `ema50_slope_6 >= 0.4890` horizon `12`: context `all`, train `41.02/day exp 0.0058`, test `44.15/day exp 0.2554`, hit `52.42%`
- `close_vs_ema50 >= 2.0685` horizon `12`: context `all`, train `41.00/day exp 0.0197`, test `44.16/day exp 0.2232`, hit `51.87%`

## Top Long Pair Rules

- `ny:spread_points <= 15.0000` + `ny:spread_points <= 15.0000` horizon `12`: train `57.99/day exp 0.0169`, test `104.95/day exp 0.5907`, hit `57.21%`
- `ny:spread_points <= 15.0000` + `ny:spread_price <= 0.0150` horizon `12`: train `57.99/day exp 0.0169`, test `104.95/day exp 0.5907`, hit `57.21%`
- `ny:spread_points <= 15.0000` + `ny:spread_price <= 0.0150` horizon `12`: train `57.99/day exp 0.0169`, test `104.95/day exp 0.5907`, hit `57.21%`
- `ny:spread_points <= 15.0000` + `ny:spread_price <= 0.0150` horizon `12`: train `57.99/day exp 0.0169`, test `104.95/day exp 0.5907`, hit `57.21%`
- `ny:spread_points <= 15.0000` + `ny:spread_price <= 0.0150` horizon `12`: train `57.99/day exp 0.0169`, test `104.95/day exp 0.5907`, hit `57.21%`

## Top Short Pair Rules

- `all:ema50_slope_6 >= 0.4890` + `all:close_vs_ema50 >= 2.0685` horizon `12`: train `33.72/day exp 0.0239`, test `36.47/day exp 0.2614`, hit `52.53%`
- `all:breakout_persist_up_6 >= 1.0000` + `all:stoch_d >= 81.5033` horizon `12`: train `34.08/day exp 0.0740`, test `39.25/day exp 0.0848`, hit `48.67%`
- `all:ema_gap_20_50 >= 1.0894` + `all:ema50_slope_6 >= 0.4890` horizon `6`: train `33.25/day exp 0.0117`, test `35.41/day exp 0.1328`, hit `50.36%`
- `all:breakout_persist_up_6 >= 1.0000` + `all:rsi14 >= 65.2500` horizon `12`: train `31.40/day exp 0.0321`, test `35.26/day exp 0.1194`, hit `49.49%`
- `all:rsi14 >= 65.2500` + `all:stoch_d >= 81.5033` horizon `12`: train `28.54/day exp 0.0839`, test `32.18/day exp 0.1461`, hit `50.27%`

## Next Step

- Use the best pair rules as the first entry masks for a new mainline prototype.
- Keep stop, reward, and capital doctrine fixed while validating the pair rules in MT5.
