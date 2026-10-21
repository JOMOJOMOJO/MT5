import numpy as np
import pandas as pd
import pytest
from tools.entry_research.multiasset.tests.test_execution import fixture
from tools.entry_research.multiasset.execution import simulate as original
from tools.entry_research.account_replay.execution import simulate
from tools.entry_research.account_replay.calendar import annotate_bars, classify_interval, WEEKEND_POLICY


def weekend(side='LONG'):
    b,c,s,g=fixture(side=side)
    start=int(pd.Timestamp('2024-01-05 23:50').timestamp())
    b.time=start+np.arange(len(b))*300
    b.loc[2:,'time']+=172800
    c['entry_time']=c['signal_time']=b.time.iloc[1]
    g['calendar_policy']=WEEKEND_POLICY
    return b,c,s,g


def test_calendar_is_explicit_and_exact():
    b,_,_,_=weekend()
    assert annotate_bars(b,300).gap_before_status.iloc[2]=='unknown_gap'
    a=annotate_bars(b,300,WEEKEND_POLICY)
    assert a.gap_before_status.iloc[2]=='scheduled_closure'
    assert a.gap_before_seconds.iloc[2]==172800
    pd.testing.assert_frame_equal(a[b.columns],b)
    for extra in [-300,300,3600,86400]:
        assert classify_interval(b.time.iloc[1],b.time.iloc[2]+extra,300,WEEKEND_POLICY)[0]=='unknown_gap'


def test_unverified_holiday_is_not_approved():
    prev=int(pd.Timestamp('2024-12-24 23:55').timestamp())
    nxt=int(pd.Timestamp('2024-12-26').timestamp())
    state,_,evidence=classify_interval(prev,nxt,300,WEEKEND_POLICY)
    assert state=='unknown_gap' and 'holiday' in evidence


@pytest.mark.parametrize('side',['LONG','SHORT'])
def test_holding_clock_counts_bars_but_keeps_weekend_exposure(side):
    b,c,s,g=weekend(side)
    result=simulate(b,c,s,g);t=result['trades']
    assert t.status.eq('closed').all() and t.exit_reason.eq('time_exit').all()
    assert t.holding_bars.eq(2).all()
    assert t.elapsed_wallclock_seconds.eq(172800+600).all()
    assert t.closure_crossings.eq(1).all() and t.closure_seconds.eq(172800).all()
    assert t.source_day_boundaries_crossed.eq(3).all()
    np.testing.assert_allclose(t.lot_source_day_exposure,t.volume*3)
    assert t.all_in_net_pnl_usd.isna().all() and t.swap_cost_usd.isna().all()
    assert result['summary'].account_path_complete.all()
    assert not result['summary'].account_pnl_promotion_eligible.any()


@pytest.mark.parametrize('side',['LONG','SHORT'])
@pytest.mark.parametrize('hit',['stop','target'])
def test_reopen_gap_fills_actual_open_not_barrier(side,hit):
    b,c,s,g=weekend(side)
    sign=1 if side=='LONG' else -1
    price=1.1+sign*(.003 if hit=='target' else -.003)
    b.loc[2,['open','high','low','close']]=[price,price+.0001,price-.0001,price]
    t=simulate(b,c,s,g)['trades']
    assert t.exit_reason.eq(hit+'_gap_open').all()
    assert t.exit_time.eq(b.time.iloc[2]).all()
    expected=price+(.0002 if side=='SHORT' else 0)-sign*.00002
    np.testing.assert_allclose(t.exit_fill,expected,atol=1e-10)
    if hit=='stop':assert t.loss_exceeds_planned_risk.all()


def test_new_candidate_after_weekend_is_not_blocked():
    b,c,s,g=weekend()
    later=c.assign(candidate_id='later',entry_index=3,signal_index=2,
                   entry_time=b.time.iloc[3],signal_time=b.time.iloc[3])
    r=simulate(b,pd.concat([c,later]),s,g)
    assert r['events'].status.eq('executed').all()
    assert r['summary'].n_closed.eq(2).all()


def test_extra_gap_or_forged_annotations_cannot_authorize_missing_quotes():
    b,c,s,g=weekend();b.loc[2:,'time']+=300
    b['gap_before_status']='scheduled_closure'
    t=simulate(b,c,s,g)['trades']
    assert t.status.eq('censored_time_gap').all()
    assert t.net_pnl_usd.isna().all()
    assert t.closure_crossings.eq(0).all()


def test_data_end_censors_after_observed_bars_without_forced_exit():
    b,c,s,g=weekend();g['max_hold_bars']=10
    t=simulate(b,c,s,g)['trades']
    assert t.status.eq('censored_data_end').all()
    assert t.holding_bars.eq(5).all()
    assert t.net_pnl_usd.isna().all() and t.closure_crossings.eq(1).all()


def test_continuous_data_keeps_original_cashflows_and_event_contract():
    for side in ['LONG','SHORT']:
        b,c,s,g=fixture(side=side)
        old=original(b,c,s,g);new=simulate(b,c,s,dict(g,calendar_policy=WEEKEND_POLICY))
        for key in ['trades','events','equity','summary']:
            pd.testing.assert_frame_equal(new[key][old[key].columns],old[key],check_dtype=False)


def test_future_closure_change_cannot_change_already_closed_trade():
    b,c,s,g=weekend();b.loc[1,'high']=1.102
    t=simulate(b,c,s,g)['trades']
    b.loc[2:,'time']+=300
    pd.testing.assert_frame_equal(t,simulate(b,c,s,g)['trades'])
