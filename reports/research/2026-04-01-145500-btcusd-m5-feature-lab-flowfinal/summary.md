# BTCUSD Feature Lab

- Symbol: `BTCUSD`
- Timeframe: `M5`
- Analysis window: `2025-04-16T12:45:00` -> `2026-04-01T08:45:00`
- Train / OOS split: `2025-04-16T12:45:00` -> `2026-01-02T08:40:00` / `2026-01-02T08:45:00` -> `2026-04-01T08:45:00`
- Full feature count: `59`
- Single-feature rule count: `1165`
- Pair-rule count: `46`

## Top Correlations

- `roc_atr_6` horizon `6`: train spearman `-0.0445`, test spearman `-0.0589`
- `high_break_12` horizon `3`: train spearman `-0.0443`, test spearman `-0.0594`
- `high_break_12` horizon `6`: train spearman `-0.0437`, test spearman `-0.0564`
- `rsi7` horizon `6`: train spearman `-0.0427`, test spearman `-0.0605`
- `rsi7` horizon `3`: train spearman `-0.0414`, test spearman `-0.0607`
- `bb_z` horizon `6`: train spearman `-0.0404`, test spearman `-0.0508`
- `stoch_k` horizon `6`: train spearman `-0.0403`, test spearman `-0.0538`
- `close_vs_ema20` horizon `3`: train spearman `-0.0401`, test spearman `-0.0658`

## Top Long Rules

- `breakout_persist_down_6 >= 1.0000` horizon `3`: context `all`, train `82.96/day PF-like exp 0.0288`, test `82.27/day exp 0.0060`, hit `53.27%`
- `roc_atr_6 <= -1.3739` horizon `6`: context `all`, train `57.09/day PF-like exp 0.0799`, test `58.12/day exp 0.0231`, hit `55.48%`
- `range_compression_12 >= 0.0075` horizon `12`: context `all`, train `57.44/day PF-like exp 0.0372`, test `111.83/day exp 0.0705`, hit `51.57%`
- `rsi7 <= 29.5772` horizon `6`: context `all`, train `56.78/day PF-like exp 0.0878`, test `60.38/day exp 0.0355`, hit `54.57%`
- `roc_atr_6 <= -1.3739` horizon `3`: context `all`, train `57.09/day PF-like exp 0.0491`, test `58.12/day exp 0.0341`, hit `55.05%`

## Top Short Rules

- `breakout_persist_up_6 >= 1.0000` horizon `3`: context `all`, train `83.94/day exp 0.0049`, test `78.35/day exp 0.0588`, hit `54.13%`
- `rsi7 >= 70.3714` horizon `6`: context `all`, train `56.74/day exp 0.0115`, test `56.73/day exp 0.1311`, hit `54.06%`
- `rsi7 >= 70.3714` horizon `3`: context `all`, train `56.74/day exp 0.0183`, test `56.76/day exp 0.0877`, hit `55.49%`
- `ret_3 >= 0.0012` horizon `6`: context `all`, train `57.07/day exp 0.0086`, test `71.43/day exp 0.1094`, hit `53.10%`
- `tick_volume_z >= 0.8244` horizon `12`: context `all`, train `57.07/day exp 0.0322`, test `54.75/day exp 0.2071`, hit `49.65%`

## Top Long Pair Rules

- `all:breakout_persist_down_6 >= 1.0000` + `all:ema20_slope_3 <= -0.3403` horizon `3`: train `46.72/day exp 0.0465`, test `47.76/day exp 0.0197`, hit `56.15%`
- `all:breakout_persist_down_6 >= 1.0000` + `all:high_break_12 <= -3.0687` horizon `3`: train `45.57/day exp 0.0456`, test `46.93/day exp 0.0352`, hit `55.98%`
- `all:close_vs_ema20 <= -1.1293` + `all:ema20_slope_3 <= -0.3403` horizon `3`: train `45.74/day exp 0.0598`, test `46.33/day exp 0.0153`, hit `56.29%`
- `all:breakout_persist_down_6 >= 1.0000` + `all:close_vs_ema20 <= -1.1293` horizon `3`: train `45.37/day exp 0.0517`, test `45.69/day exp 0.0271`, hit `56.24%`
- `all:roc_atr_6 <= -1.3739` + `all:ret_6 <= -0.0016` horizon `3`: train `43.82/day exp 0.0252`, test `50.79/day exp 0.0388`, hit `55.30%`

## Top Short Pair Rules

- `all:breakout_persist_up_6 >= 1.0000` + `all:ret_6 >= 0.0017` horizon `3`: train `38.71/day exp 0.0037`, test `43.41/day exp 0.0681`, hit `55.94%`
- `all:breakout_persist_up_6 >= 1.0000` + `all:rsi7 >= 70.3714` horizon `3`: train `40.31/day exp 0.0124`, test `37.30/day exp 0.0960`, hit `56.70%`
- `all:rsi7 >= 70.3714` + `all:ret_6 >= 0.0017` horizon `6`: train `36.42/day exp 0.0184`, test `42.07/day exp 0.1224`, hit `54.61%`
- `all:rsi7 >= 70.3714` + `all:ret_6 >= 0.0017` horizon `3`: train `36.42/day exp 0.0219`, test `42.09/day exp 0.0766`, hit `56.03%`
- `all:rsi7 >= 70.3714` + `all:high_break_12 >= -0.5768` horizon `6`: train `34.95/day exp 0.0487`, test `32.03/day exp 0.1850`, hit `55.79%`

## Next Step

- Use the best pair rules as the first entry masks for a new mainline prototype.
- Keep stop, reward, and capital doctrine fixed while validating the pair rules in MT5.
