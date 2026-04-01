# BTCUSD Feature Lab

- Symbol: `BTCUSD`
- Timeframe: `M5`
- Analysis window: `2025-04-16T14:10:00` -> `2026-04-01T10:10:00`
- Train / OOS split: `2025-04-16T14:10:00` -> `2026-01-02T10:05:00` / `2026-01-02T10:10:00` -> `2026-04-01T10:10:00`
- Full feature count: `60`
- Single-feature rule count: `1169`
- Pair-rule count: `46`

## Top Correlations

- `roc_atr_6` horizon `6`: train spearman `-0.0445`, test spearman `-0.0582`
- `high_break_12` horizon `3`: train spearman `-0.0443`, test spearman `-0.0587`
- `high_break_12` horizon `6`: train spearman `-0.0438`, test spearman `-0.0556`
- `rsi7` horizon `6`: train spearman `-0.0428`, test spearman `-0.0598`
- `rsi7` horizon `3`: train spearman `-0.0414`, test spearman `-0.0602`
- `bb_z` horizon `6`: train spearman `-0.0405`, test spearman `-0.0496`
- `stoch_k` horizon `6`: train spearman `-0.0404`, test spearman `-0.0527`
- `close_vs_ema20` horizon `3`: train spearman `-0.0402`, test spearman `-0.0649`

## Top Long Rules

- `breakout_persist_down_6 >= 1.0000` horizon `3`: context `all`, train `82.96/day PF-like exp 0.0288`, test `82.27/day exp 0.0060`, hit `53.27%`
- `range_compression_12 >= 0.0075` horizon `12`: context `all`, train `57.44/day PF-like exp 0.0372`, test `111.82/day exp 0.0740`, hit `51.61%`
- `roc_atr_6 <= -1.3740` horizon `6`: context `all`, train `57.08/day PF-like exp 0.0799`, test `58.17/day exp 0.0214`, hit `55.46%`
- `roc_atr_6 <= -1.3740` horizon `3`: context `all`, train `57.08/day PF-like exp 0.0487`, test `58.17/day exp 0.0343`, hit `55.09%`
- `rsi7 <= 29.5750` horizon `6`: context `all`, train `56.76/day PF-like exp 0.0892`, test `60.40/day exp 0.0326`, hit `54.52%`

## Top Short Rules

- `breakout_persist_up_6 >= 1.0000` horizon `3`: context `all`, train `83.92/day exp 0.0051`, test `78.45/day exp 0.0578`, hit `54.09%`
- `rsi7 >= 70.3669` horizon `6`: context `all`, train `56.76/day exp 0.0116`, test `56.80/day exp 0.1301`, hit `54.03%`
- `rsi7 >= 70.3669` horizon `3`: context `all`, train `56.76/day exp 0.0183`, test `56.81/day exp 0.0867`, hit `55.47%`
- `ret_3 >= 0.0012` horizon `6`: context `all`, train `57.07/day exp 0.0086`, test `71.52/day exp 0.1076`, hit `53.10%`
- `ret_6 >= 0.0017` horizon `6`: context `all`, train `57.08/day exp 0.0082`, test `72.06/day exp 0.0926`, hit `53.12%`

## Top Long Pair Rules

- `all:breakout_persist_down_6 >= 1.0000` + `all:ema20_slope_3 <= -0.3403` horizon `3`: train `46.72/day exp 0.0463`, test `47.76/day exp 0.0197`, hit `56.15%`
- `all:breakout_persist_down_6 >= 1.0000` + `all:high_break_12 <= -3.0688` horizon `3`: train `45.57/day exp 0.0456`, test `46.93/day exp 0.0352`, hit `55.98%`
- `all:close_vs_ema20 <= -1.1293` + `all:ema20_slope_3 <= -0.3403` horizon `3`: train `45.74/day exp 0.0596`, test `46.33/day exp 0.0153`, hit `56.29%`
- `all:breakout_persist_down_6 >= 1.0000` + `all:close_vs_ema20 <= -1.1293` horizon `3`: train `45.37/day exp 0.0517`, test `45.69/day exp 0.0271`, hit `56.24%`
- `all:roc_atr_6 <= -1.3740` + `all:ret_6 <= -0.0016` horizon `3`: train `43.79/day exp 0.0247`, test `50.86/day exp 0.0388`, hit `55.31%`

## Top Short Pair Rules

- `all:breakout_persist_up_6 >= 1.0000` + `all:ret_6 >= 0.0017` horizon `3`: train `38.72/day exp 0.0034`, test `43.51/day exp 0.0658`, hit `55.84%`
- `all:breakout_persist_up_6 >= 1.0000` + `all:rsi7 >= 70.3669` horizon `3`: train `40.34/day exp 0.0127`, test `37.35/day exp 0.0939`, hit `56.65%`
- `all:rsi7 >= 70.3669` + `all:ret_6 >= 0.0017` horizon `6`: train `36.44/day exp 0.0186`, test `42.14/day exp 0.1209`, hit `54.57%`
- `all:rsi7 >= 70.3669` + `all:ret_6 >= 0.0017` horizon `3`: train `36.44/day exp 0.0218`, test `42.15/day exp 0.0746`, hit `55.96%`
- `all:rsi7 >= 70.3669` + `all:high_break_12 >= -0.5778` horizon `6`: train `34.96/day exp 0.0486`, test `32.07/day exp 0.1830`, hit `55.77%`

## Next Step

- Use the best pair rules as the first entry masks for a new mainline prototype.
- Keep stop, reward, and capital doctrine fixed while validating the pair rules in MT5.
