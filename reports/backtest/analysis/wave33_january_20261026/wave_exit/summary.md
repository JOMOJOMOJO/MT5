# January wave geometry and actual-holding exit paths

Fixed natural cuts; descriptive only. No EA launch or mutation.

| run | month | n | wins | losses | breakeven | win_rate | net_r | mean_r | net_cash | pf_r | pf_cash |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| gold_v180 | 2025-01 | 28 | 8 | 20 | 0 | 0.2857 | -9.707 | -0.3467 | -469.8 | 0.5187 | 0.5055 |
| gold_v190 | 2025-01 | 23 | 4 | 18 | 1 | 0.1739 | -9.499 | -0.413 | -451.3 | 0.4466 | 0.4455 |
| usd_v180 | 2025-01 | 32 | 11 | 21 | 0 | 0.3438 | -9.794 | -0.3061 | -451.3 | 0.5783 | 0.5816 |
| usd_v180 | 2025-02 | 18 | 7 | 11 | 0 | 0.3889 | -0.7325 | -0.04069 | -39.56 | 0.9353 | 0.924 |
| usd_v180 | 2025-03 | 30 | 14 | 16 | 0 | 0.4667 | -1.973 | -0.06577 | -102.8 | 0.8783 | 0.8582 |

## Loss paths

| run | month | loss_path_class | n | wins | losses | breakeven | win_rate | net_r | mean_r | net_cash | pf_r | pf_cash |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| gold_v180 | 2025-01 | LOSS_WITHOUT_1R | 19 | 0 | 19 | 0 | 0 | -19.17 | -1.009 | -889.8 | 0 | 0 |
| gold_v180 | 2025-01 | REACHED_1R_THEN_LOSS | 1 | 0 | 1 | 0 | 0 | -1 | -1 | -60.25 | 0 | 0 |
| gold_v190 | 2025-01 | LOSS_WITHOUT_1R | 16 | 0 | 16 | 0 | 0 | -16.13 | -1.008 | -763.8 | 0 | 0 |
| gold_v190 | 2025-01 | REACHED_1R_THEN_LOSS | 2 | 0 | 2 | 0 | 0 | -1.031 | -0.5154 | -50 | 0 | 0 |
| usd_v180 | 2025-01 | LOSS_WITHOUT_1R | 18 | 0 | 18 | 0 | 0 | -18.34 | -1.019 | -848.8 | 0 | 0 |
| usd_v180 | 2025-01 | REACHED_1R_THEN_LOSS | 3 | 0 | 3 | 0 | 0 | -4.883 | -1.628 | -229.8 | 0 | 0 |
| usd_v180 | 2025-02 | LOSS_WITHOUT_1R | 11 | 0 | 11 | 0 | 0 | -11.33 | -1.03 | -520.8 | 0 | 0 |
| usd_v180 | 2025-03 | LOSS_WITHOUT_1R | 16 | 0 | 16 | 0 | 0 | -16.21 | -1.013 | -725.2 | 0 | 0 |

## Streaks

| run | month | ordering | max_loss_streak | start | end | net_r |
| --- | --- | --- | --- | --- | --- | --- |
| gold_v180 | 2025-01 | fill_at | 9 | 2025-01-14 12:15:06 | 2025-01-20 17:13:03 | -9.072 |
| gold_v180 | 2025-01 | exit_at | 9 | 2025-01-14 13:54:12 | 2025-01-20 18:24:12 | -9.072 |
| gold_v190 | 2025-01 | fill_at | 8 | 2025-01-14 12:15:02.085000 | 2025-01-20 17:13:08.066000 | -8.063 |
| gold_v190 | 2025-01 | exit_at | 8 | 2025-01-14 13:54:12.781000 | 2025-01-20 18:24:12.879000 | -8.063 |
| usd_v180 | 2025-01 | fill_at | 5 | 2025-01-28 16:24:08 | 2025-01-31 09:33:08 | -5.118 |
| usd_v180 | 2025-01 | exit_at | 5 | 2025-01-28 16:32:01 | 2025-01-31 10:07:18 | -5.118 |
| usd_v180 | 2025-02 | fill_at | 4 | 2025-02-26 09:46:07 | 2025-02-28 17:45:00 | -4.238 |
| usd_v180 | 2025-02 | exit_at | 4 | 2025-02-26 09:47:20 | 2025-02-28 17:59:07 | -4.238 |
| usd_v180 | 2025-03 | fill_at | 3 | 2025-03-06 22:00:03 | 2025-03-10 09:27:04 | -3 |
| usd_v180 | 2025-03 | exit_at | 3 | 2025-03-06 22:36:28 | 2025-03-10 09:45:51 | -3 |

## Boundaries and nulls

- Gold January versions differ in timing/exits; do not pool trades as independent observations.
- Only USD has February/March in frozen inputs; Gold has no out-of-month validation here.
- Small January n (especially winners) prevents reliable feature selection.
- M1 BID extrema in boundary minutes are uncertain; do not claim fill/exit tick path from OHLC.
- Recorded current H1 classification is not a new H1/H4 market-context reconstruction.
- Native v190 MFE is observed while held, not hypothetical post-exit upside.

All actual trades, immutable SL, causal entry metrics and MFE bounds: features.csv. Full fixed-bin results: stratifications.csv. Per-outcome medians: outcome_feature_statistics.csv. Native/CSV audits: summary.json.