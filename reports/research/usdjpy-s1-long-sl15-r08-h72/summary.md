# USDJPY Golden S1 Long-Only Event Study

- Symbol: `USDJPY`
- Timeframe: `M5`
- History window: `2024-11-27T00:25:00` -> `2026-04-02T06:15:00`
- Train / OOS split: `2024-11-27T00:25:00` -> `2026-01-01T06:10:00` / `2026-01-01T06:15:00` -> `2026-04-02T06:15:00`
- Event count: `1606`
- Candidate count: `8373`
- Target trades/day: `1.00`

## Top Candidates

- `ny_open` / bodies<=1 / transition>=3.0 / pullback_ratio<=0.45 / close_loc>=0.60 / impulse>=8.0 / stoch<=100.0: train `11 trades, 0.03/day, exp 0.194R`, test `4 trades, 0.07/day, exp 0.217R`
- `ny_open` / bodies<=1 / transition>=3.0 / pullback_ratio<=0.45 / close_loc>=0.60 / impulse>=10.0 / stoch<=100.0: train `11 trades, 0.03/day, exp 0.194R`, test `4 trades, 0.07/day, exp 0.217R`
- `ny_open` / bodies<=1 / transition>=3.0 / pullback_ratio<=0.45 / close_loc>=0.65 / impulse>=8.0 / stoch<=100.0: train `10 trades, 0.03/day, exp 0.145R`, test `4 trades, 0.07/day, exp 0.217R`
- `ny_open` / bodies<=1 / transition>=3.0 / pullback_ratio<=0.45 / close_loc>=0.65 / impulse>=10.0 / stoch<=100.0: train `10 trades, 0.03/day, exp 0.145R`, test `4 trades, 0.07/day, exp 0.217R`
- `ny_open` / bodies<=1 / transition>=3.0 / pullback_ratio<=0.45 / close_loc>=0.60 / impulse>=12.0 / stoch<=100.0: train `10 trades, 0.03/day, exp 0.143R`, test `4 trades, 0.07/day, exp 0.217R`
- `ny_open` / bodies<=1 / transition>=0.0 / pullback_ratio<=0.45 / close_loc>=0.60 / impulse>=8.0 / stoch<=100.0: train `12 trades, 0.03/day, exp 0.086R`, test `4 trades, 0.07/day, exp 0.217R`
- `ny_open` / bodies<=1 / transition>=0.0 / pullback_ratio<=0.45 / close_loc>=0.60 / impulse>=10.0 / stoch<=100.0: train `12 trades, 0.03/day, exp 0.086R`, test `4 trades, 0.07/day, exp 0.217R`
- `ny_open` / bodies<=1 / transition>=1.0 / pullback_ratio<=0.45 / close_loc>=0.60 / impulse>=8.0 / stoch<=100.0: train `12 trades, 0.03/day, exp 0.086R`, test `4 trades, 0.07/day, exp 0.217R`
- `ny_open` / bodies<=1 / transition>=1.0 / pullback_ratio<=0.45 / close_loc>=0.60 / impulse>=10.0 / stoch<=100.0: train `12 trades, 0.03/day, exp 0.086R`, test `4 trades, 0.07/day, exp 0.217R`
- `ny_open` / bodies<=1 / transition>=2.0 / pullback_ratio<=0.45 / close_loc>=0.60 / impulse>=8.0 / stoch<=100.0: train `12 trades, 0.03/day, exp 0.086R`, test `4 trades, 0.07/day, exp 0.217R`
