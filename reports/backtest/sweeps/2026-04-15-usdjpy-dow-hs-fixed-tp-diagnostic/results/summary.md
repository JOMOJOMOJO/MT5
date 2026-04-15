# USDJPY Dow HS Fixed TP Diagnostic

- total runs: 108
- triggers: `neck_close_confirm`
- fixed slice: `Tier A strict`, `short-only`, structural stop intact, acceptance exit on, runner/BE off in diagnostic mode
- pairs: `M30 x M15 x M3`, `M15 x M10 x M5`
- TP grid: `2 / 3 / 4 / 5 / 6 / 8` pips
- hold bars: `16 / 24 / 32`

## TRAIN

| slug | pair | trigger | tp | hold | trades | pf | net | exp payoff | max dd % | win rate % | avg R | cfg tp hit % | mfe p50 | mfe p75 | stop<tp % | accept<tp % | time<tp % |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| train-m15_m10_m5-neck_close_confirm-tp2-h16 | M15 x M10 x M5 | neck_close_confirm | 2 | 16 | 32 | 0.34 | -67.28 | -2.10 | 0.74 | 65.62 | -0.0619 | 62.50 | 2.00 | 2.20 | 0.00 | 15.62 | 18.75 |
| train-m15_m10_m5-neck_close_confirm-tp2-h24 | M15 x M10 x M5 | neck_close_confirm | 2 | 24 | 27 | 0.31 | -64.87 | -2.40 | 0.73 | 62.96 | -0.0620 | 61.54 | 2.10 | 2.20 | 0.00 | 19.23 | 15.38 |
| train-m15_m10_m5-neck_close_confirm-tp2-h32 | M15 x M10 x M5 | neck_close_confirm | 2 | 32 | 27 | 0.39 | -52.46 | -1.94 | 0.65 | 70.37 | -0.0577 | 66.67 | 2.10 | 2.20 | 0.00 | 18.52 | 11.11 |
| train-m15_m10_m5-neck_close_confirm-tp3-h16 | M15 x M10 x M5 | neck_close_confirm | 3 | 16 | 30 | 0.32 | -81.29 | -2.71 | 0.85 | 60.00 | -0.0792 | 60.00 | 3.00 | 3.10 | 0.00 | 16.67 | 23.33 |
| train-m15_m10_m5-neck_close_confirm-tp3-h24 | M15 x M10 x M5 | neck_close_confirm | 3 | 24 | 26 | 0.25 | -100.99 | -3.88 | 1.06 | 57.69 | -0.1068 | 60.00 | 3.00 | 3.10 | 4.00 | 20.00 | 16.00 |
| train-m15_m10_m5-neck_close_confirm-tp3-h32 | M15 x M10 x M5 | neck_close_confirm | 3 | 32 | 25 | 0.49 | -44.28 | -1.77 | 0.60 | 68.00 | -0.0522 | 68.00 | 3.00 | 3.10 | 0.00 | 20.00 | 12.00 |
| train-m15_m10_m5-neck_close_confirm-tp4-h16 | M15 x M10 x M5 | neck_close_confirm | 4 | 16 | 29 | 0.37 | -79.86 | -2.75 | 0.83 | 51.72 | -0.0808 | 44.83 | 3.90 | 4.30 | 0.00 | 17.24 | 34.48 |
| train-m15_m10_m5-neck_close_confirm-tp4-h24 | M15 x M10 x M5 | neck_close_confirm | 4 | 24 | 24 | 0.30 | -95.70 | -3.99 | 0.99 | 50.00 | -0.1094 | 43.48 | 4.00 | 4.30 | 4.35 | 21.74 | 21.74 |
| train-m15_m10_m5-neck_close_confirm-tp4-h32 | M15 x M10 x M5 | neck_close_confirm | 4 | 32 | 23 | 0.43 | -59.66 | -2.59 | 0.63 | 56.52 | -0.0764 | 47.83 | 4.00 | 4.30 | 0.00 | 21.74 | 21.74 |
| train-m15_m10_m5-neck_close_confirm-tp5-h16 | M15 x M10 x M5 | neck_close_confirm | 5 | 16 | 29 | 0.44 | -70.71 | -2.44 | 0.74 | 51.72 | -0.0713 | 37.93 | 3.90 | 5.10 | 0.00 | 17.24 | 34.48 |
| train-m15_m10_m5-neck_close_confirm-tp5-h24 | M15 x M10 x M5 | neck_close_confirm | 5 | 24 | 24 | 0.35 | -88.02 | -3.67 | 0.92 | 50.00 | -0.0994 | 39.13 | 5.00 | 5.15 | 4.35 | 21.74 | 21.74 |
| train-m15_m10_m5-neck_close_confirm-tp5-h32 | M15 x M10 x M5 | neck_close_confirm | 5 | 32 | 22 | 0.44 | -61.39 | -2.79 | 0.65 | 54.55 | -0.0817 | 40.91 | 5.00 | 5.17 | 0.00 | 22.73 | 22.73 |
| train-m15_m10_m5-neck_close_confirm-tp6-h16 | M15 x M10 x M5 | neck_close_confirm | 6 | 16 | 29 | 0.44 | -71.03 | -2.45 | 0.75 | 51.72 | -0.0712 | 44.83 | 3.90 | 6.00 | 0.00 | 17.24 | 37.93 |
| train-m15_m10_m5-neck_close_confirm-tp6-h24 | M15 x M10 x M5 | neck_close_confirm | 6 | 24 | 23 | 0.66 | -31.64 | -1.38 | 0.49 | 52.17 | -0.0283 | 54.55 | 6.00 | 6.10 | 0.00 | 22.73 | 22.73 |
| train-m15_m10_m5-neck_close_confirm-tp6-h32 | M15 x M10 x M5 | neck_close_confirm | 6 | 32 | 22 | 0.32 | -101.21 | -4.60 | 1.06 | 50.00 | -0.1347 | 50.00 | 5.75 | 6.10 | 4.55 | 22.73 | 22.73 |
| train-m15_m10_m5-neck_close_confirm-tp8-h16 | M15 x M10 x M5 | neck_close_confirm | 8 | 16 | 27 | 0.51 | -63.51 | -2.35 | 0.74 | 48.15 | -0.0684 | 37.04 | 5.50 | 8.30 | 0.00 | 18.52 | 40.74 |
| train-m15_m10_m5-neck_close_confirm-tp8-h24 | M15 x M10 x M5 | neck_close_confirm | 8 | 24 | 22 | 0.81 | -17.37 | -0.79 | 0.43 | 50.00 | -0.0097 | 42.86 | 7.30 | 8.30 | 0.00 | 23.81 | 28.57 |
| train-m15_m10_m5-neck_close_confirm-tp8-h32 | M15 x M10 x M5 | neck_close_confirm | 8 | 32 | 21 | 0.41 | -87.87 | -4.18 | 1.01 | 47.62 | -0.1226 | 42.86 | 6.20 | 8.30 | 4.76 | 23.81 | 23.81 |
| train-m30_m15_m3-neck_close_confirm-tp2-h16 | M30 x M15 x M3 | neck_close_confirm | 2 | 16 | 28 | 0.38 | -43.32 | -1.55 | 0.43 | 64.29 | -0.0484 | 42.86 | 2.00 | 2.00 | 0.00 | 14.29 | 25.00 |
| train-m30_m15_m3-neck_close_confirm-tp2-h24 | M30 x M15 x M3 | neck_close_confirm | 2 | 24 | 28 | 0.38 | -43.82 | -1.56 | 0.44 | 64.29 | -0.0490 | 42.86 | 2.00 | 2.00 | 0.00 | 14.29 | 21.43 |
| train-m30_m15_m3-neck_close_confirm-tp2-h32 | M30 x M15 x M3 | neck_close_confirm | 2 | 32 | 27 | 0.36 | -48.32 | -1.79 | 0.48 | 66.67 | -0.0559 | 44.44 | 2.00 | 2.00 | 0.00 | 14.81 | 18.52 |
| train-m30_m15_m3-neck_close_confirm-tp3-h16 | M30 x M15 x M3 | neck_close_confirm | 3 | 16 | 28 | 0.37 | -54.84 | -1.96 | 0.56 | 60.71 | -0.0599 | 57.14 | 3.00 | 3.10 | 0.00 | 17.86 | 25.00 |
| train-m30_m15_m3-neck_close_confirm-tp3-h24 | M30 x M15 x M3 | neck_close_confirm | 3 | 24 | 28 | 0.38 | -54.79 | -1.96 | 0.55 | 60.71 | -0.0598 | 60.71 | 3.00 | 3.10 | 0.00 | 17.86 | 21.43 |
| train-m30_m15_m3-neck_close_confirm-tp3-h32 | M30 x M15 x M3 | neck_close_confirm | 3 | 32 | 27 | 0.36 | -59.29 | -2.20 | 0.59 | 62.96 | -0.0672 | 62.96 | 3.00 | 3.10 | 0.00 | 18.52 | 18.52 |
| train-m30_m15_m3-neck_close_confirm-tp4-h16 | M30 x M15 x M3 | neck_close_confirm | 4 | 16 | 28 | 0.46 | -48.79 | -1.74 | 0.51 | 57.14 | -0.0541 | 35.71 | 4.00 | 4.10 | 0.00 | 21.43 | 25.00 |
| train-m30_m15_m3-neck_close_confirm-tp4-h24 | M30 x M15 x M3 | neck_close_confirm | 4 | 24 | 28 | 0.45 | -52.97 | -1.89 | 0.55 | 57.14 | -0.0588 | 35.71 | 4.00 | 4.10 | 0.00 | 21.43 | 21.43 |
| train-m30_m15_m3-neck_close_confirm-tp4-h32 | M30 x M15 x M3 | neck_close_confirm | 4 | 32 | 27 | 0.44 | -56.06 | -2.08 | 0.57 | 59.26 | -0.0647 | 37.04 | 4.00 | 4.10 | 0.00 | 22.22 | 18.52 |
| train-m30_m15_m3-neck_close_confirm-tp5-h16 | M30 x M15 x M3 | neck_close_confirm | 5 | 16 | 28 | 0.38 | -63.15 | -2.26 | 0.63 | 50.00 | -0.0698 | 32.14 | 4.45 | 5.03 | 0.00 | 25.00 | 32.14 |
| train-m30_m15_m3-neck_close_confirm-tp5-h24 | M30 x M15 x M3 | neck_close_confirm | 5 | 24 | 27 | 0.43 | -53.13 | -1.97 | 0.53 | 51.85 | -0.0606 | 33.33 | 4.80 | 5.05 | 0.00 | 25.93 | 25.93 |
| train-m30_m15_m3-neck_close_confirm-tp5-h32 | M30 x M15 x M3 | neck_close_confirm | 5 | 32 | 26 | 0.47 | -51.39 | -1.98 | 0.54 | 53.85 | -0.0614 | 38.46 | 5.00 | 5.08 | 0.00 | 26.92 | 19.23 |
| train-m30_m15_m3-neck_close_confirm-tp6-h16 | M30 x M15 x M3 | neck_close_confirm | 6 | 16 | 26 | 0.39 | -59.74 | -2.30 | 0.60 | 46.15 | -0.0708 | 38.46 | 4.45 | 6.20 | 0.00 | 23.08 | 38.46 |
| train-m30_m15_m3-neck_close_confirm-tp6-h24 | M30 x M15 x M3 | neck_close_confirm | 6 | 24 | 25 | 0.45 | -50.21 | -2.01 | 0.50 | 48.00 | -0.0614 | 44.00 | 4.80 | 6.20 | 0.00 | 28.00 | 28.00 |
| train-m30_m15_m3-neck_close_confirm-tp6-h32 | M30 x M15 x M3 | neck_close_confirm | 6 | 32 | 24 | 0.50 | -46.71 | -1.95 | 0.51 | 50.00 | -0.0602 | 50.00 | 5.50 | 6.22 | 0.00 | 29.17 | 20.83 |
| train-m30_m15_m3-neck_close_confirm-tp8-h16 | M30 x M15 x M3 | neck_close_confirm | 8 | 16 | 24 | 0.53 | -35.19 | -1.47 | 0.35 | 45.83 | -0.0441 | 20.83 | 4.45 | 8.00 | 0.00 | 25.00 | 45.83 |
| train-m30_m15_m3-neck_close_confirm-tp8-h24 | M30 x M15 x M3 | neck_close_confirm | 8 | 24 | 23 | 0.56 | -31.30 | -1.36 | 0.31 | 39.13 | -0.0403 | 21.74 | 4.80 | 8.00 | 0.00 | 30.43 | 34.78 |
| train-m30_m15_m3-neck_close_confirm-tp8-h32 | M30 x M15 x M3 | neck_close_confirm | 8 | 32 | 22 | 0.40 | -58.63 | -2.67 | 0.59 | 40.91 | -0.0790 | 22.73 | 5.75 | 8.00 | 0.00 | 31.82 | 31.82 |

