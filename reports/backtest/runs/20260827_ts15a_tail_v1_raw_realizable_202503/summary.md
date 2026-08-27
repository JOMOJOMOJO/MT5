# Aborted Step 15A TAIL_V1_RAW diagnostic run

- status: `VALIDATION_INVALID_ABORTED`
- source commit: `dd3048bb`
- first exhaustion: simulated `2025-03-03 22:05:37`, symbol `USDJPY`
- `active event pool exhausted` journal messages: 2,742
- formal event/outcome result: unavailable
- use for detector selection: prohibited

The initial implementation allocated the legacy heavy 552-scenario event slot
for every statistical tail event. The run was stopped after the capacity fault
was established. It was not overwritten or represented as a completed March
result. Commit `ec1a65d8` separated bounded statistical outcome tracking from
unchanged strategy-event allocation; the `_r2` runs are the formal completed
Step 15A evidence.
