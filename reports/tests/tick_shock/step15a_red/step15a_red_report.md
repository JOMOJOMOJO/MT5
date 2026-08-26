# Tick-shock Step 15A RED detector tests

- frozen spec: `docs/research/tick_shock/15a_shock_definition_spec.md` (`53DB75EEE4641D98F4917E74B9C26B84D07533CE8EA1A6689AF7F36BAAEA64EA`)
- independent oracle: `tools/tick_shock/step15a_independent_oracle.py`
- registry tests: 24
- PASS: 1
- FAIL: 0
- XFAIL: 23
- XPASS: 0
- SKIP: 0
- BLOCKED: 0

The pre-fix detector harness fails compilation because the declared production `TickShockStatisticalDetector.mqh` API does not exist. This is the expected RED observation for the 23 V1 contract tests. `STRICT_V0` remains independently covered by the unchanged Step 14R production path and is PASS, not inferred from a V1 stub.
