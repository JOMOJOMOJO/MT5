# Step 15G GREEN report

- deterministic suite: PASS 360 / FAIL 0 / XFAIL 0 / XPASS 0 / SKIP 9 / BLOCKED 0
- Step 15G contracts: 47 PASS
- compile: 18 targets, 0 errors, 0 warnings
- production path: `TickShockEconomicPath.mqh` is called by the research EA for shock episodes and matched controls
- research orders: zero; no OrderCheck or OrderSend was added
- tick CSV: disabled
- formal commission: unavailable outside the limited EURUSD tester observation

The 46 preregistered RED rows changed to PASS through the production implementation and harness. A separate regression contract, `TS15G-INTEGRITY-011`, protects causal post-entry processing under global-merge lag. Expected values were not derived from production code. The independent Decimal oracle covers 51 risk, outward-barrier-rounding, and merge-lag checks; the full CSV reconciliation is stored beside this report.
