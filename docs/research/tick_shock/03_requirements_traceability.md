# Tick-shock Step 3 requirements traceability

| TS15F-REQ-INTEGRITY | TS15FBuildFeatures | STEP15F-F01-EVALUATION-ORDER | TS15F-INTEGRITY-006 | tests/tick_shock/fixtures/TS15F-INTEGRITY-006_ticks.csv | tests/tick_shock/expected/TS15F-INTEGRITY-006_expected.csv | production-path integration | XFAIL before evaluation-order fix | Step 15F |
## Rules

- One row is one executable Test ID. A Requirement may have multiple boundary/direction tests.
- Function IDs are from 02_function_catalog.md and identify As-Is touchpoints, not oracle implementations.
- Fixture and expected paths are normative. Step 5 must not derive expected values by calling the Function IDs.
- NONE means no known defect is required to justify the requirement; it does not mean the code is proven.

## Coverage summary

- Requirement IDs: 40
- Test IDs: 64
- Defect IDs referenced: 14 / 14
- Every Requirement has at least one Test ID; every Test ID has one tick fixture, one config fixture, and one expected path.

## Traceability matrix

| Requirement ID | Function ID | Defect ID | Test ID | Fixture path | Expected path | Test layer | Current expected status | Fix Step |
|---|---|---|---|---|---|---|---|---|
| REQ-TIME-001 | EA-057, EA-061, EA-081, EA-083, EA-084, EX-005, EX-006, EX-007 | TS-KD-001 | TS-TIME-001 | tests/tick_shock/fixtures/TS-TIME-001_ticks.csv; tests/tick_shock/fixtures/TS-TIME-001_config.csv | tests/tick_shock/expected/TS-TIME-001_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-TIME-002 | EX-005, EX-006 | NONE | TS-TIME-002 | tests/tick_shock/fixtures/TS-TIME-002_ticks.csv; tests/tick_shock/fixtures/TS-TIME-002_config.csv | tests/tick_shock/expected/TS-TIME-002_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-TIME-002 | EX-005, EX-006 | NONE | TS-TIME-003 | tests/tick_shock/fixtures/TS-TIME-003_ticks.csv; tests/tick_shock/fixtures/TS-TIME-003_config.csv | tests/tick_shock/expected/TS-TIME-003_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-TIME-002 | EX-005, EX-006 | NONE | TS-TIME-004 | tests/tick_shock/fixtures/TS-TIME-004_ticks.csv; tests/tick_shock/fixtures/TS-TIME-004_config.csv | tests/tick_shock/expected/TS-TIME-004_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-TIME-003 | EX-005, EX-006, EX-007 | NONE | TS-TIME-005 | tests/tick_shock/fixtures/TS-TIME-005_ticks.csv; tests/tick_shock/fixtures/TS-TIME-005_config.csv | tests/tick_shock/expected/TS-TIME-005_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-TIME-002 | EX-005, EX-006 | NONE | TS-TIME-006 | tests/tick_shock/fixtures/TS-TIME-006_ticks.csv; tests/tick_shock/fixtures/TS-TIME-006_config.csv | tests/tick_shock/expected/TS-TIME-006_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-TIME-004 | EA-061, EA-070, EA-071, EX-006 | TS-KD-002 | TS-DETECT-001 | tests/tick_shock/fixtures/TS-DETECT-001_ticks.csv; tests/tick_shock/fixtures/TS-DETECT-001_config.csv | tests/tick_shock/expected/TS-DETECT-001_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-TIME-001 | EA-057, EA-061, EA-081, EA-083, EA-084, EX-005, EX-006, EX-007 | TS-KD-001 | TS-MERGE-001 | tests/tick_shock/fixtures/TS-MERGE-001_ticks.csv; tests/tick_shock/fixtures/TS-MERGE-001_config.csv | tests/tick_shock/expected/TS-MERGE-001_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-TIME-005 | EA-057, EA-068, EX-004, EX-006 | TS-KD-003 | TS-REV-001 | tests/tick_shock/fixtures/TS-REV-001_ticks.csv; tests/tick_shock/fixtures/TS-REV-001_config.csv | tests/tick_shock/expected/TS-REV-001_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-DET-001 | EA-032, EA-070, EX-008, SM-014 | TS-KD-004 | TS-RET-001 | tests/tick_shock/fixtures/TS-RET-001_ticks.csv; tests/tick_shock/fixtures/TS-RET-001_config.csv | tests/tick_shock/expected/TS-RET-001_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-DET-001 | EA-032, EA-070, EX-008, SM-014 | NONE | TS-RET-002 | tests/tick_shock/fixtures/TS-RET-002_ticks.csv; tests/tick_shock/fixtures/TS-RET-002_config.csv | tests/tick_shock/expected/TS-RET-002_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-DET-002 | EA-041, EA-044 | NONE | TS-PCT-001 | tests/tick_shock/fixtures/TS-PCT-001_ticks.csv; tests/tick_shock/fixtures/TS-PCT-001_config.csv | tests/tick_shock/expected/TS-PCT-001_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-DET-003 | EA-042, EA-044, SM-016 | NONE | TS-Z-001 | tests/tick_shock/fixtures/TS-Z-001_ticks.csv; tests/tick_shock/fixtures/TS-Z-001_config.csv | tests/tick_shock/expected/TS-Z-001_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-DET-003 | EA-042, EA-044, SM-016 | NONE | TS-Z-002 | tests/tick_shock/fixtures/TS-Z-002_ticks.csv; tests/tick_shock/fixtures/TS-Z-002_config.csv | tests/tick_shock/expected/TS-Z-002_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-DET-004 | EA-034 | NONE | TS-EFF-001 | tests/tick_shock/fixtures/TS-EFF-001_ticks.csv; tests/tick_shock/fixtures/TS-EFF-001_config.csv | tests/tick_shock/expected/TS-EFF-001_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-DET-004 | EA-034 | NONE | TS-EFF-002 | tests/tick_shock/fixtures/TS-EFF-002_ticks.csv; tests/tick_shock/fixtures/TS-EFF-002_config.csv | tests/tick_shock/expected/TS-EFF-002_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-DET-005 | EA-041, EA-044, EA-070, SM-005 | NONE | TS-INT-001 | tests/tick_shock/fixtures/TS-INT-001_ticks.csv; tests/tick_shock/fixtures/TS-INT-001_config.csv | tests/tick_shock/expected/TS-INT-001_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-DET-006 | EA-070, SM-005, SM-013 | NONE | TS-MOVE-001 | tests/tick_shock/fixtures/TS-MOVE-001_ticks.csv; tests/tick_shock/fixtures/TS-MOVE-001_config.csv | tests/tick_shock/expected/TS-MOVE-001_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-DET-007 | EA-041, EA-044, EA-070, SM-005 | NONE | TS-SPREAD-001 | tests/tick_shock/fixtures/TS-SPREAD-001_ticks.csv; tests/tick_shock/fixtures/TS-SPREAD-001_config.csv | tests/tick_shock/expected/TS-SPREAD-001_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-DET-008 | EA-070, SM-005 | NONE | TS-GATE-001 | tests/tick_shock/fixtures/TS-GATE-001_ticks.csv; tests/tick_shock/fixtures/TS-GATE-001_config.csv | tests/tick_shock/expected/TS-GATE-001_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-DET-009 | EA-044, EA-070 | TS-KD-008 | TS-BASE-001 | tests/tick_shock/fixtures/TS-BASE-001_ticks.csv; tests/tick_shock/fixtures/TS-BASE-001_config.csv | tests/tick_shock/expected/TS-BASE-001_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-DET-009 | EA-044, EA-070 | TS-KD-008 | TS-BASE-002 | tests/tick_shock/fixtures/TS-BASE-002_ticks.csv; tests/tick_shock/fixtures/TS-BASE-002_config.csv | tests/tick_shock/expected/TS-BASE-002_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-STATE-001 | EA-068, SM-002, SM-004 | TS-KD-008 | TS-STATE-LONG-001 | tests/tick_shock/fixtures/TS-STATE-LONG-001_ticks.csv; tests/tick_shock/fixtures/TS-STATE-LONG-001_config.csv | tests/tick_shock/expected/TS-STATE-LONG-001_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-STATE-002 | EA-068, SM-002, SM-004 | TS-KD-008 | TS-STATE-SHORT-001 | tests/tick_shock/fixtures/TS-STATE-SHORT-001_ticks.csv; tests/tick_shock/fixtures/TS-STATE-SHORT-001_config.csv | tests/tick_shock/expected/TS-STATE-SHORT-001_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-STATE-003 | SM-004 | NONE | TS-BURST-001 | tests/tick_shock/fixtures/TS-BURST-001_ticks.csv; tests/tick_shock/fixtures/TS-BURST-001_config.csv | tests/tick_shock/expected/TS-BURST-001_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-STATE-003 | SM-004 | NONE | TS-BURST-002 | tests/tick_shock/fixtures/TS-BURST-002_ticks.csv; tests/tick_shock/fixtures/TS-BURST-002_config.csv | tests/tick_shock/expected/TS-BURST-002_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-STATE-004 | EA-068, SM-003, SM-004 | NONE | TS-PB-001 | tests/tick_shock/fixtures/TS-PB-001_ticks.csv; tests/tick_shock/fixtures/TS-PB-001_config.csv | tests/tick_shock/expected/TS-PB-001_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-STATE-004 | EA-068, SM-003, SM-004 | NONE | TS-PB-002 | tests/tick_shock/fixtures/TS-PB-002_ticks.csv; tests/tick_shock/fixtures/TS-PB-002_config.csv | tests/tick_shock/expected/TS-PB-002_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-STATE-004 | EA-068, SM-003, SM-004 | NONE | TS-PB-003 | tests/tick_shock/fixtures/TS-PB-003_ticks.csv; tests/tick_shock/fixtures/TS-PB-003_config.csv | tests/tick_shock/expected/TS-PB-003_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-STATE-004 | EA-068, SM-003, SM-004 | TS-KD-003 | TS-INVALID-001 | tests/tick_shock/fixtures/TS-INVALID-001_ticks.csv; tests/tick_shock/fixtures/TS-INVALID-001_config.csv | tests/tick_shock/expected/TS-INVALID-001_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-STATE-005 | SM-004 | NONE | TS-TIMEOUT-001 | tests/tick_shock/fixtures/TS-TIMEOUT-001_ticks.csv; tests/tick_shock/fixtures/TS-TIMEOUT-001_config.csv | tests/tick_shock/expected/TS-TIMEOUT-001_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-STATE-005 | SM-004 | NONE | TS-NOREACCEL-001 | tests/tick_shock/fixtures/TS-NOREACCEL-001_ticks.csv; tests/tick_shock/fixtures/TS-NOREACCEL-001_config.csv | tests/tick_shock/expected/TS-NOREACCEL-001_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-EXEC-001 | EA-059, EA-061 | TS-KD-008 | TS-EXEC-LONG-001 | tests/tick_shock/fixtures/TS-EXEC-LONG-001_ticks.csv; tests/tick_shock/fixtures/TS-EXEC-LONG-001_config.csv | tests/tick_shock/expected/TS-EXEC-LONG-001_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-EXEC-002 | EA-059, EA-061 | TS-KD-008 | TS-EXEC-SHORT-001 | tests/tick_shock/fixtures/TS-EXEC-SHORT-001_ticks.csv; tests/tick_shock/fixtures/TS-EXEC-SHORT-001_config.csv | tests/tick_shock/expected/TS-EXEC-SHORT-001_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-EXEC-003 | EA-061, EX-011, EX-012 | TS-KD-006 | TS-RR-001 | tests/tick_shock/fixtures/TS-RR-001_ticks.csv; tests/tick_shock/fixtures/TS-RR-001_config.csv | tests/tick_shock/expected/TS-RR-001_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-EXEC-004 | EA-063, SM-021 | NONE | TS-TP-001 | tests/tick_shock/fixtures/TS-TP-001_ticks.csv; tests/tick_shock/fixtures/TS-TP-001_config.csv | tests/tick_shock/expected/TS-TP-001_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-EXEC-005 | EA-063, SM-021 | NONE | TS-SL-001 | tests/tick_shock/fixtures/TS-SL-001_ticks.csv; tests/tick_shock/fixtures/TS-SL-001_config.csv | tests/tick_shock/expected/TS-SL-001_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-EXEC-005 | EA-063, SM-021 | NONE | TS-SL-002 | tests/tick_shock/fixtures/TS-SL-002_ticks.csv; tests/tick_shock/fixtures/TS-SL-002_config.csv | tests/tick_shock/expected/TS-SL-002_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-EXEC-006 | EA-063, SM-008, SM-021 | NONE | TS-TIMEEXIT-001 | tests/tick_shock/fixtures/TS-TIMEEXIT-001_ticks.csv; tests/tick_shock/fixtures/TS-TIMEEXIT-001_config.csv | tests/tick_shock/expected/TS-TIMEEXIT-001_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-EXEC-007 | EA-056, EA-061 | NONE | TS-COMM-001 | tests/tick_shock/fixtures/TS-COMM-001_ticks.csv; tests/tick_shock/fixtures/TS-COMM-001_config.csv | tests/tick_shock/expected/TS-COMM-001_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-EXEC-008 | EA-061, EX-013, EX-014 | TS-KD-007 | TS-BROKER-001 | tests/tick_shock/fixtures/TS-BROKER-001_ticks.csv; tests/tick_shock/fixtures/TS-BROKER-001_config.csv | tests/tick_shock/expected/TS-BROKER-001_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-EXEC-009 | EA-060, EA-061, SM-018 | NONE | TS-POLICY-001 | tests/tick_shock/fixtures/TS-POLICY-001_ticks.csv; tests/tick_shock/fixtures/TS-POLICY-001_config.csv | tests/tick_shock/expected/TS-POLICY-001_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-MULTI-001 | EA-071, EA-076, EA-083, EX-010 | TS-KD-008 | TS-SAMEMSC-001 | tests/tick_shock/fixtures/TS-SAMEMSC-001_ticks.csv; tests/tick_shock/fixtures/TS-SAMEMSC-001_config.csv | tests/tick_shock/expected/TS-SAMEMSC-001_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-MULTI-002 | EA-078, EA-080, EA-081, EA-083, EA-084, SM-019 | TS-KD-008 | TS-MULTI-001 | tests/tick_shock/fixtures/TS-MULTI-001_ticks.csv; tests/tick_shock/fixtures/TS-MULTI-001_config.csv | tests/tick_shock/expected/TS-MULTI-001_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-MULTI-002 | EA-078, EA-080, EA-081, EA-083, EA-084, SM-019 | TS-KD-014 | TS-MERGE-002 | tests/tick_shock/fixtures/TS-MERGE-002_ticks.csv; tests/tick_shock/fixtures/TS-MERGE-002_config.csv | tests/tick_shock/expected/TS-MERGE-002_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-MULTI-003 | EA-070, EX-003, EX-009 | TS-KD-005 | TS-CLUSTER-001 | tests/tick_shock/fixtures/TS-CLUSTER-001_ticks.csv; tests/tick_shock/fixtures/TS-CLUSTER-001_config.csv | tests/tick_shock/expected/TS-CLUSTER-001_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-MULTI-004 | EA-070, EA-074 | TS-KD-005 | TS-CLUSTER-002 | tests/tick_shock/fixtures/TS-CLUSTER-002_ticks.csv; tests/tick_shock/fixtures/TS-CLUSTER-002_config.csv | tests/tick_shock/expected/TS-CLUSTER-002_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-MULTI-004 | EA-070, EA-074 | TS-KD-008 | TS-DUP-001 | tests/tick_shock/fixtures/TS-DUP-001_ticks.csv; tests/tick_shock/fixtures/TS-DUP-001_config.csv | tests/tick_shock/expected/TS-DUP-001_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-CSV-001 | EA-017, EA-020 | TS-KD-012 | TS-CSV-001 | tests/tick_shock/fixtures/TS-CSV-001_ticks.csv; tests/tick_shock/fixtures/TS-CSV-001_config.csv | tests/tick_shock/expected/TS-CSV-001_expected.csv | python | XFAIL | Step 6: defect correction/evidence rerun after Step 5 RED |
| REQ-CSV-002 | EA-074, EA-087 | NONE | TS-CSV-002 | tests/tick_shock/fixtures/TS-CSV-002_ticks.csv; tests/tick_shock/fixtures/TS-CSV-002_config.csv | tests/tick_shock/expected/TS-CSV-002_expected.csv | python | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-PROV-001 | EA-087, EA-090 | TS-KD-013 | TS-PROV-001 | tests/tick_shock/fixtures/TS-PROV-001_ticks.csv; tests/tick_shock/fixtures/TS-PROV-001_config.csv | tests/tick_shock/expected/TS-PROV-001_expected.csv | python | XFAIL | Step 6: defect correction/evidence rerun after Step 5 RED |
| REQ-ORDER-001 | OH-006, OH-007, OH-008, OH-009, OH-010, OH-027 | NONE | TS-ORDER-001 | tests/tick_shock/fixtures/TS-ORDER-001_ticks.csv; tests/tick_shock/fixtures/TS-ORDER-001_config.csv | tests/tick_shock/expected/TS-ORDER-001_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-ORDER-001 | OH-006, OH-007, OH-008, OH-009, OH-010, OH-027 | NONE | TS-ORDER-002 | tests/tick_shock/fixtures/TS-ORDER-002_ticks.csv; tests/tick_shock/fixtures/TS-ORDER-002_config.csv | tests/tick_shock/expected/TS-ORDER-002_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-ORDER-001 | OH-006, OH-007, OH-008, OH-009, OH-010, OH-027 | TS-KD-009 | TS-PARTIAL-001 | tests/tick_shock/fixtures/TS-PARTIAL-001_ticks.csv; tests/tick_shock/fixtures/TS-PARTIAL-001_config.csv | tests/tick_shock/expected/TS-PARTIAL-001_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-ORDER-002 | OH-008, OH-019, OH-026 | NONE | TS-ORDER-003 | tests/tick_shock/fixtures/TS-ORDER-003_ticks.csv; tests/tick_shock/fixtures/TS-ORDER-003_config.csv | tests/tick_shock/expected/TS-ORDER-003_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-ORDER-003 | OH-016, OH-017, OH-022, OH-027, OH-028 | TS-KD-011 | TS-SERVER-SL-LONG-001 | tests/tick_shock/fixtures/TS-SERVER-SL-LONG-001_ticks.csv; tests/tick_shock/fixtures/TS-SERVER-SL-LONG-001_config.csv | tests/tick_shock/expected/TS-SERVER-SL-LONG-001_expected.csv | strategy_tester | SKIP | Strategy Tester/controlled observation after Step 5; retain SKIP until observed |
| REQ-ORDER-003 | OH-016, OH-017, OH-022, OH-027, OH-028 | TS-KD-011 | TS-SERVER-SL-SHORT-001 | tests/tick_shock/fixtures/TS-SERVER-SL-SHORT-001_ticks.csv; tests/tick_shock/fixtures/TS-SERVER-SL-SHORT-001_config.csv | tests/tick_shock/expected/TS-SERVER-SL-SHORT-001_expected.csv | strategy_tester | SKIP | Strategy Tester/controlled observation after Step 5; retain SKIP until observed |
| REQ-ORDER-003 | OH-016, OH-017, OH-022, OH-027, OH-028 | TS-KD-011 | TS-SERVER-TP-LONG-001 | tests/tick_shock/fixtures/TS-SERVER-TP-LONG-001_ticks.csv; tests/tick_shock/fixtures/TS-SERVER-TP-LONG-001_config.csv | tests/tick_shock/expected/TS-SERVER-TP-LONG-001_expected.csv | strategy_tester | SKIP | Strategy Tester/controlled observation after Step 5; retain SKIP until observed |
| REQ-ORDER-003 | OH-016, OH-017, OH-022, OH-027, OH-028 | TS-KD-011 | TS-SERVER-TP-SHORT-001 | tests/tick_shock/fixtures/TS-SERVER-TP-SHORT-001_ticks.csv; tests/tick_shock/fixtures/TS-SERVER-TP-SHORT-001_config.csv | tests/tick_shock/expected/TS-SERVER-TP-SHORT-001_expected.csv | strategy_tester | SKIP | Strategy Tester/controlled observation after Step 5; retain SKIP until observed |
| REQ-ORDER-004 | OH-018, OH-022, OH-027 | NONE | TS-TIME-CLOSE-LONG-001 | tests/tick_shock/fixtures/TS-TIME-CLOSE-LONG-001_ticks.csv; tests/tick_shock/fixtures/TS-TIME-CLOSE-LONG-001_config.csv | tests/tick_shock/expected/TS-TIME-CLOSE-LONG-001_expected.csv | strategy_tester | SKIP | Strategy Tester/controlled observation after Step 5; retain SKIP until observed |
| REQ-ORDER-004 | OH-018, OH-022, OH-027 | NONE | TS-TIME-CLOSE-SHORT-001 | tests/tick_shock/fixtures/TS-TIME-CLOSE-SHORT-001_ticks.csv; tests/tick_shock/fixtures/TS-TIME-CLOSE-SHORT-001_config.csv | tests/tick_shock/expected/TS-TIME-CLOSE-SHORT-001_expected.csv | strategy_tester | SKIP | Strategy Tester/controlled observation after Step 5; retain SKIP until observed |
| REQ-ORDER-005 | OH-020, OH-025, OH-026, OH-028 | NONE | TS-POSITION-001 | tests/tick_shock/fixtures/TS-POSITION-001_ticks.csv; tests/tick_shock/fixtures/TS-POSITION-001_config.csv | tests/tick_shock/expected/TS-POSITION-001_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |
| REQ-ORDER-005 | OH-020, OH-025, OH-026, OH-028 | TS-KD-010 | TS-RESTART-001 | tests/tick_shock/fixtures/TS-RESTART-001_ticks.csv; tests/tick_shock/fixtures/TS-RESTART-001_config.csv | tests/tick_shock/expected/TS-RESTART-001_expected.csv | unit | PASS | Step 5: encode and run; no behavior fix planned |
| REQ-ORDER-005 | OH-020, OH-025, OH-026, OH-028 | TS-KD-010 | TS-RESTART-002 | tests/tick_shock/fixtures/TS-RESTART-002_ticks.csv; tests/tick_shock/fixtures/TS-RESTART-002_config.csv | tests/tick_shock/expected/TS-RESTART-002_expected.csv | production_path_integration | XFAIL | Step 4: injectable production seam; Step 5 verify; Step 6 only if mismatch remains |

