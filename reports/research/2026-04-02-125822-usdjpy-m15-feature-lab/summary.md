# BTCUSD Feature Lab

- Symbol: `USDJPY`
- Timeframe: `M15`
- Analysis window: `2025-04-02T06:45:00` -> `2026-04-02T06:45:00`
- Train / OOS split: `2025-04-02T06:45:00` -> `2026-01-02T23:45:00` / `2026-01-05T00:00:00` -> `2026-04-02T06:45:00`
- Full feature count: `60`
- Single-feature rule count: `1104`
- Pair-rule count: `27`

## Top Correlations

- `adx14` horizon `12`: train spearman `-0.0424`, test spearman `-0.0569`
- `breakout_persist_up_6` horizon `12`: train spearman `0.0326`, test spearman `-0.0842`
- `high_break_24` horizon `12`: train spearman `0.0313`, test spearman `-0.0405`
- `range_compression_12` horizon `12`: train spearman `0.0308`, test spearman `-0.0900`
- `adx14` horizon `6`: train spearman `-0.0296`, test spearman `-0.0526`
- `spread_acceleration_3` horizon `3`: train spearman `-0.0281`, test spearman `-0.0373`
- `ema_gap_10_20` horizon `12`: train spearman `0.0268`, test spearman `-0.0520`
- `bb_width` horizon `6`: train spearman `0.0252`, test spearman `-0.0768`

## Top Long Rules

- `spread_points <= 15.0000` horizon `12`: context `all`, train `43.97/day PF-like exp 0.0510`, test `18.89/day exp 0.1583`, hit `61.96%`
- `spread_points <= 15.0000` horizon `12`: context `all`, train `43.97/day PF-like exp 0.0510`, test `18.89/day exp 0.1583`, hit `61.96%`
- `spread_price <= 0.0150` horizon `12`: context `all`, train `43.97/day PF-like exp 0.0510`, test `18.89/day exp 0.1583`, hit `61.96%`
- `spread_price <= 0.0150` horizon `12`: context `all`, train `43.97/day PF-like exp 0.0510`, test `18.89/day exp 0.1583`, hit `61.96%`
- `adx14 <= 20.4865` horizon `12`: context `all`, train `13.64/day PF-like exp 0.3700`, test `12.82/day exp 0.2641`, hit `61.66%`

## Top Short Rules

- `spread_points <= 15.0000` horizon `3`: context `all`, train `43.97/day exp 0.0052`, test `18.89/day exp 0.0875`, hit `51.81%`
- `spread_points <= 15.0000` horizon `3`: context `all`, train `43.97/day exp 0.0052`, test `18.89/day exp 0.0875`, hit `51.81%`
- `spread_price <= 0.0150` horizon `3`: context `all`, train `43.97/day exp 0.0052`, test `18.89/day exp 0.0875`, hit `51.81%`
- `spread_price <= 0.0150` horizon `3`: context `all`, train `43.97/day exp 0.0052`, test `18.89/day exp 0.0875`, hit `51.81%`
- `close_vs_ema20 >= 1.8129` horizon `12`: context `late`, train `1.06/day exp 0.1980`, test `1.14/day exp 1.2045`, hit `85.42%`

## Top Long Pair Rules

- `all:spread_points <= 15.0000` + `all:spread_points <= 15.0000` horizon `12`: train `43.97/day exp 0.0510`, test `18.89/day exp 0.1583`, hit `61.96%`
- `all:spread_points <= 15.0000` + `all:spread_price <= 0.0150` horizon `12`: train `43.97/day exp 0.0510`, test `18.89/day exp 0.1583`, hit `61.96%`
- `all:spread_points <= 15.0000` + `all:spread_price <= 0.0150` horizon `12`: train `43.97/day exp 0.0510`, test `18.89/day exp 0.1583`, hit `61.96%`
- `all:spread_points <= 15.0000` + `all:spread_price <= 0.0150` horizon `12`: train `43.97/day exp 0.0510`, test `18.89/day exp 0.1583`, hit `61.96%`
- `all:spread_points <= 15.0000` + `all:spread_price <= 0.0150` horizon `12`: train `43.97/day exp 0.0510`, test `18.89/day exp 0.1583`, hit `61.96%`

## Top Short Pair Rules

- `all:spread_points <= 15.0000` + `all:spread_points <= 15.0000` horizon `3`: train `43.97/day exp 0.0052`, test `18.89/day exp 0.0875`, hit `51.81%`
- `all:spread_points <= 15.0000` + `all:spread_price <= 0.0150` horizon `3`: train `43.97/day exp 0.0052`, test `18.89/day exp 0.0875`, hit `51.81%`
- `all:spread_points <= 15.0000` + `all:spread_price <= 0.0150` horizon `3`: train `43.97/day exp 0.0052`, test `18.89/day exp 0.0875`, hit `51.81%`
- `all:spread_points <= 15.0000` + `all:spread_price <= 0.0150` horizon `3`: train `43.97/day exp 0.0052`, test `18.89/day exp 0.0875`, hit `51.81%`
- `all:spread_points <= 15.0000` + `all:spread_price <= 0.0150` horizon `3`: train `43.97/day exp 0.0052`, test `18.89/day exp 0.0875`, hit `51.81%`

## Next Step

- Use the best pair rules as the first entry masks for a new mainline prototype.
- Keep stop, reward, and capital doctrine fixed while validating the pair rules in MT5.
