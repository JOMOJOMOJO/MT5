# Remaining research artifact exclusions

Following the user's approval to exclude remaining artifacts and publish,
793 currently untracked report files are excluded using exact paths in
`reports/.gitignore`. Their original classifications and hashes are in
`reports/checkpoints/tick_shock/publish_20260915/inventory.csv`.
No data is deleted. No broad rule hides future research files.

The existing research branch is appropriate: all published work belongs to
the same Tick-shock research lineage, so no artificial branch split is made.
Destination: `https://github.com/JOMOJOMOJO/MT5.git`, branch
`research/tickshock/2026-09-13-two-stage-ml` (not main).

18 existing tracked changes remain deliberately uncommitted: the two deleted
historical technical includes, one regenerated EX5, 14 Step 15G compiler
logs and the Step 15G aggregate suite CSV containing later Step 15H rows.
They are not hidden with assume-unchanged/skip-worktree and are not restored.
The source deletion intent and historical evidence provenance have not been
established. Creating a new branch would not establish that provenance.
Those changes are excluded from this publication, not endorsed as a repair.

This operation changes only Git exclusion rules and documentation. It does
not alter production logic, test expectations, or backtest outcomes.
