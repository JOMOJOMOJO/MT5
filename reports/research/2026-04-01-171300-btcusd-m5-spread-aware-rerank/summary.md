# BTCUSD Spread-Aware Re-Rank

- Features: `C:\Users\windows\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\MQL5\Experts\dev\reports\research\2026-04-01-171300-btcusd-m5-feature-lab-spreadfix\analysis_window_features.csv.gz`
- Split date: `2026-01-02T10:10:00`
- Cost floor quantile: `0.75`

## Broker Spread Floor

- mean `0.2327 ATR`
- median `0.1918 ATR`
- p75 `0.2751 ATR`
- p90 `0.4012 ATR`

## Promotable Rules

- `(ema_gap_20_50 <= -1.3698491409549307)` horizon `12`: test `7.92/day exp 0.5374`, spread floor `0.2194`, net `0.3180`
- `(macd_line_atr >= 0.9664991804238436)` horizon `12`: test `6.63/day exp 0.5221`, spread floor `0.2189`, net `0.3032`
- `(ema_gap_50_100 <= -1.6928388037485844)` horizon `12`: test `10.65/day exp 0.5398`, spread floor `0.2644`, net `0.2754`
- `(ret_24 <= -0.0056613738716477)` horizon `12`: test `9.54/day exp 0.4041`, spread floor `0.1650`, net `0.2391`
- `(macd_line_atr <= -0.869920056320943)` horizon `12`: test `5.62/day exp 0.4575`, spread floor `0.2195`, net `0.2379`
- `(bb_z <= -1.675619408583442)` horizon `12`: test `4.52/day exp 0.5067`, spread floor `0.2730`, net `0.2337`
- `(ema50_slope_6 <= -0.620545774915175)` horizon `12`: test `6.41/day exp 0.4482`, spread floor `0.2191`, net `0.2292`
- `(macd_hist <= -0.2943564255777498)` horizon `12`: test `3.97/day exp 0.4837`, spread floor `0.2749`, net `0.2088`
- `(high_break_24 >= -0.3645223794025753)` horizon `12`: test `8.58/day exp 0.4868`, spread floor `0.2896`, net `0.1972`
- `(high_break_24 <= -5.285006808207483)` horizon `12`: test `4.54/day exp 0.4658`, spread floor `0.2755`, net `0.1902`

## Top Ranked Rules

- `(ema_gap_20_50 <= -1.3698491409549307)` horizon `12`: test `7.92/day exp 0.5374`, spread floor `0.2194`, net `0.3180`
- `(macd_line_atr >= 0.9664991804238436)` horizon `12`: test `6.63/day exp 0.5221`, spread floor `0.2189`, net `0.3032`
- `(ema_gap_50_100 <= -1.6928388037485844)` horizon `12`: test `10.65/day exp 0.5398`, spread floor `0.2644`, net `0.2754`
- `(ret_24 <= -0.0056613738716477)` horizon `12`: test `9.54/day exp 0.4041`, spread floor `0.1650`, net `0.2391`
- `(macd_line_atr <= -0.869920056320943)` horizon `12`: test `5.62/day exp 0.4575`, spread floor `0.2195`, net `0.2379`
- `(bb_z <= -1.675619408583442)` horizon `12`: test `4.52/day exp 0.5067`, spread floor `0.2730`, net `0.2337`
- `(ema50_slope_6 <= -0.620545774915175)` horizon `12`: test `6.41/day exp 0.4482`, spread floor `0.2191`, net `0.2292`
- `(macd_hist <= -0.2943564255777498)` horizon `12`: test `3.97/day exp 0.4837`, spread floor `0.2749`, net `0.2088`
- `(high_break_24 >= -0.3645223794025753)` horizon `12`: test `8.58/day exp 0.4868`, spread floor `0.2896`, net `0.1972`
- `(high_break_24 <= -5.285006808207483)` horizon `12`: test `4.54/day exp 0.4658`, spread floor `0.2755`, net `0.1902`

## Verdict

- Open the next actual MT5 prototype only from the promotable rules above.