## OOS

| slug | pair | trigger | tp | hold | trades | pf | net | exp payoff | max dd % | win rate % | avg R | cfg tp hit % | mfe p50 | mfe p75 | stop<tp % | accept<tp % | time<tp % |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| oos-m15_m10_m5-neck_close_confirm-tp2-h16 | M15 x M10 x M5 | neck_close_confirm | 2 | 16 | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | -1.0472 | 0.00 | 1.80 | 1.80 | 100.00 | 0.00 | 0.00 |
| oos-m15_m10_m5-neck_close_confirm-tp2-h24 | M15 x M10 x M5 | neck_close_confirm | 2 | 24 | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | -1.0472 | 0.00 | 1.80 | 1.80 | 100.00 | 0.00 | 0.00 |
| oos-m15_m10_m5-neck_close_confirm-tp2-h32 | M15 x M10 x M5 | neck_close_confirm | 2 | 32 | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | -1.0472 | 0.00 | 1.80 | 1.80 | 100.00 | 0.00 | 0.00 |
| oos-m15_m10_m5-neck_close_confirm-tp3-h16 | M15 x M10 x M5 | neck_close_confirm | 3 | 16 | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | -1.0472 | 0.00 | 1.80 | 1.80 | 100.00 | 0.00 | 0.00 |
| oos-m15_m10_m5-neck_close_confirm-tp3-h24 | M15 x M10 x M5 | neck_close_confirm | 3 | 24 | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | -1.0472 | 0.00 | 1.80 | 1.80 | 100.00 | 0.00 | 0.00 |
| oos-m15_m10_m5-neck_close_confirm-tp3-h32 | M15 x M10 x M5 | neck_close_confirm | 3 | 32 | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | -1.0472 | 0.00 | 1.80 | 1.80 | 100.00 | 0.00 | 0.00 |
| oos-m15_m10_m5-neck_close_confirm-tp4-h16 | M15 x M10 x M5 | neck_close_confirm | 4 | 16 | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | -1.0472 | 0.00 | 1.80 | 1.80 | 100.00 | 0.00 | 0.00 |
| oos-m15_m10_m5-neck_close_confirm-tp4-h24 | M15 x M10 x M5 | neck_close_confirm | 4 | 24 | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | -1.0472 | 0.00 | 1.80 | 1.80 | 100.00 | 0.00 | 0.00 |
| oos-m15_m10_m5-neck_close_confirm-tp4-h32 | M15 x M10 x M5 | neck_close_confirm | 4 | 32 | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | -1.0472 | 0.00 | 1.80 | 1.80 | 100.00 | 0.00 | 0.00 |
| oos-m15_m10_m5-neck_close_confirm-tp5-h16 | M15 x M10 x M5 | neck_close_confirm | 5 | 16 | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | -1.0472 | 0.00 | 1.80 | 1.80 | 100.00 | 0.00 | 0.00 |
| oos-m15_m10_m5-neck_close_confirm-tp5-h24 | M15 x M10 x M5 | neck_close_confirm | 5 | 24 | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | -1.0472 | 0.00 | 1.80 | 1.80 | 100.00 | 0.00 | 0.00 |
| oos-m15_m10_m5-neck_close_confirm-tp5-h32 | M15 x M10 x M5 | neck_close_confirm | 5 | 32 | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | -1.0472 | 0.00 | 1.80 | 1.80 | 100.00 | 0.00 | 0.00 |
| oos-m15_m10_m5-neck_close_confirm-tp6-h16 | M15 x M10 x M5 | neck_close_confirm | 6 | 16 | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | -1.0472 | 0.00 | 1.80 | 1.80 | 100.00 | 0.00 | 0.00 |
| oos-m15_m10_m5-neck_close_confirm-tp6-h24 | M15 x M10 x M5 | neck_close_confirm | 6 | 24 | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | -1.0472 | 0.00 | 1.80 | 1.80 | 100.00 | 0.00 | 0.00 |
| oos-m15_m10_m5-neck_close_confirm-tp6-h32 | M15 x M10 x M5 | neck_close_confirm | 6 | 32 | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | -1.0472 | 0.00 | 1.80 | 1.80 | 100.00 | 0.00 | 0.00 |
| oos-m15_m10_m5-neck_close_confirm-tp8-h16 | M15 x M10 x M5 | neck_close_confirm | 8 | 16 | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | -1.0472 | 0.00 | 1.80 | 1.80 | 100.00 | 0.00 | 0.00 |
| oos-m15_m10_m5-neck_close_confirm-tp8-h24 | M15 x M10 x M5 | neck_close_confirm | 8 | 24 | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | -1.0472 | 0.00 | 1.80 | 1.80 | 100.00 | 0.00 | 0.00 |
| oos-m15_m10_m5-neck_close_confirm-tp8-h32 | M15 x M10 x M5 | neck_close_confirm | 8 | 32 | 1 | 0.00 | -36.51 | -36.51 | 0.37 | 0.00 | -1.0472 | 0.00 | 1.80 | 1.80 | 100.00 | 0.00 | 0.00 |
| oos-m30_m15_m3-neck_close_confirm-tp2-h16 | M30 x M15 x M3 | neck_close_confirm | 2 | 16 | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m30_m15_m3-neck_close_confirm-tp2-h24 | M30 x M15 x M3 | neck_close_confirm | 2 | 24 | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m30_m15_m3-neck_close_confirm-tp2-h32 | M30 x M15 x M3 | neck_close_confirm | 2 | 32 | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m30_m15_m3-neck_close_confirm-tp3-h16 | M30 x M15 x M3 | neck_close_confirm | 3 | 16 | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m30_m15_m3-neck_close_confirm-tp3-h24 | M30 x M15 x M3 | neck_close_confirm | 3 | 24 | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m30_m15_m3-neck_close_confirm-tp3-h32 | M30 x M15 x M3 | neck_close_confirm | 3 | 32 | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m30_m15_m3-neck_close_confirm-tp4-h16 | M30 x M15 x M3 | neck_close_confirm | 4 | 16 | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m30_m15_m3-neck_close_confirm-tp4-h24 | M30 x M15 x M3 | neck_close_confirm | 4 | 24 | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m30_m15_m3-neck_close_confirm-tp4-h32 | M30 x M15 x M3 | neck_close_confirm | 4 | 32 | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m30_m15_m3-neck_close_confirm-tp5-h16 | M30 x M15 x M3 | neck_close_confirm | 5 | 16 | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m30_m15_m3-neck_close_confirm-tp5-h24 | M30 x M15 x M3 | neck_close_confirm | 5 | 24 | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m30_m15_m3-neck_close_confirm-tp5-h32 | M30 x M15 x M3 | neck_close_confirm | 5 | 32 | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m30_m15_m3-neck_close_confirm-tp6-h16 | M30 x M15 x M3 | neck_close_confirm | 6 | 16 | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m30_m15_m3-neck_close_confirm-tp6-h24 | M30 x M15 x M3 | neck_close_confirm | 6 | 24 | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m30_m15_m3-neck_close_confirm-tp6-h32 | M30 x M15 x M3 | neck_close_confirm | 6 | 32 | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m30_m15_m3-neck_close_confirm-tp8-h16 | M30 x M15 x M3 | neck_close_confirm | 8 | 16 | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m30_m15_m3-neck_close_confirm-tp8-h24 | M30 x M15 x M3 | neck_close_confirm | 8 | 24 | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| oos-m30_m15_m3-neck_close_confirm-tp8-h32 | M30 x M15 x M3 | neck_close_confirm | 8 | 32 | 0 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.0000 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |

