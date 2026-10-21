"""Same-window reset of four independent books to isolate shared capital effects."""
import numpy as np
import pandas as pd

from ..account_replay.execution import simulate, SCENARIOS
from ..monthly_review.diagnostics import monthly


def independent_reference(bars, candidates, specs, execution, config, start, end):
    accounts, month_rows, summary_rows = {}, [], []
    admitted = candidates.filter_pass & candidates.calendar_pass & candidates.entry_time.ge(start) & candidates.entry_time.lt(end)
    cells = config['cell_order']
    initial = config['initial_equity']/len(cells)
    for cell in cells:
        c = candidates.loc[admitted & candidates.cell_id.eq(cell)]
        raw = candidates.loc[candidates.cell_id.eq(cell)].iloc[0]
        ex = dict(execution, initial_equity=initial, risk_fraction=config['risk_fraction']*len(cells),
                  end_exclusive=end, method=raw.method, side=raw.side)
        r = simulate(bars[raw.symbol], c, specs[raw.symbol], ex)
        accounts[cell] = r
        for scenario in SCENARIOS:
            summary = r['summary'].set_index('scenario').loc[scenario]
            if not summary.account_path_complete:
                continue
            t = r['trades'].loc[r['trades'].scenario.eq(scenario)].copy()
            for col in ['net_pnl_before_unknown_swap_usd', 'exit_reason']:
                if col not in t:
                    t[col] = pd.Series(dtype=float if col != 'exit_reason' else str)
            available = pd.period_range(pd.Timestamp(start, unit='s').to_period('M'),
                                       pd.Timestamp(end-1, unit='s').to_period('M'),freq='M').astype(str)
            eq = r['equity'].loc[r['equity'].scenario.eq(scenario)].copy()
            if eq.time.min() > start:
                # This is reserved cash before the symbol is available, not
                # synthetic price history or a fabricated trading return.
                cash_start = eq.iloc[0].copy()
                cash_start['time'] = start
                cash_start['phase'] = 'initial_reserved_cash'
                eq = pd.concat([pd.DataFrame([cash_start]), eq], ignore_index=True)
            m = monthly(t, eq, available, initial)
            m = m.loc[m.data_available].copy()
            m['cell_id'], m['scenario'] = cell, scenario
            month_rows.append(m)
    detail = pd.concat(month_rows, ignore_index=True)
    combined = []
    for scenario in SCENARIOS:
        complete = all(r['summary'].set_index('scenario').loc[scenario, 'account_path_complete'] for r in accounts.values())
        trades = pd.concat([r['trades'].loc[r['trades'].scenario.eq(scenario)] for r in accounts.values()], ignore_index=True)
        closed = trades.loc[trades.status.eq('closed')]
        cash = closed.net_pnl_before_unknown_swap_usd if len(closed) else pd.Series(dtype=float)
        sub = detail.loc[detail.scenario.eq(scenario)]
        m = sub.groupby('month', as_index=False).agg(equity_change_usd=('equity_change_usd','sum'), n_entries=('n_entries','sum'), books=('cell_id','nunique'))
        if complete:
            assert m.books.eq(len(cells)).all()
            assert np.isclose(m.equity_change_usd.sum(), cash.sum(), atol=1e-6)
            m['scenario'] = scenario
            combined.append(m)
        summary_rows.append(dict(scenario=scenario, complete=complete, n_closed=len(closed),
            net_pnl_before_unknown_swap_usd=cash.sum(),
            profit_factor=cash.clip(lower=0).sum() / -cash.clip(upper=0).sum() if cash.lt(0).any() else np.nan,
            monthly_positive=int(m.equity_change_usd.gt(1e-10).sum()) if complete else np.nan,
            available_months=len(m) if complete else np.nan))
    return dict(accounts=accounts, summary=pd.DataFrame(summary_rows),
                monthly=pd.concat(combined, ignore_index=True) if combined else pd.DataFrame())
