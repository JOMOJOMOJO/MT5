# Live Path Robustness Analysis

## IS Plateau
Average 2025 live-path performance by `NecklineBreakBufferATR`:
|NecklineBreakBufferATR|Avg ExpectancyR|Avg PF|
|---:|---:|---:|
|0.03|0.064400|1.123636|
|0.05|0.112166|1.205765|
|0.07|0.155850|1.292770|

Average 2025 live-path performance by ADX bucket thresholds:
|ADXLow/ADXHigh|Avg ExpectancyR|Avg PF|Avg Trades|
|---|---:|---:|---:|
|18/28|0.117659|1.222171|100.2|
|18/30|0.115067|1.208789|111.0|
|20/30|0.183003|1.340935|109.4|
|20/32|0.092275|1.173545|114.3|
|22/32|0.046023|1.091511|88.4|

## What Is Robust
- `NecklineBreakBufferATR=0.07` is consistently the strongest region on live path.
- `Tolerance=0.20-0.25` is safer than `0.30`; many weak and negative sets use `0.30`.
- The strongest IS plateau is around `ADX 20/30`, but that rank-1 candidate failed OOS.

## What Is Fragile
- `g039` passed both IS and OOS, but its broader ADX `22/32` group is not the strongest average group.
- `g039` also had a negative 2025 Q4 (`-0.758R`) and negative 2026 April (`-2.066R`).
- This means it is not robust enough for production. It is only robust enough to justify controlled demo observation.

## Execution-Friction Sensitivity
The live-path rerun confirmed that the earlier virtual edge was overstated. Several parameter sets that looked excellent on virtual deteriorated materially on tester order execution.

The ranking changed enough that all future promotion gates should use `EnableTrading=true` tester evidence, not virtual evidence.

## Conclusion
There is one live-path survivor in the preselected top-5 group: `g039`. It can move to demo-forward validation, but production readiness is not established.
