"""Read-only checks of all shared ledgers, plus optional exact main replay."""
import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd

from ..multiasset.data import sha
from .run import ROOT, load_inputs
from .engine import simulate_shared


def audit(out, replay=True):
    out = Path(out).resolve()
    manifest = json.loads((out/'manifest.json').read_text())
    for path, expected in manifest['protected_hashes'].items():
        assert sha(path) == expected, path
    for path, expected in manifest['source_hashes'].items():
        assert sha(ROOT/path) == expected, path
    for path, expected in manifest['output_hashes'].items():
        assert sha(out/path) == expected, path
    summaries = pd.read_parquet(out/'summary.parquet')
    months = pd.read_parquet(out/'monthly.parquet')
    raw = pd.read_parquet(out/'original_candidates.parquet')
    assert len(summaries) == 16 and summaries.profile.nunique() == 16
    cfg = manifest['config']
    order = {c: i for i,c in enumerate(cfg['cell_order'])}
    for summary in summaries.to_dict('records'):
        directory = out/'profiles'/summary['profile']
        t = pd.read_parquet(directory/'trades.parquet')
        e = pd.read_parquet(directory/'equity.parquet')
        events = pd.read_parquet(directory/'events.parquet')
        assert len(events) == len(raw) and events.candidate_id.nunique() == len(raw)
        assert not events.status.isin(['pending','open']).any()
        closed = t.loc[t.status.eq('closed')]
        cash = closed.net_pnl_before_unknown_swap_usd
        assert len(closed) == summary['n_closed']
        assert np.isclose(cash.sum(), summary['net_pnl_before_unknown_swap_usd'], atol=1e-7)
        if cash.lt(0).any():
            assert np.isclose(cash.clip(lower=0).sum()/-cash.clip(upper=0).sum(), summary['profit_factor'])
        assert np.isclose(e.iloc[-1].balance_usd-cfg['initial_equity'], cash.sum(), atol=1e-7)
        m = months.loc[months.profile.eq(summary['profile'])]
        if summary['account_path_complete']:
            assert np.isclose(m.equity_change_usd.sum(), cash.sum(), atol=1e-7)
            assert m.n_entries.sum() == len(t) and e.iloc[-1].n_open == 0
        else:
            assert m.empty
        assert e.n_open.max() <= cfg['max_positions']
        assert (t.entry_time < 1767225600).all()
        admitted = events.loc[events.status.eq('executed')].set_index('candidate_id')
        for trade in t.loc[t.status.eq('closed')].to_dict('records'):
            ev = admitted.loc[trade['candidate_id']]
            assert trade['planned_risk_usd'] <= ev.target_risk_usd + 1e-8
            assert np.isclose(ev.target_risk_usd, ev.shared_equity_before_usd*cfg['risk_fraction'])
            time, priority = trade['entry_time'], order[trade['cell_id']]
            prior = t.loc[(t.entry_time.lt(time) | (t.entry_time.eq(time) & t.cell_id.map(order).lt(priority))) & t.exit_time.gt(time)]
            assert not prior.cell_id.eq(trade['cell_id']).any()
            risk = prior.planned_risk_usd.sum() + trade['planned_risk_usd']
            assert risk <= ev.shared_equity_before_usd*cfg['max_open_risk_fraction'] + 1e-7
            same = prior.loc[prior.symbol.eq(trade['symbol'])]
            assert same.planned_risk_usd.sum()+trade['planned_risk_usd'] <= ev.shared_equity_before_usd*cfg['max_symbol_risk_fraction']+1e-7
            if summary['mode'] == 'block_opposite':
                assert not same.side.ne(trade['side']).any()
        marks = e.loc[e.phase.eq('post_entry')]
        assert marks.margin_used_usd.le(marks.equity_close_usd + 1e-7).all()
    exact = False
    if replay:
        bars,candidates,specs,ex,config,_ = load_inputs()
        start,end = int(pd.Timestamp(config['common_start']).timestamp()),config['end_exclusive_epoch']
        ex['slippage_pips_per_side'] = .2
        result = simulate_shared(bars,candidates,specs,ex,config,start=start,end=end)
        directory = out/'profiles/common_hedging_base_stop_first_lower'
        for name in ['trades','events','equity']:
            saved = pd.read_parquet(directory/f'{name}.parquet')
            pd.testing.assert_frame_equal(result[name],saved,check_exact=True)
        exact = True
    return dict(status='PASS', profiles_verified=16, original_candidate_accounting=True,
        trade_cash_pf_and_monthly_reconciled=True, rule_overlap_and_admission_risk_caps_checked=True,
        assumed_entry_margin_checked=True, source_and_output_hashes_match=True,
        primary_replay_exact=exact, holdout_2026_used=False)


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('directory',type=Path)
    parser.add_argument('--no-replay',action='store_true')
    args=parser.parse_args()
    print(json.dumps(audit(args.directory,not args.no_replay),indent=2))
