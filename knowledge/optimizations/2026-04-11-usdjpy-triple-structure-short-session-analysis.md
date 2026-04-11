# USDJPY Triple-Structure Short Session Analysis

- Date: `2026-04-11`
- Family:
  - `usdjpy_20260411_triple_structure_method2_scaffold`
- Data source:
  - `FILE_COMMON` telemetry written by the all-day `actual-16m` runs
- Goal:
  - test whether hour selection can rescue the family without collapsing sample count below the standalone floor.

## Why Session Review Was Needed

- The baseline all-day runs already met the user's turnover target.
- That means any session filter is allowed only if it improves actual MT5 quality while still leaving enough sample to describe the family as a realistic standalone candidate.

## Strong Only Hour Review

### Positive hour pockets

- `04`
- `06`
- `13`
- `14`
- `17`

### Clearly weak hour pockets

- `01`
- `05`
- `08`
- `09`
- `10`
- `11`
- `21`

### Strong-only actual 16m hour summary

- `13`: `3 exits / net +42.14 / PF 5.58`
- `14`: `3 exits / net +33.16 / PF 1.95`
- `17`: `2 exits / net +33.81 / PF 3.47`
- `06`: `3 exits / net +12.03 / PF 3.91`
- `04`: `1 exit / net +31.68`

The issue is obvious: the best hours exist, but they are too sparse.

## Strong Plus Standard Hour Review

### Positive hour pockets

- `04`
- `13`
- `14`
- `17`

### Clearly weak hour pockets

- `01`
- `05`
- `08`
- `09`
- `10`
- `11`
- `20`
- `21`

### Strong+Standard actual 16m hour summary

- `13`: `2 exits / net +50.71 / PF 81.49`
- `14`: `3 exits / net +30.24 / PF 1.86`
- `17`: `2 exits / net +34.53 / PF 3.67`
- `04`: `2 exits / net +15.19 / PF 1.98`

`Standard` inventory did not open a new stable hour regime. It mostly widened weak inventory.

## Frequency-Constrained Subset Search

I searched hour subsets on the actual telemetry to answer one concrete question:

- Can an hour filter make the family positive without pushing the count below the repo's minimum useful sample?

### Strong only

- No positive hour subset exists at `40+ exits`.
- Best subset with `40+ exits`:
  - hours `1,3,7,13,15,17`
  - `41 exits / net -144.96 / PF 0.74`
- Best positive subset appears only at `30 exits`:
  - hours `3,4,6,7,13,14,16,17`
  - `30 exits / net +80.26 / PF 1.28`

### Strong + Standard

- No positive hour subset exists at `40+ exits`.
- Best subset with `40+ exits`:
  - hours `1,3,7,13,14,15`
  - `40 exits / net -149.81 / PF 0.74`
- Best positive subset appears only at `30 exits`:
  - hours `3,4,6,7,13,14,17`
  - `30 exits / net +47.10 / PF 1.15`

## Read

- Session routing can improve the family only by cutting it down into a sparse survivor.
- That violates the cycle rule:
  - do not promote sparse high-PF behavior as the standalone mainline.
- There is no evidence that an hour filter can keep the family near `1 trade / 3 trading days` while also clearing the repo quality floor.

## Decision

- Do not create a session-filtered promotion preset for this family.
- Use the session review as negative evidence:
  - the family is not failing because it trades at the wrong hour alone,
  - it is failing because the core short pattern does not scale into a durable, high-count edge on this feed.

## Reusable Lesson

- For this Method2 family, session filtering is a diagnostic tool, not a rescue path.
- If the only positive route appears after collapsing the sample toward `30 exits` over `16 months`, the research answer is `fresh thesis`, not another filter pass.
