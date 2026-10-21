import numpy as np
import pandas as pd

from tools.entry_research.diagnostics.statistics import class_summary, timing_summary, summarize_curves


def test_empty_class_is_visible_and_ratios_preserve_full_denominator():
    frame = pd.DataFrame({'method': ['a', 'a'], 'side': ['LONG', 'LONG'],
                          'class_label': ['immediate_adverse', 'unclassifiable_data'], 'common_pool': [True, False]})
    summary = class_summary(frame)
    group = summary[(summary.population == 'all_origins') & (summary.grouping == 'all')]
    assert len(group) == 8
    assert group.n.sum() == 2
    assert group.ratio.sum() == 1
    assert group.loc[group.class_label.eq('no_direction'), 'n'].iloc[0] == 0


def test_timing_cost_decomposition_does_not_select_only_fills():
    rows = []
    for i in range(4):
        for policy in ['immediate', 'pullback']:
            filled = policy == 'immediate' or i < 2
            row = dict(origin_candidate_id=str(i), method='a', side='LONG', week=f'w{i}', year=2024+i%2,
                       common_pool=True, policy=policy, status='filled' if filled else 'expired', wait_bars=1 if filled else np.nan)
            for endpoint in ['hold10', 'deadline50']:
                row['net_' + endpoint] = -1.9 if filled else np.nan
                row['opp_net_' + endpoint] = -1.9 if filled else 0
                row['opp_gross_' + endpoint] = 0.
            rows.append(row)
    strategy = pd.DataFrame(rows)
    control = strategy.assign(replicate=0)
    result = timing_summary(strategy, control, {'seed': 2, 'bootstrap_reps': 100,
        'timing_baseline_holm_family': 4, 'timing_immediate_holm_family': 2})
    p = result[(result.policy == 'pullback') & (result.endpoint == 'hold10')].iloc[0]
    assert p.n == 4 and p.filled == 2
    assert p.conditional_net == -1.9
    assert p.opportunity_net == -.95
    assert p.delta_immediate == .95
    assert p.saved_cost_per_origin == .95
    assert p.delta_gross_immediate == 0
    assert p.delta_baseline == 0


def test_curves_average_control_replicates_not_pooled_rows():
    rows = []
    for dataset, rep, n, value in [('strategy', -1, 4, 2.), ('baseline', 0, 1, 1.), ('baseline', 1, 3, 3.)]:
        row = dict(dataset=dataset, replicate=rep, year=2024, method='a', side='LONG', horizon=1, n=n)
        row.update({metric: value*n for metric in ['gross_pips','net_pips','gross_atr','net_atr','mfe_atr','mae_atr']})
        rows.append(row)
    result = summarize_curves(pd.DataFrame(rows)).iloc[0]
    assert result.baseline_net_pips == 2.
    assert result.delta_net_pips == 0.
