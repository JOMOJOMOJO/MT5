from types import SimpleNamespace
import numpy as np
import pandas as pd
import pytest
from tools.entry_research.early_loss.analysis import (FEATURES, LOCK, labels, pre_entry_features,
    path_features,valid_window,comparisons)


def fixture(side='LONG'):
    t=pd.DataFrame([dict(candidate_id='a',side=side,method='donchian',entry_time=1704070800,atr14=2.)])
    c=pd.DataFrame([dict(candidate_id='a',available_time=1704070800,signal_time=1704070800,
        atr14=2.,h4_trend='up',h4_available_time=1704070800,high=103.,low=99.,open=100.,close=102.,
        recent_move_atr=1.5,relative_vol=1.1,ema_fast=100.5,spread=2,dc_high=101.,dc_low=99.,
        cloud_upper=101.,cloud_lower=98.,trend='up',vol_bucket='normal',cloud_position='above',signal_index=0)])
    return t,c,dict(point=.01,pip_size=.01)


def test_direction_and_confirmed_signal_features():
    t,c,s=fixture();long=pre_entry_features(t,c,s).iloc[0]
    t.side='SHORT';short=pre_entry_features(t,c,s).iloc[0]
    assert long.signed_body_atr==1 and short.signed_body_atr==-1
    assert long.rejection_wick_fraction==.25 and short.rejection_wick_fraction==.25
    assert long.h1_alignment=='aligned' and short.h1_alignment=='opposed'
    assert long.breakout_margin_atr==.5 and short.breakout_margin_atr==-1.5


def test_unreferenced_future_signal_does_not_change_past_features():
    t,c,s=fixture();original=pre_entry_features(t,c,s)
    future=c.copy();future.candidate_id='future';future.signal_time+=3600;future.high=100000.
    pd.testing.assert_frame_equal(original,pre_entry_features(t,pd.concat([c,future]),s))


@pytest.mark.parametrize('bad',['h4','signal','holdout','atr'])
def test_reject_leakage_and_atr_drift(bad):
    t,c,s=fixture()
    if bad=='h4':c.h4_available_time+=1
    elif bad=='signal':c.available_time+=1
    elif bad=='holdout':t.entry_time=LOCK;c.signal_time=LOCK;c.available_time=LOCK
    else:c.atr14=3.
    with pytest.raises(ValueError):pre_entry_features(t,c,s)


def test_label_ambiguity_is_not_early_stop():
    t=pd.DataFrame(dict(net_pnl_before_unknown_swap_usd=[-1,-1,-1,1],holding_bars=[1,2,3,2],
                        exit_reason=['stop_ambiguous','stop','stop','target'],ambiguous=[True,False,False,False]))
    assert labels(t).tolist()==['ambiguous','early_stop','late_stop','early_win']


@pytest.mark.parametrize('side,fill,stop,target',[('LONG',100.2,99.2,101.2),('SHORT',99.9,100.9,98.9)])
def test_quote_cost_geometry_and_neutral_barriers(side,fill,stop,target):
    b=pd.DataFrame(dict(time=[1704070800,1704074400],open=[100.,100.],high=[100.5,100.5],low=[99.5,99.5],close=[100.,100.],gap_before_status=['contiguous']*2))
    t=SimpleNamespace(entry_index=0,exit_index=0,atr14=1.,entry_time=1704070800,exit_time=1704074400,
        side=side,entry_fill=fill,stop_price=stop,target_price=target,entry_spread_pips=10.)
    x=path_features(t,SimpleNamespace(signal_low=99.,signal_high=101.),b,dict(pip_size=.01))
    assert x['fill_stop_atr']==pytest.approx(1.)
    assert x['quote_stop_distance_atr']==pytest.approx(.8)
    assert x['quote_target_distance_atr']==pytest.approx(1.2)
    assert x['neutral_stop_reached_first2']==False
    assert x['path_valid_h10']==False and np.isnan(x['bid_close_return_atr_h10'])


def test_unknown_gaps_are_missing_not_zero_return():
    b=pd.DataFrame(dict(time=[1704070800,1704078000],open=[100.]*2,high=[101.]*2,low=[99.]*2,close=[100.]*2,gap_before_status=['contiguous','unknown_gap']))
    assert not valid_window(b,0,2)
    b.loc[1,'gap_before_status']='scheduled_closure'
    assert valid_window(b,0,2)
    b.loc[1,'time']=LOCK
    assert not valid_window(b,0,2)


def test_block_comparison_keeps_fixed_cell_effect_and_is_repeatable():
    rows=[]
    for k,day in enumerate(pd.date_range('2024-12-02',periods=12,freq='7D')):
        for cell,offset in [('a',0),('b',100)]:
            for label,shift in [('early_stop',1),('early_win',0)]:
                rows.append(dict(cell=cell,week=str(day.date()),year=day.year,label=label,holding_bars=1,
                    net_pnl_before_unknown_swap_usd=-1 if label=='early_stop' else 1,
                    **{f:offset+shift for f in FEATURES}))
    a,b=comparisons(pd.DataFrame(rows),reps=30,seed=4)
    a2,b2=comparisons(pd.DataFrame(rows),reps=30,seed=4)
    pd.testing.assert_frame_equal(a,a2);assert b==b2
    assert np.allclose(a.cell_weighted_mean_difference,1.)
    assert np.allclose(a.difference_2024,1.) and np.allclose(a.difference_2025,1.)
