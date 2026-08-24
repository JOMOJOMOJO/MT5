# Step 11 pre-fix test additions

Step 11 extends the executable specification without changing production code.
The Step 10 research EA SHA remains
`D33CF37A0534F812112F29EC01F1463A6AFB816740BECC8DE23E561D7E17A539`.

Added coverage: six configuration, three commission, four run identity/writer,
four capacity/cursor, three status/direction, four idempotent order-ledger, and
two watermark integrity tests.

The 10 deterministic Step 10 seam cases remain PASS. Of the 26 additions,
24 reproduce an expected mismatch as XFAIL, `TS-COMM-003` is XPASS because the
existing single-deduction calculation already matches the oracle, and
`TS-CURSOR-001` is BLOCKED because no production-callable page/cursor seam exists.
The nine terminal-only observations remain SKIP. No Step 3 fixture or expected
file was edited.

Run command:

`powershell -NoProfile -ExecutionPolicy Bypass -File tools/tick_shock/run_all_tests.ps1 -TimeoutSeconds 45 -Phase step11`
