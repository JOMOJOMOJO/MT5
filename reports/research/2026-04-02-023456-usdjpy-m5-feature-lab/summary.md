# BTCUSD Feature Lab

- Symbol: `USDJPY`
- Timeframe: `M5`
- Analysis window: `2025-04-01T20:30:00` -> `2026-04-01T20:30:00`
- Train / OOS split: `2025-04-01T20:30:00` -> `2026-01-02T20:25:00` / `2026-01-02T20:30:00` -> `2026-04-01T20:30:00`
- Full feature count: `60`
- Single-feature rule count: `1663`
- Pair-rule count: `33`

## Top Correlations

- `spread_z` horizon `12`: train spearman `0.0400`, test spearman `0.0601`
- `spread_change_3` horizon `3`: train spearman `-0.0306`, test spearman `-0.0440`
- `spread_z` horizon `6`: train spearman `0.0275`, test spearman `0.0269`
- `high_break_12` horizon `12`: train spearman `-0.0263`, test spearman `-0.0296`
- `spread_change_3` horizon `6`: train spearman `-0.0251`, test spearman `-0.0324`
- `adx14` horizon `12`: train spearman `0.0241`, test spearman `-0.0240`
- `roc_atr_12` horizon `12`: train spearman `-0.0236`, test spearman `-0.0270`
- `stoch_k` horizon `12`: train spearman `-0.0235`, test spearman `-0.0236`

## Top Long Rules

- `spread_points <= 15.0000` horizon `12`: context `ny`, train `57.99/day PF-like exp 0.0169`, test `104.95/day exp 0.5907`, hit `57.21%`
- `spread_points <= 15.0000` horizon `12`: context `ny`, train `57.99/day PF-like exp 0.0169`, test `104.95/day exp 0.5907`, hit `57.21%`
- `spread_price <= 0.0150` horizon `12`: context `ny`, train `57.99/day PF-like exp 0.0169`, test `104.95/day exp 0.5907`, hit `57.21%`
- `spread_price <= 0.0150` horizon `12`: context `ny`, train `57.99/day PF-like exp 0.0169`, test `104.95/day exp 0.5907`, hit `57.21%`
- `spread_z >= 0.0000` horizon `12`: context `all`, train `57.58/day PF-like exp 0.1417`, test `127.96/day exp 0.1415`, hit `53.79%`

## Top Short Rules

- `breakout_persist_up_6 >= 1.0000` horizon `12`: context `all`, train `60.49/day exp 0.0132`, test `63.82/day exp 0.0567`, hit `48.39%`
- `breakout_persist_up_6 >= 1.0000` horizon `6`: context `all`, train `60.49/day exp 0.0175`, test `63.83/day exp 0.0129`, hit `47.82%`
- `breakout_persist_up_6 >= 1.0000` horizon `3`: context `all`, train `60.49/day exp 0.0070`, test `63.83/day exp 0.0080`, hit `48.50%`
- `ema50_slope_6 >= 0.4882` horizon `12`: context `all`, train `40.92/day exp 0.0008`, test `44.09/day exp 0.2691`, hit `52.55%`
- `close_vs_ema50 >= 2.0675` horizon `12`: context `all`, train `40.92/day exp 0.0159`, test `43.99/day exp 0.2341`, hit `51.93%`

## Top Long Pair Rules

- `ny:spread_points <= 15.0000` + `ny:spread_points <= 15.0000` horizon `12`: train `57.99/day exp 0.0169`, test `104.95/day exp 0.5907`, hit `57.21%`
- `ny:spread_points <= 15.0000` + `ny:spread_price <= 0.0150` horizon `12`: train `57.99/day exp 0.0169`, test `104.95/day exp 0.5907`, hit `57.21%`
- `ny:spread_points <= 15.0000` + `ny:spread_price <= 0.0150` horizon `12`: train `57.99/day exp 0.0169`, test `104.95/day exp 0.5907`, hit `57.21%`
- `ny:spread_points <= 15.0000` + `ny:spread_price <= 0.0150` horizon `12`: train `57.99/day exp 0.0169`, test `104.95/day exp 0.5907`, hit `57.21%`
- `ny:spread_points <= 15.0000` + `ny:spread_price <= 0.0150` horizon `12`: train `57.99/day exp 0.0169`, test `104.95/day exp 0.5907`, hit `57.21%`

## Top Short Pair Rules

- `all:ema50_slope_6 >= 0.4882` + `all:close_vs_ema50 >= 2.0675` horizon `12`: train `33.65/day exp 0.0171`, test `36.38/day exp 0.2784`, hit `52.67%`
- `all:breakout_persist_up_6 >= 1.0000` + `all:stoch_d >= 81.5197` horizon `12`: train `33.99/day exp 0.0722`, test `39.44/day exp 0.0908`, hit `48.83%`
- `all:ema_gap_20_50 >= 1.0883` + `all:ema50_slope_6 >= 0.4882` horizon `6`: train `33.23/day exp 0.0090`, test `35.28/day exp 0.1389`, hit `50.43%`
- `all:breakout_persist_up_6 >= 1.0000` + `all:rsi14 >= 65.2672` horizon `12`: train `31.31/day exp 0.0308`, test `34.92/day exp 0.1275`, hit `49.61%`
- `all:rsi14 >= 65.2672` + `all:stoch_d >= 81.5197` horizon `12`: train `28.47/day exp 0.0795`, test `32.30/day exp 0.1578`, hit `50.50%`

## Next Step

- Use the best pair rules as the first entry masks for a new mainline prototype.
- Keep stop, reward, and capital doctrine fixed while validating the pair rules in MT5.