## Defect coverage

- TS-KD-001: TS-TIME-001, TS-MERGE-001
- TS-KD-002: TS-DETECT-001
- TS-KD-003: TS-REV-001, TS-INVALID-001
- TS-KD-004: TS-RET-001
- TS-KD-005: TS-CLUSTER-001, TS-CLUSTER-002
- TS-KD-006: TS-RR-001
- TS-KD-007: TS-BROKER-001
- TS-KD-008: TS-BASE-001, TS-BASE-002, TS-STATE-LONG-001, TS-STATE-SHORT-001, TS-EXEC-LONG-001, TS-EXEC-SHORT-001, TS-SAMEMSC-001, TS-MULTI-001, TS-DUP-001
- TS-KD-009: TS-PARTIAL-001
- TS-KD-010: TS-RESTART-001, TS-RESTART-002
- TS-KD-011: TS-SERVER-SL-LONG-001, TS-SERVER-SL-SHORT-001, TS-SERVER-TP-LONG-001, TS-SERVER-TP-SHORT-001
- TS-KD-012: TS-CSV-001
- TS-KD-013: TS-PROV-001
- TS-KD-014: TS-MERGE-002

## Step 11 traceability addendum

| Requirement | Production function / path | Defect | Tests | Layer | Fix step |
|---|---|---|---|---|---|
| REQ-CONFIG-001 | `TSConfigValid` | TS-KD-015 | TS-CONFIG-001..005 | production-path integration | 12 |
| REQ-CONFIG-002 | EA `OnInit` | TS-KD-015 | TS-CONFIG-006 | source contract plus compile | 12 |
| REQ-COMM-001 | `TSBuildCommissionResult`, `TSMt5CommissionResult` | TS-KD-016 | TS-COMM-002..004 | production-path integration | 12 |
| REQ-RUN-001 | `TSRRunMetadataFingerprint`, `TSMt5OpenAppendCsv` | TS-KD-017 | TS-CSV-003..006 | production-path/source contract | 12 |
| REQ-INTEGRITY-001 | `TSRegisterResearchEvent`, `TSMergeAppend`, CopyTicks cursor | TS-KD-018 | TS-CAP-001..003, TS-CURSOR-001 | production-path integration | 12 |
| REQ-STATUS-001 | `TSScenarioStatusFromFeasibility`, `TSDirectionName` | TS-KD-019 | TS-STATUS-001..002, TS-DIRECTION-001 | unit/production function | 12 |
| REQ-ORDER-006 | `TSApplyEntryDeal`, lifecycle snapshot | TS-KD-020 | TS-ORDER-004..007 | production-path integration | 12 |
| REQ-WATERMARK-001 | `TickShockPendingRepository`, global frontier diagnostics | TS-KD-021 | TS-WATERMARK-001..002 | production-path integration | 12 |

