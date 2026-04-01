# BTCUSD Feature Lab

- Symbol: `BTCUSD`
- Timeframe: `M5`
- Analysis window: `2025-04-16T12:25:00` -> `2026-04-01T08:25:00`
- Train / OOS split: `2025-04-16T12:25:00` -> `2026-01-02T08:20:00` / `2026-01-02T08:25:00` -> `2026-04-01T08:25:00`
- Full feature count: `39`
- Single-feature rule count: `993`
- Pair-rule count: `39`

## Top Correlations

- `roc_atr_6` horizon `6`: train spearman `-0.0445`, test spearman `-0.0589`
- `high_break_12` horizon `3`: train spearman `-0.0443`, test spearman `-0.0593`
- `high_break_12` horizon `6`: train spearman `-0.0437`, test spearman `-0.0563`
- `rsi7` horizon `6`: train spearman `-0.0427`, test spearman `-0.0606`
- `rsi7` horizon `3`: train spearman `-0.0414`, test spearman `-0.0606`
- `bb_z` horizon `6`: train spearman `-0.0404`, test spearman `-0.0508`
- `stoch_k` horizon `6`: train spearman `-0.0402`, test spearman `-0.0538`
- `close_vs_ema20` horizon `3`: train spearman `-0.0401`, test spearman `-0.0657`

## Top Long Rules

- `roc_atr_6 <= -1.3739` horizon `6`: context `all`, train `57.09/day PF-like exp 0.0799`, test `58.12/day exp 0.0231`, hit `55.48%`
- `range_compression_12 >= 0.0075` horizon `12`: context `all`, train `57.44/day PF-like exp 0.0372`, test `111.83/day exp 0.0705`, hit `51.57%`
- `rsi7 <= 29.5772` horizon `6`: context `all`, train `56.78/day PF-like exp 0.0878`, test `60.38/day exp 0.0355`, hit `54.57%`
- `roc_atr_6 <= -1.3739` horizon `3`: context `all`, train `57.09/day PF-like exp 0.0491`, test `58.12/day exp 0.0341`, hit `55.05%`
- `high_break_12 <= -3.0687` horizon `3`: context `all`, train `57.10/day PF-like exp 0.0495`, test `57.61/day exp 0.0226`, hit `55.33%`

## Top Short Rules

- `rsi7 >= 70.3688` horizon `6`: context `all`, train `56.75/day exp 0.0117`, test `56.77/day exp 0.1307`, hit `54.05%`
- `rsi7 >= 70.3688` horizon `3`: context `all`, train `56.75/day exp 0.0184`, test `56.77/day exp 0.0875`, hit `55.47%`
- `ret_3 >= 0.0012` horizon `6`: context `all`, train `57.07/day exp 0.0085`, test `71.39/day exp 0.1094`, hit `53.12%`
- `tick_volume_z >= 0.8247` horizon `12`: context `all`, train `57.09/day exp 0.0312`, test `54.70/day exp 0.2073`, hit `49.65%`
- `ret_6 >= 0.0017` horizon `6`: context `all`, train `57.07/day exp 0.0081`, test `71.97/day exp 0.0944`, hit `53.15%`

## Top Long Pair Rules

- `all:close_vs_ema20 <= -1.1293` + `all:ema20_slope_3 <= -0.3403` horizon `3`: train `45.74/day exp 0.0598`, test `46.33/day exp 0.0153`, hit `56.29%`
- `all:roc_atr_6 <= -1.3739` + `all:ret_6 <= -0.0016` horizon `3`: train `43.81/day exp 0.0252`, test `50.79/day exp 0.0388`, hit `55.30%`
- `all:roc_atr_6 <= -1.3739` + `all:ret_6 <= -0.0016` horizon `6`: train `43.81/day exp 0.0421`, test `50.79/day exp 0.0214`, hit `55.90%`
- `all:high_break_12 <= -3.0687` + `all:close_vs_ema20 <= -1.1293` horizon `3`: train `43.10/day exp 0.0574`, test `43.76/day exp 0.0257`, hit `56.26%`
- `all:range_compression_12 >= 0.0075` + `all:range_compression_24 >= 0.0108` horizon `12`: train `42.18/day exp 0.0388`, test `93.42/day exp 0.0918`, hit `51.81%`

## Top Short Pair Rules

- `all:rsi7 >= 70.3688` + `all:ret_6 >= 0.0017` horizon `6`: train `36.43/day exp 0.0187`, test `42.10/day exp 0.1218`, hit `54.59%`
- `all:rsi7 >= 70.3688` + `all:ret_6 >= 0.0017` horizon `3`: train `36.43/day exp 0.0220`, test `42.10/day exp 0.0763`, hit `56.01%`
- `all:rsi7 >= 70.3688` + `all:high_break_12 >= -0.5770` horizon `6`: train `34.96/day exp 0.0489`, test `32.03/day exp 0.1850`, hit `55.79%`
- `all:ret_6 >= 0.0017` + `all:high_break_12 >= -0.5770` horizon `6`: train `32.83/day exp 0.0487`, test `34.74/day exp 0.1536`, hit `54.80%`
- `all:rsi7 >= 70.3688` + `all:macd_hist >= 0.1951` horizon `3`: train `33.66/day exp 0.0147`, test `32.92/day exp 0.1076`, hit `55.70%`

## Next Step

- Use the best pair rules as the first entry masks for a new mainline prototype.
- Keep stop, reward, and capital doctrine fixed while validating the pair rules in MT5.
