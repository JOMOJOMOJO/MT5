# Step 04 behavior-preservation comparison

## Result

- Comparison rows: `11403`
- Preservation-oracle compared values: `272155`
- Unintended difference rows: `0`
- Mandated-baseline version-drift rows: `54`
- Verdict: `PASS`

The manifest baseline is retained as the mandatory historical reference. Because its source predates the current causal-execution revision, its differences are reported as `REFERENCE_VERSION_DRIFT`. Behavior preservation is judged only against the manifest-registered run whose source hash matches the immediate pre-refactor EA.

## Inputs

- preservation events: `reports/backtest/runs/20260822_tickshock_realizable_execution/events.csv` (`SHA-256 EAC7BBEBFF71CAFC70576A4E4D06D9BD6EFAF5BF34E8A4826284EB754986E2A1`)
- preservation summary: `reports/backtest/runs/20260822_tickshock_realizable_execution/summary.csv` (`SHA-256 3AADFE299C94B98D201BFC566248FC60701D9FF9927A931F45BE4F2893DAB23D`)
- manifest baseline events: `reports/backtest/runs/20260822_tickshock_execution_revision/events.csv` (`SHA-256 45F01B4F54CE45ACC94A08B48391A6CCB382110096FBAC9FE4B54741D10D9D14`)
- manifest baseline summary: `reports/backtest/runs/20260822_tickshock_execution_revision/summary.csv` (`SHA-256 3CED2C22045F5911445E895BD2A55386BD8CB5DA28D6606AC7C283C5FEEFA17A`)
- manifest baseline narrative: `reports/backtest/runs/20260822_tickshock_execution_revision/summary.md` (`SHA-256 D5C3CA7D19B9C1158C5B8A1C57AC1AACB1F023D7EA68AC81731331AE04FE2967`)
- candidate events: `reports/refactor/tick_shock/step04_candidate_events.csv` (`SHA-256 24C499B1DC3BB150C64890B20FD12C046A2EC89AFA3D8CE42EFDF93DEAB2FF8D`)
- candidate summary: `reports/refactor/tick_shock/step04_candidate_summary.csv` (`SHA-256 FF479B5629C1DF8DFE926A5363C2862E9980EDA9A6279D184E79B989D960D7CB`)
- candidate source: `mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5` (`SHA-256 4A5BF40C024924C42375FB5EB1338B3A0EB1590FBCFA0E6CB3FCCC6FA0A26D8E`)

## Compile evidence

- `reports/compile/tick_shock/step04_research_ea.log`: `Result: 0 errors, 0 warnings, 2602 ms elapsed, cpu='X64 Regular'`
- `reports/compile/tick_shock/step04_ExpectedValue_TickShock_ResearchReachabilityHarness.log`: `Result: 0 errors, 0 warnings, 584 ms elapsed, cpu='X64 Regular'`
- `reports/compile/tick_shock/step04_ExpectedValue_TickShock_OrderReachabilityHarness.log`: `Result: 0 errors, 0 warnings, 656 ms elapsed, cpu='X64 Regular'`

The research EA compile trace includes all ten `mql/Include/TickShock/` modules. The two existing harnesses compile through the compatibility include paths.

## Preserved behavior and known-defect boundary

The extraction routes detector gates, state transitions, and scenario entry through the same production facade available to Step 5. MT5 symbol/tick/time/memory/trend/file operations are behind the adapter, while enum-to-string conversion occurs at the CSV boundary.

No detector/state/stop-grid/RR value, scenario index, merge/watermark rule, entry/exit semantics, or CSV schema was intentionally changed. Same-RunId append behavior and the other defects recorded by Step 2 remain outside this behavior-preserving step.

## Exclusions

`RunId`, runtime, memory, source hash, byte counts, and output paths are excluded. All event identity, detector, state, signal, scenario execution, policy, cluster, and funnel comparisons remain in the CSV.
