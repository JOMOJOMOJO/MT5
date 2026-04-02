# USDJPY Golden S1 Long-Only Event Study

- Symbol: `USDJPY`
- Timeframe: `M5`
- History window: `2024-11-27T00:10:00` -> `2026-04-02T06:00:00`
- Train / OOS split: `2024-11-27T00:10:00` -> `2026-01-01T05:55:00` / `2026-01-01T06:00:00` -> `2026-04-02T06:00:00`
- Event count: `1606`
- Candidate count: `8373`
- Target trades/day: `1.00`

## Top Candidates

- `ny` / bodies<=1 / transition>=0.0 / pullback_ratio<=0.55 / close_loc>=0.60 / impulse>=14.0 / stoch<=100.0: train `21 trades, 0.06/day, exp -0.119R`, test `8 trades, 0.11/day, exp 0.179R`
- `ny` / bodies<=1 / transition>=1.0 / pullback_ratio<=0.55 / close_loc>=0.60 / impulse>=14.0 / stoch<=100.0: train `21 trades, 0.06/day, exp -0.119R`, test `8 trades, 0.11/day, exp 0.179R`
- `ny` / bodies<=1 / transition>=2.0 / pullback_ratio<=0.55 / close_loc>=0.60 / impulse>=14.0 / stoch<=100.0: train `19 trades, 0.05/day, exp -0.124R`, test `8 trades, 0.11/day, exp 0.179R`
- `ny` / bodies<=1 / transition>=3.0 / pullback_ratio<=0.55 / close_loc>=0.60 / impulse>=14.0 / stoch<=100.0: train `17 trades, 0.05/day, exp -0.133R`, test `8 trades, 0.11/day, exp 0.179R`
- `london_open` / bodies<=3 / transition>=3.0 / pullback_ratio<=0.45 / close_loc>=0.60 / impulse>=14.0 / stoch<=100.0: train `28 trades, 0.08/day, exp -0.292R`, test `11 trades, 0.20/day, exp 0.200R`
- `london_open` / bodies<=4 / transition>=3.0 / pullback_ratio<=0.45 / close_loc>=0.60 / impulse>=14.0 / stoch<=100.0: train `28 trades, 0.08/day, exp -0.292R`, test `11 trades, 0.20/day, exp 0.200R`
- `london_open` / bodies<=3 / transition>=0.0 / pullback_ratio<=0.45 / close_loc>=0.60 / impulse>=14.0 / stoch<=100.0: train `33 trades, 0.10/day, exp -0.358R`, test `11 trades, 0.20/day, exp 0.200R`
- `london_open` / bodies<=4 / transition>=0.0 / pullback_ratio<=0.45 / close_loc>=0.60 / impulse>=14.0 / stoch<=100.0: train `33 trades, 0.10/day, exp -0.358R`, test `11 trades, 0.20/day, exp 0.200R`
- `london_open` / bodies<=3 / transition>=2.0 / pullback_ratio<=0.45 / close_loc>=0.60 / impulse>=14.0 / stoch<=100.0: train `30 trades, 0.09/day, exp -0.350R`, test `11 trades, 0.20/day, exp 0.200R`
- `london_open` / bodies<=4 / transition>=2.0 / pullback_ratio<=0.45 / close_loc>=0.60 / impulse>=14.0 / stoch<=100.0: train `30 trades, 0.09/day, exp -0.350R`, test `11 trades, 0.20/day, exp 0.200R`
