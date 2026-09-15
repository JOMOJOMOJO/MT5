# Accumulated research checkpoint

Publication scope: existing branch `research/tickshock/2026-09-13-two-stage-ml`.
Base HEAD: `292e9494bb7332837c2c00d74244bae9da6bcda1`.

Separate commits preserve (1) monthly collection / technical ML / 4m2m
research, (2) remaining two-stage development QA, (3) fixed-time exit
comparison and matched-entry diagnosis, and (4) protected SL/TP barrier grid.
No strategy logic is changed during this checkpoint. This is not promotion.

The inventory and commit plan are under
`reports/checkpoints/tick_shock/publish_20260915/`.
Every excluded path has a reason and its current SHA-256 where present.
Large evidence (>2 MB per file), duplicate replay, terminal HTML/journals,
runtime status/locks and binary artifacts remain local, not deleted.
The inventory covers git-visible pending files, not all ignored MT5 cache.
Existing deleted `mql/Include/TickShock/TickShockTechnicalFeatures.mqh` and
`TickShockTechnicalStudy.mqh` are deliberately not staged: deletion intent
was not established. Historical Step 15G generated changes also remain local.
Therefore this checkpoint intentionally does not make the worktree clean.
Existing historical source bundles are retained; this operation does not
assert that every old EA compiles from the present dirty worktree.

## Completed barrier experiment

Evidence: `reports/backtest/batches/two_stage_barrier_grid_20260914_r3/`.
All nine runs completed with integrity PASS, 248 closed trades each, no
remaining positions or reconciliation errors. July/August are development.
All nine net results are negative in both months. No geometry is adopted.
TP 0.68 / SL 0.55 ATR: net -477.98 USD; PF 0.7035; expectancy -0.19711R;
88 TP, 160 SL, zero TIME; mean hold 201.938 seconds, max 1458.015 seconds.
July 115 trades / -379.40 USD; August 133 trades / -98.58 USD.
Actual commission/fee/swap were zero in the tester, not a general broker-cost
claim. Spread is embedded in actual Bid/Ask fills. SL-risk R differs from
the old time-only experiment's ATR normalization, so those R values are not
directly comparable. The existing model is not demonstrated profitable.

Prior r1/r2 failed harness attempts remain labeled evidence, not successes.
No new backtest, compile, model fitting or optimization is run for publication.
Staged whitespace, credential-pattern checks and final remote HEAD equality
are checked separately from the historical strategy QA.
