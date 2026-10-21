import json
from pathlib import Path

import numpy as np
import pandas as pd

from tools.entry_research.multiasset.tests.test_execution import fixture
from tools.entry_research.account_replay.execution import simulate
from tools.entry_research.shared_portfolio.engine import simulate_shared, notional_usd


def setup():
    b, c, spec, ex = fixture(count=30)
    spec['tick_size'] = spec['point']
    ex['assumed_spread_pips'] = {'EURUSD': 2.}
    c['cell_id'], c['filter_pass'], c['calendar_pass'] = 'A', True, True
    cfg = json.loads((Path(__file__).parents[1] / 'config.json').read_text())
    cfg['cell_order'] = ['A', 'B']
    return b, c, spec, ex, cfg


def run(b, c, spec, ex, cfg, **kw):
    return simulate_shared({'EURUSD': b}, c, {'EURUSD': spec}, ex, cfg,
                           start=int(b.time.iloc[0]), end=int(b.time.iloc[-1]+300), **kw)


def duplicate(c, side=None, index=None, b=None):
    other = c.copy()
    other['candidate_id'], other['cell_id'] = 'b', 'B'
    if side:
        other['side'] = side
    if index is not None:
        other['signal_index'], other['entry_index'] = index-1, index
        other['signal_time'] = other['entry_time'] = b.time.iloc[index]
    return pd.concat([c, other], ignore_index=True)


def test_single_rule_matches_frozen_cash_and_volume():
    b,c,s,e,g = setup()
    r = run(b,c,s,e,g)
    old = simulate(b,c,s,dict(e,initial_equity=g['initial_equity'],risk_fraction=g['risk_fraction']))
    old = old['trades'].query("scenario == 'stop_first_lower'").iloc[0]
    new = r['trades'].iloc[0]
    for col in ['entry_fill','exit_fill','volume','planned_risk_usd','net_pnl_before_unknown_swap_usd']:
        assert new[col] == old[col]
    assert np.isclose(r['equity'].iloc[-1].balance_usd-g['initial_equity'], new.net_pnl_before_unknown_swap_usd)


def test_high_low_future_does_not_change_same_time_admission_or_size():
    b,c,s,e,g = setup()
    c = duplicate(c, side='SHORT')
    old = run(b,c,s,e,g)
    b.loc[1:, ['high','low']] = [1.12,1.08]
    changed = run(b,c,s,e,g)
    for r in [old,changed]:
        assert len(r['trades']) == 2
    pd.testing.assert_series_equal(old['trades'].set_index('cell_id').volume.sort_index(),
                                  changed['trades'].set_index('cell_id').volume.sort_index())


def test_fixed_priority_risk_margin_and_opposite_block():
    b,c,s,e,g = setup()
    c = duplicate(c, side='SHORT').iloc[::-1]
    r = run(b,c,s,e,dict(g,max_open_risk_fraction=.0003))
    assert r['events'].set_index('cell_id').loc['B','status'] == 'skipped_portfolio_risk_cap'
    assert r['trades'].cell_id.tolist() == ['A']
    r = run(b,c,s,e,g,mode='block_opposite')
    assert r['events'].set_index('cell_id').loc['B','status'] == 'skipped_opposite_position'
    r = run(b,c,s,e,dict(g,assumed_leverage=.1))
    assert r['trades'].empty and r['events'].status.eq('skipped_assumed_margin').all()


def test_rule_overlap_and_close_before_next_entry():
    b,c,s,e,g = setup()
    c = duplicate(c,index=2,b=b)
    c['cell_id'] = 'A'
    r = run(b,c,s,e,g)
    assert r['events'].iloc[1].status == 'skipped_rule_overlap'
    c.loc[1,['signal_index','entry_index']] = [2,3]
    c.loc[1,['signal_time','entry_time']] = b.time.iloc[3]
    r = run(b,c,s,e,g)
    assert r['complete'] and len(r['trades']) == 2
    assert r['trades'].iloc[0].exit_time == r['trades'].iloc[1].entry_time


def test_same_timestamp_friction_can_halt_second_entry():
    b,c,s,e,g = setup()
    r = run(b,duplicate(c),s,e,dict(g,daily_entry_halt_fraction=.000001))
    assert r['events'].set_index('cell_id').loc['B','status'] == 'skipped_daily_entry_halt'


def test_censor_does_not_reopen_or_publish_future_pnl():
    b,c,s,e,g = setup()
    e['max_hold_bars'] = 10
    b.loc[3:,'time'] += 3600
    c = duplicate(c,index=3,b=b)
    r = run(b,c,s,e,g)
    assert not r['complete']
    assert r['events'].iloc[1].status == 'skipped_account_censored'
    assert r['trades'].exit_time.isna().all()
    assert r['trades'].net_pnl_before_unknown_swap_usd.isna().all()


def test_close_exposure_does_not_read_next_open_and_currency_conversion():
    b,c,s,e,g = setup()
    e['max_hold_bars'] = 10
    old = run(b,c,s,e,g)
    b.loc[2:, ['open','close','high','low']] = [1.2,1.2,1.2004,1.1996]
    changed = run(b,c,s,e,g)
    for r in [old,changed]:
        mark = r['equity'].loc[r['equity'].phase.eq('bar_close') & r['equity'].time.eq(b.time.iloc[2])].iloc[0]
        assert np.isclose(mark.gross_exposure_usd, r['trades'].iloc[0].volume*100000*1.1001)
    assert notional_usd('USDJPY',.1,100000,150) == 10000
    assert notional_usd('AUDUSD',.1,100000,.65) == 6500
