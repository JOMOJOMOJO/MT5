# QA Checklist

- [ ] Compile succeeds with `scripts/compile.ps1`.
- [ ] The EA uses a unique magic number strategy.
- [ ] Volume respects broker min lot, max lot, and step size.
- [ ] Stops and pending prices respect stops level and freeze level.
- [ ] Spread, session, and symbol filters are explicit.
- [ ] Duplicate entries are prevented across repeated ticks or retries.
- [ ] Backtest sample size is large enough to be informative.
- [ ] Forward assumptions are not based on one optimization peak.
- [ ] MT5 report artifacts are imported into `reports/backtest/runs/` and reflected in `knowledge/backtests/` when the result matters.
