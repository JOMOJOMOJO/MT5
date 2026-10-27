# Feb–Mar2025 H1 ER native integrity audit

**PASS_WITH_DATA_LIMITATIONS: 67/67 checks.** Read-only audit; no MT5 launch, no EA edits, no threshold changes. Frozen comparison: XAUUSD+, M5×M1, native period2025.02.01–2025.04.01.

| Item | OFF | ON |
|---|---:|---:|
| Unique actual entry positions | 71 | 36 |
| Native trade count (exit legs) | 104 | 49 |
| Raw deals | 175 | 85 |
| Net USD including all costs | -289.6700000000 | -400.6400000000 |
| Native PF | 0.85 | 0.65 |
| Native maximum equity DD | 474.42 (9.31%) | 539.73 (10.69%) |
| Native maximum balance DD | 426.55 (8.41%) | 496.90 (9.89%) |
| Final balance USD | 4710.33 | 4599.36 |
| Native H1 observations | 91 | 92 |

Both arms show the rounded native label100% real ticks, 8,306,849 ticks and56,327 generated M1 bars, finish through the final market tick2025.03.31 23:57:54, and state Test passed/thread finished. However, the journal explicitly reports6minutes with absent real ticks and14minutes with discarded real ticks, all20using generated ticks; this is approximately0.0355% of56,327minute bars. February27 has5discarded minute bars/169mismatched tick prices; March27 has6absent+9discarded minute bars/1,297mismatched tick prices. The day-summary timestamp23:59does not identify which minutes were affected. Another2,741minute bars have absent last prices and useBid. Both arms have exactly the same data warning signatures. **The pure real-tick gate is NOT PASSED.** Comparable mixed-data results remain descriptive, with no assumption that generated execution exactly matches unseen real ticks. Native journal excerpts and SHA256 identities are saved beside this report.

Actual closed M1 and M5 CSV files are byte-identical between arms, including OHLC and known_at. All91 matching decision H1 windows agree on all13 prices/times and ER metadata. Every logged valid H1 ER was independently recalculated using Decimal and checked for closed-bar availability. Missing data are recorded and allowed, not silently converted toER0. Both arms execute45 pure policy checks with no failures.

All54 actual native inputs match the frozen presets and January baseline except run tag. The only behavioral OFF/ON difference is InpSkipH1LowEfficiency. All125 protected prior sources/presets and34 deployment artifact hashes remain unchanged. Remaining runtime artifacts/presets/private INI hashes and frozen job hashes match their prepared identities. TEMP runtime terminal64.exe/metatester64.exe files are absent after execution, so their current hashes cannot be rechecked; prelaunch hashes/verification retain their launch identities. No earlier verification script was rerun and no QA/runtime status was reset.

Cash reconciliation includes profit, commissions, swaps and fees across all in/out deals. Net equals both native report and final balance minus5000 exactly. Partial exits are grouped once per position for completeness; native trade count includes multiple exit legs and must not be used as the number of independent entries.

OFF also records16partial-close rejections for Market closed on March20 01:00:29–55 for LONG setup196. The retry succeeds at01:01:00 for0.10lot; the remaining0.10lot later closes atSL01:19:36. No rejection appears in ON because this trade is filtered. These are execution effects already included in realized P/L; they are not an initializer failure or an unresolved position.

As a conservative descriptive sensitivity, [warning_day_position_exposure.csv](warning_day_position_exposure.csv) flags any position whose holding interval overlaps the entire February27/March27 dates. OFF has2positions totaling−84USD; ON has1totaling−36USD. Arithmetic removal leavesOFF−205.67USD versusON−364.64USD, so ON remains worse in this limited check. Exact bad minutes are unknown; this does not reconstruct a corrected tick stream, rerun lot/equity/candidate paths, or justify a strategy day filter.

## TEST_END and censoring

Both TEST_END rows refer to the same LONG candidate W33_XAUUSD+_5_1_LONG_1743455700_243 in LOWER_COUNTERTREND, entry_status=CANDIDATE, no order/fill. That candidate has no raw deals. All actual position in/out volumes balance; no positions remain open, and no raw deal or journal close is labelled end-of-test. Last actual exits are regular SL exits several hours before23:57:54. Consequently, removing terminal-forced closures changes realized profit/loss by0 in both arms. The unfinished setup is right-censored for candidate-conversion studies, not an extra losing/winning trade. A weekend closure in the raw deals is the strategy's normal weekend rule, not tester censorship.

February/March are a continuous account path. Monthly attribution should use original entry month and disclose crossing positions rather than resetting capital at each month boundary. Broker/source clock mapping and historical symbol specification changes remain assumptions. These results do not establish causality or profitability; both arms lose money and the ON native PF/DD are worse.

Machine evidence: [integrity.json](integrity.json). Reproduce read-only: python audit_native_integrity.py.
