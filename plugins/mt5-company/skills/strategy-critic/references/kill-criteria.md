# Kill Criteria

## Stop pushing the current algorithm when:

- PF stays below 1.0 after multiple independent windows
- Only a tiny parameter region works
- Out-of-sample collapses while in-sample looks strong
- Profit depends on one logic bucket that is not repeatable
- Trade count is too small to judge but optimization keeps picking it

## Continue carefully when:

- PF is improving but still below the target
- Drawdown is falling and the weak bucket is identifiable
- The same weakness appears across multiple runs and suggests one clear fix
