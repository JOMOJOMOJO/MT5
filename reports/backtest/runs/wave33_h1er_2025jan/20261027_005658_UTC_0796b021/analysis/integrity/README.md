# H1 ER12 native OFF/ON integrity audit

Read-only independent audit; no MT5 launch, strategy edit or threshold change.

Result: **PASS: 52/52 checks**.

| Item | OFF | ON |
|---|---:|---:|
| Native requested period | 2025.01.01–2025.02.01 | same |
| Real-tick quality reported by MT5 | 100% | 100% |
| Actual tick count | 4,010,784 | 4,010,784 |
| Generated M1 bars | 30,163 | 30,163 |
| Exported closed M1/M5 bars | 30,163 / 6,042 | identical byte hashes |
| H1 pure policy checks | 45 PASS / 0 FAIL | 45 PASS / 0 FAIL |
| Unique entry positions | 29 | 16 |
| Native trade count / exit legs | 37 | 21 |
| Raw deal count | 66 | 37 |
| Net USD including commissions, swap, fees | −536.91 | −255.43 |
| Native gross profit / gross loss USD | 410.17 / −947.08 | 281.19 / −536.62 |
| Native PF unrounded | 0.4331 | 0.5240 |
| Native max equity DD USD / percent | 562.47 / 11.20% | 275.35 / 5.49% |
| Final balance USD | 4,463.09 | 4,744.57 |

Both arms reach January31 market close and the native tester states `Test passed` / `thread finished`. Shutdown/forced-close text occurs after completion. No fallback/absent/discarded/mismatch tick warning or native initialization error was found. The requested real-tick mode and the native 100% real-tick report agree. Journal excerpts and SHA256 identities are saved beside this note.

Native HTML embeds all54 inputs and they match the frozen presets. The only behavioral difference is `InpSkipH1LowEfficiency=false/true`; run tag differs for log isolation. Native config differs only by this flag, resolved run tag, and the expected input hash. Runtime EX5, terminal and tester binaries remain identical to their launch hashes. Initial symbol and historical cache fingerprints match between arms. Actual closed M1 and M5 exports are byte-identical, including `known_at` and OHLC. The protected125 existing source/preset files and all frozen deployment artifacts are independently SHA256 checked against current repository files without rerunning or resetting the earlier QA script/status.

Raw profit + commission + swap + fee sums equal both native report net and final balance minus5000 exactly. Every position's in/out volume balances; no positions remain unresolved. The OFF swap total is +10.24USD; ON swap is0. Total commissions across all in/out deals are−34.92 / −19.68USD. Native gross-loss accounting includes all commission/swap adjustments. Native PF uses exit-leg accounting and must not be mistaken for an independent setup-level PF. The root performance analysis should use initial full-position risk and reconcile partial exits once per setup.

Limitations: report/journal real-tick evidence is not an independent reconstruction of every tick. No complete executable tick stream was exported; equal cache fingerprints/counts/actual bars are strong consistency evidence. January1 has no source market ticks; first real ticks are January2. One pre-start already-closed Dec31 bar is exported at initialization; the last forming M1 bar is intentionally not classified as closed. Historical symbol specifications and UTC offset mapping remain broker/source assumptions. This January-only exploratory result supports comparison integrity, not profitability or adoption; both arms lose money.

Machine evidence: [integrity.json](integrity.json). Reproduce without launching MT5: `python audit_native_integrity.py`.
