"""Independent delivery checks; never mutates original research artifacts."""
import hashlib
import json
import re
from pathlib import Path
from xml.etree import ElementTree

import duckdb
import numpy as np
import pandas as pd

OUT = Path('reports/research/positive_pf_20261017/reviewed')
manifest = json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

for key in ['inputs_sha256', 'source_hashes']:
    for path, expected in manifest[key].items():
        assert sha(path) == expected, path
for path, expected in json.loads((OUT/'output_hashes.json').read_text()).items():
    assert sha(OUT/path) == expected, path

links = re.findall(r'\]\(([^)]+)\)', (OUT/'report.md').read_text(encoding='utf-8'))
assert all((OUT/link).exists() for link in links if not link.startswith('http'))
tables = {path.stem: pd.read_parquet(path) for path in OUT.glob('*.parquet')}
with duckdb.connect(str(OUT/'review.duckdb'), read_only=True) as db:
    for name, frame in tables.items():
        assert db.execute(f'SELECT count(*) FROM "{name}"').fetchone()[0] == len(frame)
        assert len(pd.read_csv(OUT/f'{name}.csv')) == len(frame)
        # Reporting-only edits must not change numerical outputs.
        old = pd.read_parquet(OUT.parent/'validated'/f'{name}.parquet')
        pd.testing.assert_frame_equal(frame, old)

# Recompute the primary block CI using direct sampled weekly arrays, rather
# than the production count-weight matrix implementation.
weeks = pd.date_range('2024-01-01', '2025-12-29', freq='W-MON', tz='UTC')
rng = np.random.default_rng(20261017+4)
starts = rng.integers(105, size=(20000, 27))
indices = np.concatenate([(starts[:, i, None]+np.arange(4)) % 105 for i in range(27)], axis=1)[:, :105]
independent_ci_checks = 0
for side in ['LONG', 'SHORT']:
    ledger = pd.read_parquet(Path(manifest['source'])/f'USDJPY/H1/atr_breakout_{side}/execution_trades.parquet')
    for scenario, group in ledger.groupby('scenario'):
        dt = pd.to_datetime(group.entry_time, unit='s', utc=True)
        labels = dt.dt.normalize()-pd.to_timedelta(dt.dt.dayofweek, unit='D')
        cash = group.net_pnl_before_unknown_swap_usd.to_numpy()
        arr = pd.DataFrame({'week': labels.to_numpy(), 'n': 1, 'r': group.result_r.to_numpy(),
                            'gain': np.maximum(cash, 0), 'loss': np.maximum(-cash, 0)})
        weekly = arr.groupby('week').sum().reindex(weeks, fill_value=0).to_numpy()
        draws = weekly[indices].sum(axis=1)
        r, pf = draws[:, 1]/draws[:, 0], draws[:, 2]/draws[:, 3]
        saved = tables['bootstrap'].loc[lambda x: x.side.eq(side) & x.scenario.eq(scenario) & x.block_weeks.eq(4)].iloc[0]
        for name, distribution in [('mean_r', r), ('pf', pf)]:
            np.testing.assert_allclose(np.quantile(distribution, [.025, .975]),
                                       [saved[name+'_ci_low'], saved[name+'_ci_high']], rtol=0, atol=1e-10)
            independent_ci_checks += 1
        cost = tables['break_even'].loc[lambda x: x.side.eq(side) & x.scenario.eq(scenario)].iloc[0]
        fee_pips = cash.sum()/sum(float(t.volume)*100000*.01*float(t.exit_conversion_quote_to_usd) for t in group.itertuples())
        assert np.isclose(fee_pips, cost.extra_roundtrip_pips_to_zero, rtol=0, atol=1e-10)

assert len(tables['positive_inventory']) == 12
assert len(tables['scenario_pairs']) == 20
assert len(tables['intrabar']) == 10
assert tables['intrabar'].complete_m1_path.all()
assert tables['intrabar'].h1_bid_ohlc_match.all()
assert not tables['intrabar'].tick_sequence_verified.any()
assert tables['summary'].all_in_net_pnl_usd.isna().all()
assert not manifest['holdout_2026_used']
suite = ElementTree.parse(OUT.parent/'qa/pytest.xml').getroot()
tests = sum(int(x.get('tests', 0)) for x in suite.iter('testsuite'))
errors = sum(int(x.get('errors', 0))+int(x.get('failures', 0)) for x in suite.iter('testsuite'))
assert tests == 15 and errors == 0
result = dict(status='PASS', source_and_output_hashes_match=True, existing_data_unchanged=True,
              csv_parquet_duckdb_table_counts_match=len(tables), report_links_checked=len(links),
              independent_bootstrap_ci_checks=independent_ci_checks,
              independent_cost_break_even_checks=4, table_equality_across_reporting_revisions=True,
              tests=tests, failures_or_errors=errors, holdout_2026_used=False)
(OUT.parent/'qa/delivery.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
print(json.dumps(result, indent=2))