Every Test ID maps one-to-one to its registry row, fixture/config pair, expected
file, raw observation row, and `step11_pre_fix_results.csv` evidence row.

## Step 12 resolution

REQ-CONFIG-001/002, REQ-COMM-001, REQ-RUN-001, REQ-INTEGRITY-001,
REQ-STATUS-001, REQ-ORDER-006 and REQ-WATERMARK-001 now point to
`reports/tests/tick_shock/step12_post_fix_results.csv` and `step12_raw/`.
All 26 Step 11 additions are observable and PASS. No deterministic
BLOCKED/FAIL/XFAIL/XPASS remains. Nine actual terminal-only cases retain SKIP.

## Step 14R versioned requirements

| Requirement | Production function / path | Test | Fixture / expected | RED evidence | GREEN evidence | Status |
|---|---|---|---|---|---|---|
| REQ-FRONTIER-002 quiet-range completeness | `TSFrontierBeginReadCycle`, `TSFrontierObserveCopyPage`, `TSMergeObserveReadThroughFrontier` | TS-MERGE-003 | `tests/tick_shock/fixtures/TS-MERGE-003_*`; `tests/tick_shock/expected/TS-MERGE-003_expected.csv` | `reports/tests/tick_shock/step14r_pre_fix/raw/multicurrency_merge.csv` | `reports/tests/tick_shock/step14r_final/raw/multicurrency_merge.csv` | PASS |
| REQ-FRONTIER-003 true read failure is fail-closed | same | TS-MERGE-004 | `tests/tick_shock/fixtures/TS-MERGE-004_*`; `tests/tick_shock/expected/TS-MERGE-004_expected.csv` | test already passed before production fix | `reports/tests/tick_shock/step14r_final/raw/multicurrency_merge.csv` | PASS |
| REQ-FRONTIER-004 transient failure recovery | same | TS-MERGE-005 | `tests/tick_shock/fixtures/TS-MERGE-005_*`; `tests/tick_shock/expected/TS-MERGE-005_expected.csv` | `reports/tests/tick_shock/step14r_transient_recovery_pre_fix/multicurrency_merge.csv` | `reports/tests/tick_shock/step14r_final/raw/multicurrency_merge.csv` | PASS |
| REQ-ORDER-007 transaction reordering | `TSConfigureOrderIdentity`, `TSApplyOrderDeal` | TS-ORDER-008 | `tests/tick_shock/fixtures/TS-ORDER-008_*`; `tests/tick_shock/expected/TS-ORDER-008_expected.csv` | `reports/tests/tick_shock/step14r_pre_fix/raw/order_lifecycle.csv` | `reports/tests/tick_shock/step14r_final/raw/order_lifecycle.csv` | PASS |
| REQ-ORDER-008 operation identity separation | `TSAttachExitOperationIdentity`, order harness transaction adapter | TS-ORDER-009 | `tests/tick_shock/fixtures/TS-ORDER-009_*`; `tests/tick_shock/expected/TS-ORDER-009_expected.csv` | `reports/tests/tick_shock/step14r_pre_fix/raw/order_lifecycle.csv` | deterministic GREEN plus `step14r_order_observation_final/order_observations.csv` | PASS / OBSERVED_PASS |

`TS-MERGE-002` remains the obsolete legacy-watermark contract with its original
fixture and hash. Step 14R does not rewrite it; the new tests carry the revised
requirement explicitly.

## Change-control boundary

A Function ID may change location/name in Step 4, but the Requirement ID, Test ID, fixture path, expected path, and independent numeric outcome remain stable. Traceability is updated only to point at the extracted equivalent. If a desired defect correction changes an expected value, it requires a reviewed specification change separate from production implementation.
