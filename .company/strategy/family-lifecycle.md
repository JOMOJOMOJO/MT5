# Strategy Family Lifecycle

## States

- `incubating`
  - early hypothesis
  - fast search only
- `serious-validation`
  - actual MT5 and rolling split evidence exist
- `demo-forward-candidate`
  - live controls and proving path exist
- `small-live-staged`
  - reduced-risk first-capital preset exists
- `secondary`
  - valid but not the main business engine
- `parked`
  - kept for reference, not worth more mainline tuning
- `legacy`
  - historical only
- `killed`
  - not to be revived without a new thesis

## Plateau Rule

- Run a plateau review whenever:
  - three serious cycles have happened in the same family,
  - or the family keeps missing the active business objective,
  - or the latest actual MT5 and recent OOS both fail to improve the current best branch meaningfully.

- A `serious cycle` means at least one of:
  - a long-window actual MT5 run,
  - a rolling `9 months train / 3 months OOS` review,
  - a demo-forward review.

## Plateau Outcomes

- `continue`
  - improvement is still real enough to justify another cycle
- `tighten`
  - the issue is execution, risk, or one named rule defect
- `park_secondary_and_open_new_family`
  - the family is still useful, but not for the active objective
- `kill`
  - the family keeps failing on both quality and objective fit

## Default Action

- If the family is quality-positive but objective-negative:
  - mark it `secondary` or `parked`
  - open a new family immediately
- Do not keep forcing a low-turnover family into a high-turnover role.
- Do not keep adding indicators when the real problem is structural.
