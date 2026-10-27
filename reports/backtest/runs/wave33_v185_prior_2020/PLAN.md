# Wave33 v1.85 M5/M1: prior-level retest fixed comparison

Status: prepared; native execution waits for root READY.

The user authorized the proposed comparison on 2026-10-26. This is an in-sample mechanism diagnostic on the already observed 2020 data, not new out-of-sample evidence or live promotion.

## Frozen comparison

- Symbol XAUUSD+, M5/M1 pattern B, tester chart M1.
- 2020-01-01 through 2021-01-01, source/broker time retained without an invented UTC mapping.
- Initial equity USD 5,000, leverage 100, risk 1%, RR input 1.0.
- Scale out OFF. Existing original TP extension, original SL, opposite-W1 profit exit, deep-Fib-close exclusion, and connected-W1 exclusion unchanged.
- The prior context diagnostic stays ON. Prior band fraction stays exactly 0.05. Choppy-W1 skip stays OFF.
- The only strategy input difference is `InpSkipPriorLevelRetest=false` versus `true`. Output tag also differs to prevent mixed files.
- All 45 inputs are copied from [the prior v1.85 B scale-OFF run](../wave33_v185_2020/20261026_100045_50909ab6/v185_b_scale_off/inputs.set). No defaults are inferred or thresholds tuned.

## Provenance and safety

EA source, binary and 17 Wave33 headers must match the prior final QA deployment. Terminal and metatester executables, plus 2019/2020/2021 HCC caches, must match the prior annual provenance. A changed cache or new native tick archive is a hard stop rather than a silent data change.

The source data root is fixed to the preserved prior annual portable runtime, `%LOCALAPPDATA%/CodexMT5Wave33ScaleOut/20261026_100045_50909ab6`. Its history, symbol metadata, identity cache, and server cache are copied read-only into the new runtime. Current installed-terminal symbol caches differ from this preserved runtime, so they are deliberately excluded from this fixed comparison. Symbol files and identity cache hashes are recorded without publishing account-bearing filenames.

Model 4 is requested as before, but the preserved 2020 source has no TKC native tick files. The expected result is generated ticks with 0% real ticks; this cannot establish real-tick execution quality.

The runner creates a new private portable terminal under `%LOCALAPPDATA%/CodexMT5Wave33Prior2020/`, launches Hidden, disables ordinary-chart live trading, uses tester-only EA orders, and never changes or stops an installed terminal. It uses a task-specific tester port and checks for at least 4 GB free before execution. Cleanup stops only processes whose executable paths belong to this newly created runtime.

## Audit

Two new native runs, OFF followed by ON. Preserve inputs, native HTML, full tagged diagnostic exports including raw deals, events, chop/prior-context logs, source bars, runtime identity, cache hashes, method snapshots, and redacted tester journals. The OFF run should reproduce the prior 334 positions / USD -1,440.92; any mismatch must be explained before interpreting the ON comparison.

Independent analysis will reconcile native totals, raw cash (profit, commission, swap and fee), position-level R, drawdown, losing streak, quarterly/directional stability, blocked winners/losers, and newly possible trades after occupancy changes. A post-hoc deletion of blocked positions is not treated as equivalent to a fresh tester run.

No 2026 history, optimization, new filters or threshold adjustment is authorized in this comparison. If the remaining group is still negative or improvement is concentrated, retain that result without rescue tuning.

Baseline: [prior provenance](../wave33_v185_2020/20261026_100045_50909ab6/provenance.json), [prior review](../wave33_v185_2020/FINAL_REVIEW.md).