## ACTUAL

| slug | pair | trigger | tp | hold | trades | pf | net | exp payoff | max dd % | win rate % | avg R | cfg tp hit % | mfe p50 | mfe p75 | stop<tp % | accept<tp % | time<tp % |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| actual-m15_m10_m5-neck_close_confirm-tp2-h16 | M15 x M10 x M5 | neck_close_confirm | 2 | 16 | 43 | 0.32 | -100.24 | -2.33 | 1.04 | 67.44 | -0.0696 | 62.79 | 2.00 | 2.20 | 2.33 | 11.63 | 18.60 |
| actual-m15_m10_m5-neck_close_confirm-tp2-h24 | M15 x M10 x M5 | neck_close_confirm | 2 | 24 | 38 | 0.30 | -95.78 | -2.52 | 1.06 | 65.79 | -0.0695 | 62.16 | 2.00 | 2.20 | 2.70 | 13.51 | 16.22 |
| actual-m15_m10_m5-neck_close_confirm-tp2-h32 | M15 x M10 x M5 | neck_close_confirm | 2 | 32 | 37 | 0.36 | -79.66 | -2.15 | 0.91 | 72.97 | -0.0649 | 67.57 | 2.10 | 2.20 | 2.70 | 13.51 | 10.81 |
| actual-m15_m10_m5-neck_close_confirm-tp3-h16 | M15 x M10 x M5 | neck_close_confirm | 3 | 16 | 40 | 0.28 | -126.89 | -3.17 | 1.31 | 60.00 | -0.0937 | 60.00 | 3.00 | 3.10 | 2.50 | 12.50 | 25.00 |
| actual-m15_m10_m5-neck_close_confirm-tp3-h24 | M15 x M10 x M5 | neck_close_confirm | 3 | 24 | 36 | 0.24 | -140.20 | -3.89 | 1.46 | 58.33 | -0.1102 | 60.00 | 3.00 | 3.10 | 5.71 | 14.29 | 20.00 |
| actual-m15_m10_m5-neck_close_confirm-tp3-h32 | M15 x M10 x M5 | neck_close_confirm | 3 | 32 | 34 | 0.38 | -86.60 | -2.55 | 0.94 | 67.65 | -0.0758 | 67.65 | 3.00 | 3.10 | 2.94 | 14.71 | 14.71 |
| actual-m15_m10_m5-neck_close_confirm-tp4-h16 | M15 x M10 x M5 | neck_close_confirm | 4 | 16 | 38 | 0.33 | -123.05 | -3.24 | 1.28 | 52.63 | -0.0959 | 42.11 | 3.95 | 4.20 | 2.63 | 13.16 | 34.21 |
| actual-m15_m10_m5-neck_close_confirm-tp4-h24 | M15 x M10 x M5 | neck_close_confirm | 4 | 24 | 33 | 0.29 | -132.02 | -4.00 | 1.40 | 51.52 | -0.1131 | 43.75 | 4.00 | 4.30 | 6.25 | 15.62 | 25.00 |
| actual-m15_m10_m5-neck_close_confirm-tp4-h32 | M15 x M10 x M5 | neck_close_confirm | 4 | 32 | 30 | 0.33 | -107.21 | -3.57 | 1.13 | 53.33 | -0.1064 | 46.67 | 4.00 | 4.30 | 3.33 | 16.67 | 26.67 |
| actual-m15_m10_m5-neck_close_confirm-tp5-h16 | M15 x M10 x M5 | neck_close_confirm | 5 | 16 | 38 | 0.39 | -110.53 | -2.91 | 1.17 | 52.63 | -0.0859 | 36.84 | 4.45 | 5.10 | 2.63 | 13.16 | 34.21 |
| actual-m15_m10_m5-neck_close_confirm-tp5-h24 | M15 x M10 x M5 | neck_close_confirm | 5 | 24 | 33 | 0.35 | -121.03 | -3.67 | 1.31 | 51.52 | -0.1031 | 40.62 | 5.00 | 5.12 | 6.25 | 15.62 | 25.00 |
| actual-m15_m10_m5-neck_close_confirm-tp5-h32 | M15 x M10 x M5 | neck_close_confirm | 5 | 32 | 29 | 0.35 | -106.79 | -3.68 | 1.14 | 51.72 | -0.1092 | 41.38 | 5.00 | 5.10 | 3.45 | 17.24 | 27.59 |
| actual-m15_m10_m5-neck_close_confirm-tp6-h16 | M15 x M10 x M5 | neck_close_confirm | 6 | 16 | 38 | 0.41 | -107.24 | -2.82 | 1.16 | 52.63 | -0.0830 | 47.37 | 4.70 | 6.08 | 2.63 | 13.16 | 36.84 |
| actual-m15_m10_m5-neck_close_confirm-tp6-h24 | M15 x M10 x M5 | neck_close_confirm | 6 | 24 | 32 | 0.57 | -61.13 | -1.91 | 0.74 | 53.12 | -0.0494 | 54.84 | 6.00 | 6.10 | 3.23 | 16.13 | 25.81 |
| actual-m15_m10_m5-neck_close_confirm-tp6-h32 | M15 x M10 x M5 | neck_close_confirm | 6 | 32 | 29 | 0.29 | -144.64 | -4.99 | 1.53 | 48.28 | -0.1473 | 48.28 | 5.50 | 6.10 | 6.90 | 17.24 | 27.59 |
| actual-m15_m10_m5-neck_close_confirm-tp8-h16 | M15 x M10 x M5 | neck_close_confirm | 8 | 16 | 36 | 0.50 | -92.78 | -2.58 | 1.07 | 50.00 | -0.0761 | 41.67 | 5.75 | 8.30 | 2.78 | 13.89 | 38.89 |
| actual-m15_m10_m5-neck_close_confirm-tp8-h24 | M15 x M10 x M5 | neck_close_confirm | 8 | 24 | 31 | 0.72 | -40.25 | -1.30 | 0.64 | 51.61 | -0.0304 | 46.67 | 7.65 | 8.30 | 3.33 | 16.67 | 30.00 |
| actual-m15_m10_m5-neck_close_confirm-tp8-h32 | M15 x M10 x M5 | neck_close_confirm | 8 | 32 | 28 | 0.38 | -127.38 | -4.55 | 1.38 | 46.43 | -0.1345 | 42.86 | 5.85 | 8.30 | 7.14 | 17.86 | 28.57 |
| actual-m30_m15_m3-neck_close_confirm-tp2-h16 | M30 x M15 x M3 | neck_close_confirm | 2 | 16 | 40 | 0.35 | -73.01 | -1.83 | 0.73 | 62.50 | -0.0560 | 45.00 | 2.00 | 2.02 | 0.00 | 20.00 | 20.00 |
| actual-m30_m15_m3-neck_close_confirm-tp2-h24 | M30 x M15 x M3 | neck_close_confirm | 2 | 24 | 40 | 0.36 | -73.29 | -1.83 | 0.73 | 62.50 | -0.0562 | 45.00 | 2.00 | 2.02 | 0.00 | 20.00 | 17.50 |
| actual-m30_m15_m3-neck_close_confirm-tp2-h32 | M30 x M15 x M3 | neck_close_confirm | 2 | 32 | 39 | 0.34 | -79.20 | -2.03 | 0.79 | 64.10 | -0.0623 | 46.15 | 2.00 | 2.05 | 0.00 | 20.51 | 15.38 |
| actual-m30_m15_m3-neck_close_confirm-tp3-h16 | M30 x M15 x M3 | neck_close_confirm | 3 | 16 | 40 | 0.40 | -78.22 | -1.96 | 0.79 | 60.00 | -0.0594 | 57.50 | 3.00 | 3.10 | 0.00 | 22.50 | 20.00 |
| actual-m30_m15_m3-neck_close_confirm-tp3-h24 | M30 x M15 x M3 | neck_close_confirm | 3 | 24 | 40 | 0.41 | -77.95 | -1.95 | 0.79 | 60.00 | -0.0592 | 60.00 | 3.00 | 3.10 | 0.00 | 22.50 | 17.50 |
| actual-m30_m15_m3-neck_close_confirm-tp3-h32 | M30 x M15 x M3 | neck_close_confirm | 3 | 32 | 39 | 0.39 | -83.86 | -2.15 | 0.84 | 61.54 | -0.0653 | 61.54 | 3.00 | 3.10 | 0.00 | 23.08 | 15.38 |
| actual-m30_m15_m3-neck_close_confirm-tp4-h16 | M30 x M15 x M3 | neck_close_confirm | 4 | 16 | 40 | 0.42 | -84.36 | -2.11 | 0.87 | 52.50 | -0.0643 | 32.50 | 3.70 | 4.10 | 0.00 | 27.50 | 22.50 |
| actual-m30_m15_m3-neck_close_confirm-tp4-h24 | M30 x M15 x M3 | neck_close_confirm | 4 | 24 | 40 | 0.41 | -91.31 | -2.28 | 0.93 | 52.50 | -0.0698 | 32.50 | 4.00 | 4.10 | 0.00 | 27.50 | 20.00 |
| actual-m30_m15_m3-neck_close_confirm-tp4-h32 | M30 x M15 x M3 | neck_close_confirm | 4 | 32 | 39 | 0.40 | -95.61 | -2.45 | 0.97 | 53.85 | -0.0751 | 33.33 | 4.00 | 4.10 | 0.00 | 28.21 | 17.95 |
| actual-m30_m15_m3-neck_close_confirm-tp5-h16 | M30 x M15 x M3 | neck_close_confirm | 5 | 16 | 40 | 0.35 | -103.20 | -2.58 | 1.03 | 45.00 | -0.0784 | 30.00 | 3.85 | 5.00 | 0.00 | 30.00 | 30.00 |
| actual-m30_m15_m3-neck_close_confirm-tp5-h24 | M30 x M15 x M3 | neck_close_confirm | 5 | 24 | 38 | 0.38 | -98.05 | -2.58 | 0.98 | 47.37 | -0.0781 | 31.58 | 4.45 | 5.00 | 0.00 | 31.58 | 23.68 |
| actual-m30_m15_m3-neck_close_confirm-tp5-h32 | M30 x M15 x M3 | neck_close_confirm | 5 | 32 | 37 | 0.39 | -97.52 | -2.64 | 1.00 | 48.65 | -0.0801 | 35.14 | 4.80 | 5.00 | 0.00 | 32.43 | 18.92 |
| actual-m30_m15_m3-neck_close_confirm-tp6-h16 | M30 x M15 x M3 | neck_close_confirm | 6 | 16 | 38 | 0.39 | -95.76 | -2.52 | 0.96 | 42.11 | -0.0764 | 36.84 | 3.85 | 6.17 | 0.00 | 28.95 | 34.21 |
| actual-m30_m15_m3-neck_close_confirm-tp6-h24 | M30 x M15 x M3 | neck_close_confirm | 6 | 24 | 36 | 0.41 | -91.10 | -2.53 | 0.91 | 44.44 | -0.0764 | 41.67 | 4.45 | 6.20 | 0.00 | 33.33 | 25.00 |
| actual-m30_m15_m3-neck_close_confirm-tp6-h32 | M30 x M15 x M3 | neck_close_confirm | 6 | 32 | 35 | 0.44 | -88.81 | -2.54 | 0.93 | 45.71 | -0.0770 | 45.71 | 4.80 | 6.20 | 0.00 | 34.29 | 20.00 |
| actual-m30_m15_m3-neck_close_confirm-tp8-h16 | M30 x M15 x M3 | neck_close_confirm | 8 | 16 | 36 | 0.52 | -63.45 | -1.76 | 0.63 | 41.67 | -0.0526 | 25.00 | 3.85 | 8.00 | 0.00 | 30.56 | 38.89 |
| actual-m30_m15_m3-neck_close_confirm-tp8-h24 | M30 x M15 x M3 | neck_close_confirm | 8 | 24 | 34 | 0.52 | -64.43 | -1.90 | 0.64 | 38.24 | -0.0563 | 26.47 | 4.45 | 8.00 | 0.00 | 35.29 | 29.41 |
| actual-m30_m15_m3-neck_close_confirm-tp8-h32 | M30 x M15 x M3 | neck_close_confirm | 8 | 32 | 33 | 0.42 | -92.97 | -2.82 | 0.93 | 39.39 | -0.0836 | 27.27 | 4.80 | 8.00 | 0.00 | 36.36 | 27.27 |

