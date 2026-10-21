import pandas as pd
from tools.entry_research.shared_portfolio.tests.test_engine import setup
from tools.entry_research.shared_portfolio.reference import independent_reference


def test_reserved_cash_before_symbol_coverage_is_not_missing_equity():
    b,c,s,e,g = setup()
    shift = int(pd.Timestamp('2024-08-01 08:00',tz='UTC').timestamp())-int(b.time.iloc[0])
    b['time'] += shift
    c['signal_time'] += shift
    c['entry_time'] += shift
    g['cell_order'] = ['A']
    r = independent_reference({'EURUSD':b},c,{'EURUSD':s},e,g,
                              int(pd.Timestamp('2024-01-01',tz='UTC').timestamp()),
                              int(pd.Timestamp('2024-09-01',tz='UTC').timestamp()))
    assert len(r['monthly']) == 16
    jan = r['monthly'].loc[r['monthly'].month.eq('2024-01')]
    assert jan.n_entries.eq(0).all() and jan.equity_change_usd.eq(0).all()
    assert r['summary'].complete.all()
