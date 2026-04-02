# USDJPY Zone Escape Cycle 1 Kill

- Date: `2026-04-02`
- Family: `usdjpy_20260402_zone_escape`
- Objective: `high_turnover_compounding`
- Verdict: `kill`

## What Was Tested

- baseline `asia sell core`
- `spread 2.2` probe after separating signal qualification from execution gating
- `spread 3.0` probe to verify whether the family survives broker friction when the blocked OOS signals are actually allowed through

## Actual MT5 Results

- baseline train `9m`: `PF 0.91`, `net -13.30`, `7 trades`
- baseline OOS `3m`: `PF 0.00`, `net 0.00`, `0 trades`
- spread `2.2` train `9m`: `PF 0.91`, `net -13.30`, `7 trades`
- spread `2.2` OOS `3m`: `PF 0.00`, `net 0.00`, `0 trades`
- spread `3.0` train `9m`: `PF 0.72`, `net -48.50`, `8 trades`
- spread `3.0` OOS `3m`: `PF 0.57`, `net -30.96`, `3 trades`

## What Was Learned

- The family is no longer blocked by a breakout-detection bug.
- `spread 2.2` proved that real signals exist in OOS: tester debug moved from `qualified=0` to `qualified=5`.
- Those signals still could not clear the broker spread gate until the cap was widened to `3.0`.
- Once widened to `3.0`, the family traded in OOS but the edge collapsed.
- This means the problem is not "the EA misses signals"; the problem is "the edge does not survive executable friction on this broker feed."

## Reusable Lesson

- For USDJPY M5 continuation ideas, do not trust sparse Asia-session breakout/retest patterns until they are tested at executable spread, not only at study-level assumed spread.
- If widening spread turns `0 trades` into live trades but flips the family negative, treat that as a structural family failure, not as a tuning invitation.

## Next Step

- Open the next USDJPY mainline from a fresh `London/NY EMA13-EMA100 continuation + volatility-state + V-shape pullback` study.
- Do not spend another immediate cycle on `usdjpy_20260402_zone_escape` spread loosening, expiry retuning, or touch-buffer tuning.
