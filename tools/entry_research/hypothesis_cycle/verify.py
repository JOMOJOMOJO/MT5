"""Read-only audit of a saved cycle, with deterministic representative replays."""
import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd

from ..multiasset.data import sha
from .run import ROOT, SOURCE, DATA, prepare, simulate_cell, LOWER


def audit(directory, replay=True):
    out = Path(directory).resolve()
    manifest = json.loads((out / 'manifest.json').read_text())
    for mapping, root in [(manifest['protected_hashes'], None), (manifest['output_hashes'], out),
                          (manifest['source_hashes'], ROOT)]:
        for name, expected in mapping.items():
            path = Path(name) if root is None else root / name
            assert sha(path) == expected, f'Hash changed: {path}'
    a = pd.read_parquet(out / 'accounts.parquet')
    m = pd.read_parquet(out / 'monthly.parquet')
    v = pd.read_parquet(out / 'verdict.parquet')
    dispositions = pd.read_parquet(out / 'original_dispositions.parquet')
    assert len(v) == 19 and len(a) == 142
    assert not manifest['holdout_2026_used'] and not manifest['independent_oos']
    keys = ['cell_id', 'cost', 'pause', 'scenario']
    assert not a.duplicated(keys).any()
    n_verified = 0
    for account in a.to_dict('records'):
        cid, cost, pause, scenario = [account[k] for k in keys]
        directory = out / 'accounts' / cid / f'{cost}_{"pause" if pause else "raw"}'
        t = pd.read_parquet(directory / 'trades.parquet')
        t = t.loc[t.scenario.eq(scenario)]
        c = t.loc[t.status.eq('closed')]
        assert len(c) == account['n_closed']
        cash = c.net_pnl_before_unknown_swap_usd if len(c) else pd.Series(dtype=float)
        assert np.isclose(cash.sum(), account['net_pnl_before_unknown_swap_usd'], atol=1e-7)
        gains, losses = cash.clip(lower=0).sum(), -cash.clip(upper=0).sum()
        pf = gains / losses if losses > 0 else np.nan
        assert np.isclose(pf, account['profit_factor'], equal_nan=True)
        raw = pd.read_parquet(out / 'candidates' / f'{cid}.parquet')
        if len(t):
            joined = t.merge(raw[['candidate_id', 'signal_time']], on='candidate_id', validate='one_to_one')
            assert joined.signal_time.le(joined.entry_time).all()
            assert joined.entry_time.lt(1767225600).all()
        d = dispositions.loc[dispositions.cell_id.eq(cid) & dispositions.cost.eq(cost)
                             & dispositions.pause.eq(pause) & dispositions.scenario.eq(scenario)]
        assert len(d) == len(raw) and d.candidate_id.nunique() == len(raw)
        assert d.status.notna().all()
        assert d.admitted.sum() == account['n_candidates']
        month = m.loc[m.cell_id.eq(cid) & m.cost.eq(cost) & m.pause.eq(pause) & m.scenario.eq(scenario)]
        if account['account_path_complete']:
            assert len(month) == 24
            assert np.isclose(month.equity_change_usd.sum(), cash.sum(), atol=1e-7)
            assert month.n_entries.sum() == len(t)
            assert month.loc[~month.data_available, 'equity_change_usd'].isna().all()
        else:
            assert month.empty, 'Censored tail must not become zero months'
        n_verified += 1
    for row in v.to_dict('records'):
        mask = a.cell_id.eq(row['cell_id']) & a.cost.eq('base') & a.pause & a.scenario.eq(LOWER)
        summary = a.loc[mask].iloc[0]
        assert row['complete'] == summary.account_path_complete
        assert row['n_trades'] == summary.n_closed
        assert not row['advance_to_independent_validation'] or all(row[k] for k in
            ['gate_profit', 'gate_monthly', 'gate_stress', 'gate_statistics'])
    replayed = []
    if replay:
        original = json.loads((SOURCE / 'manifest.json').read_text())['config']
        data = json.loads((DATA / 'manifest.json').read_text())
        cycle = manifest['cycle']
        bars, _, cells, _, _ = prepare(data, original)
        selected = ['USDJPY_donchian_LONG_margin025', 'AUDUSD_rsi2_pullback_SHORT_rsi2']
        for cell in cells:
            if cell['cell_id'] not in selected:
                continue
            cid, symbol = cell['cell_id'], cell['symbol']
            r = simulate_cell(cell, bars[symbol], data['specs'][symbol], original, cycle, 'base', True)
            for name, actual in r.items():
                saved = pd.read_parquet(out / 'accounts' / cid / 'base_pause' / f'{name}.parquet')
                pd.testing.assert_frame_equal(actual, saved, check_exact=True)
            replayed.append(cid)
    return dict(status='PASS', account_scenarios_verified=n_verified,
                hypotheses_verified=len(v), representative_replays_exact=replayed,
                protected_hashes_unchanged=True, source_hashes_match=True,
                monthly_equity_cash_reconciled=True, original_candidates_accounted=True,
                censored_months_not_fabricated=True, holdout_2026_used=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    parser.add_argument('--no-replay', action='store_true')
    args = parser.parse_args()
    print(json.dumps(audit(args.directory, replay=not args.no_replay), indent=2))
