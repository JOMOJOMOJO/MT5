"""Descriptive aggregation of four selected independent books, not a portfolio replay."""
from pathlib import Path
import hashlib
import json

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'reports/research/hypothesis_cycle_20261019/validated'
OUT = ROOT / 'reports/research/four_pattern_monthly_20261019'
CELLS = ['USDJPY_donchian_LONG_margin025', 'USDJPY_atr_breakout_SHORT_margin025',
         'USDCHF_donchian_SHORT_margin025', 'AUDUSD_rsi2_pullback_SHORT_rsi2']


def main():
    if OUT.exists():
        raise FileExistsError('Keep existing evidence; output already exists')
    m = pd.read_parquet(SOURCE / 'monthly.parquet')
    m = m.loc[m.cell_id.isin(CELLS) & m.pause & m.scenario.eq('stop_first_lower')]
    summaries, frames, correlations, inputs = [], [], [], [SOURCE / 'monthly.parquet']
    for cost in ['base', 'stress']:
        sub = m.loc[m.cost.eq(cost)]
        pnl = sub.pivot(index='month', columns='cell_id', values='equity_change_usd').reindex(columns=CELLS)
        counts = sub.pivot(index='month', columns='cell_id', values='n_entries').reindex(columns=CELLS)
        common = pnl.notna().all(axis=1)
        t = []
        for cid in CELLS:
            path = SOURCE / 'accounts' / cid / f'{cost}_pause/trades.parquet'
            inputs.append(path)
            trades = pd.read_parquet(path)
            trades = trades.loc[trades.scenario.eq('stop_first_lower')].copy()
            assert trades.status.eq('closed').all()
            trades['cell_id'] = cid
            trades['entry_month'] = pd.to_datetime(trades.entry_time, unit='s', utc=True).dt.strftime('%Y-%m')
            t.append(trades)
        trades = pd.concat(t, ignore_index=True)
        assert trades.entry_time.lt(1767225600).all()
        assert np.isclose(trades.net_pnl_before_unknown_swap_usd.sum(), pnl.sum().sum(), atol=1e-7)
        detail = pnl.copy()
        detail['books_available'] = pnl.notna().sum(axis=1)
        detail['all_four_available'] = common
        # Strict combined column stays missing when one book is unobserved.
        detail['four_book_mtm_usd'] = pnl.sum(axis=1, min_count=4)
        detail['four_book_entries'] = counts.sum(axis=1, min_count=4)
        detail['available_books_mtm_usd_reference'] = pnl.sum(axis=1)
        detail['cost'] = cost
        frames.append(detail.reset_index())
        for scope, labels in [('available_books_mixed_coverage_reference', pnl.index),
                              ('all_four_common_months', pnl.index[common])]:
            selected = trades.loc[trades.entry_month.isin(labels)]
            cash = selected.net_pnl_before_unknown_swap_usd
            monthly = pnl.loc[labels].sum(axis=1)
            summaries.append(dict(cost=cost, scope=scope, months=len(labels), trades=len(selected),
                trades_per_month=len(selected)/len(labels), net_closed_cash_usd=cash.sum(),
                pf=cash.clip(lower=0).sum() / -cash.clip(upper=0).sum(),
                positive_months=int(monthly.gt(1e-10).sum()), negative_months=int(monthly.lt(-1e-10).sum()),
                monthly_marked_change_usd=monthly.sum(), worst_month_usd=monthly.min(),
                mean_r=selected.result_r.mean(), std_r=selected.result_r.std(),
                win_rate=cash.gt(0).mean(), shared_account_replayed=False))
        corr = pnl.loc[common].corr().rename_axis('cell_a').reset_index().melt(id_vars='cell_a', var_name='cell_b', value_name='monthly_correlation')
        corr['cost'], corr['common_months'] = cost, int(common.sum())
        correlations.append(corr)
    OUT.mkdir(parents=True)
    tables = {'summary': pd.DataFrame(summaries), 'monthly': pd.concat(frames), 'correlations': pd.concat(correlations)}
    for name, frame in tables.items():
        frame.to_csv(OUT / f'{name}.csv', index=False, encoding='utf-8-sig')
        frame.to_parquet(OUT / f'{name}.parquet', index=False)
    manifest = dict(selected_after_results=True, selection='four rows from preceding assistant answer',
        cells=CELLS, weights_optimized=False, independent_books_initial_usd_each=10000,
        shared_account_replayed=False, holdout_2026_used=False,
        missing_months='USDCHF Jan-Jul2024 not zero; common-month result primary',
        pf_scope='pooled closed trade cash, not average of individual PF',
        common_pf_cohort='entry months in common coverage; monthly PnL uses boundary MTM',
        input_sha256={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},
        script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    print(tables['summary'].to_string(index=False))


if __name__ == '__main__':
    main()
