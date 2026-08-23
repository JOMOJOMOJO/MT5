# Step 10 behavior-preservation comparison

## Result

- Comparison rows: `11403`
- Preservation-oracle compared values: `272155`
- Unintended difference rows: `0`
- Mandated-baseline version-drift rows: `54`
- Verdict: `PASS`

The manifest baseline is retained as the mandatory historical reference. Because its source predates the current causal-execution revision, its differences are reported as `REFERENCE_VERSION_DRIFT`. Behavior preservation is judged only against the manifest-registered run whose source hash matches the immediate pre-refactor EA.

## Inputs

- preservation events: `reports/backtest/runs/20260822_tickshock_causal_realizable_202503/events.csv` (`SHA-256 722DF1673BFA91B5B80D21E0BC5E43AD3C7C2FFC3267AB8A5EB5C570D1B41F4A`)
- preservation summary: `reports/backtest/runs/20260822_tickshock_causal_realizable_202503/summary.csv` (`SHA-256 97E1EF29D736FA832887521D3188FE85E85C8135D00A35BFD6AF29FA7571BDB6`)
- manifest baseline events: `reports/backtest/runs/20260822_tickshock_execution_revision/events.csv` (`SHA-256 45F01B4F54CE45ACC94A08B48391A6CCB382110096FBAC9FE4B54741D10D9D14`)
- manifest baseline summary: `reports/backtest/runs/20260822_tickshock_execution_revision/summary.csv` (`SHA-256 3CED2C22045F5911445E895BD2A55386BD8CB5DA28D6606AC7C283C5FEEFA17A`)
- manifest baseline narrative: `reports/backtest/runs/20260822_tickshock_execution_revision/summary.md` (`SHA-256 D5C3CA7D19B9C1158C5B8A1C57AC1AACB1F023D7EA68AC81731331AE04FE2967`)
- candidate events: `reports/backtest/runs/20260823_tickshock_step10_refactor_realizable_202503/events.csv` (`SHA-256 5D6C5573FC186E0C335D3F5133F4F5F1B15C00BD73FD82315F09432B43E40EF4`)
- candidate summary: `reports/backtest/runs/20260823_tickshock_step10_refactor_realizable_202503/summary.csv` (`SHA-256 077F7BF924D76CD41B2596AEE65B0B1C3CCED4D803B73C5C17CE8C197315537E`)
- candidate source: `mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5` (`SHA-256 D33CF37A0534F812112F29EC01F1463A6AFB816740BECC8DE23E561D7E17A539`)

## Compile evidence

- `reports/compile/tick_shock/step10_research_ea_compile.log`: `Result: 0 errors, 0 warnings, 3342 ms elapsed, cpu='X64 Regular'`

The research EA compile trace includes the complete `mql/Include/TickShock/` module graph. All ten harnesses compile through the same production modules or retained compatibility include paths.

## Preserved behavior and known-defect boundary

The extraction routes detector gates, state transitions, and scenario entry through the same production facade available to Step 5. MT5 symbol/tick/time/memory/trend/file operations are behind the adapter, while enum-to-string conversion occurs at the CSV boundary.

No detector/state/stop-grid/RR value, scenario index, merge/watermark rule, entry/exit semantics, or CSV schema was intentionally changed. Same-RunId append behavior and the other defects recorded by Step 2 remain outside this behavior-preserving step.

## Exclusions

`RunId`, runtime, memory, source hash, byte counts, and output paths are excluded. All event identity, detector, state, signal, scenario execution, policy, cluster, and funnel comparisons remain in the CSV.
