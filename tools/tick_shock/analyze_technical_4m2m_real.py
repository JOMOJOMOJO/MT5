"""January-April-only model selection. This command never reads May/June outcomes."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
import pandas as pd
import analyze_technical_discovery as core
from technical_discovery_independent_recalculation import score as independent_score

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / 'reports/backtest/batches/tstech_real_202501_202506_20260910'
OUT = ROOT / 'reports/analysis/tick_shock/technical_4m2m_real'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load_months(months):
    fs, os, hashes = [], [], []
    for month in months:
        folder = BATCH / str(month)
        qa = json.loads((folder/'collection_qa.json').read_text())
        assert qa['status'] in ('PASS', 'PASS_WITH_LEGACY_WARNING')
        assert all(qa['checks'].values())
        pair = []
        for name in ('technical_features.csv', 'technical_outcomes.csv'):
            path = folder/name
            actual = sha(path)
            assert actual == qa['input_sha256'][name]
            hashes.append(dict(month=month, path=str(path.relative_to(ROOT)), sha256=actual))
            frame = core.csv(path)
            frame['episode_id'] = qa['run_id'] + ':' + frame.episode_id.astype(str)
            if 'market_cluster_id' in frame:
                frame['market_cluster_id'] = qa['run_id'] + ':' + frame.market_cluster_id.astype(str)
            pair.append(frame)
        f, o = pair
        assert not f.episode_id.duplicated().any()
        assert not o.duplicated(['episode_id', 'direction', 'distance_index']).any()
        assert not f.feature_future_count.sum()
        assert (f.feature_max_close_msc <= f.t0_msc).all()
        assert set(f.episode_id) == set(o.episode_id)
        # Months are metadata, never model predictors.
        f['month'] = month
        o['month'] = month
        o['calendar_segment'] = int(str(month)[-2:]) - 1
        fs.append(f)
        os.append(o)
    f = pd.concat(fs, ignore_index=True).sort_values(['t0_msc', 'episode_id']).reset_index(drop=True)
    return f, pd.concat(os, ignore_index=True), hashes


def select(rows):
    frame = pd.DataFrame(rows)
    aggregated = []
    for key, g in frame.groupby('candidate_id', sort=True):
        assert set(g.month) == {202503, 202504}
        row = dict(candidate_id=key, method=g.method.iloc[0], distance_index=int(g.distance_index.iloc[0]),
                   threshold=float(g.threshold.iloc[0]), min_month_trades=int(g.trades.min()),
                   worst_month_ev=float(g.expectancy_r.min()), total_r=float(g.total_r.sum()),
                   both_positive=bool((g.total_r > 0).all() and (g.pf > 1).all()),
                   top5_each_positive=bool((g.top5_removed_total_r > 0).all()),
                   concentration_ok=bool((g.max_day_profit_share < .35).all()))
        row['individual_gate'] = (row['min_month_trades'] >= 200 and row['both_positive']
                                  and row['top5_each_positive'] and row['concentration_ok'])
        aggregated.append(row)
    result = pd.DataFrame(aggregated)
    result['adjacent_positive'] = False
    for _, idx in result.groupby(['method', 'distance_index']).groups.items():
        ordered = result.loc[idx].sort_values('threshold')
        for pos, (i, row) in enumerate(ordered.iterrows()):
            neighbors = ordered.iloc[max(0, pos-1):pos+2].drop(index=i)
            result.loc[i, 'adjacent_positive'] = bool(((neighbors.min_month_trades >= 200) & neighbors.both_positive).any())
    result['candidate_gate'] = result.individual_gate & result.adjacent_positive
    pool = result[result.candidate_gate]
    decision = 'DEVELOPMENT_CANDIDATE'
    if pool.empty:
        decision = 'DIAGNOSTIC_ONLY_NO_VALIDATED_EDGE'
        pool = result[result.min_month_trades >= 200]
    if pool.empty:
        pool = result.sort_values(['min_month_trades', 'worst_month_ev', 'total_r', 'candidate_id'], ascending=[False,False,False,True])
    else:
        pool = pool.sort_values(['worst_month_ev', 'total_r', 'candidate_id'], ascending=[False, False, True])
    return result, pool.iloc[0].to_dict(), decision


def run(output):
    output.mkdir(parents=True, exist_ok=False)
    f, o, hashes = load_months((202501, 202502, 202503, 202504))
    xframe, catalog = core.feature_matrix(f.drop(columns='month'))
    assert len(xframe.columns) == 486
    x = xframe.to_numpy(float)
    core.dump_csv(hashes, output/'input_hashes.csv')
    core.dump_csv(catalog, output/'feature_catalog.csv')
    core.summarize_paths(o, output)
    print(f'train episodes={len(f)} features={x.shape[1]} outcomes={len(o)}', flush=True)
    rows, coverage = [], []
    for geometry, group in o.groupby('distance_index', sort=True):
        for method in core.METHODS:
            for month in (202503, 202504):
                boundary = int(pd.Timestamp(f'{str(month)[:4]}-{str(month)[4:]}-01', tz='UTC').timestamp()*1000)
                # Full label availability, not only the early trade exit.
                last = group.groupby('episode_id').agg(last_exit=('exit_msc','max'), last_entry=('entry_msc','max'))
                complete = (f.episode_id.map(last.last_exit).fillna(np.inf) < boundary)
                complete &= (f.episode_id.map(last.last_entry).fillna(np.inf) + 900000 < boundary)
                complete &= (f.t0_msc + 930000 < boundary)
                validation = f.index[f.month == month].to_numpy()
                valclusters = set(f.loc[validation, 'market_cluster_id'])
                train = f.index[(f.month < month) & complete & ~f.market_cluster_id.isin(valclusters)].to_numpy()
                pair = core.fit_pair(method, x, f, group, train)
                coverage.append(dict(distance_index=geometry, method=method, validation_month=month,
                                     train_episodes=len(train), validation_episodes=len(validation), fitted=pair is not None))
                if pair is None:
                    continue
                actions = core.choose_actions(group, f.loc[validation], pair[1].predict(x[validation]), pair[-1].predict(x[validation]))
                for threshold in core.THRESHOLDS:
                    trades, skips = core.portfolio(actions, threshold)
                    stats = core.profit_stats(trades)
                    rows.append(dict(candidate_id=f'g{int(geometry)}_{method}_{threshold:g}', month=month,
                                     method=method, distance_index=int(geometry), threshold=threshold, **skips, **stats))
                print(f'g{geometry} {method} validation={month} done', flush=True)
            core.dump_csv(rows, output/'inner_validation.csv')
            core.dump_csv(coverage, output/'training_coverage.csv')
    frontier, selected, decision = select(rows)
    core.dump_csv(frontier, output/'selection_frontier.csv')
    group = o[o.distance_index == selected['distance_index']]
    pair = core.fit_pair(selected['method'], x, f, group, np.arange(len(f)))
    assert pair is not None
    spec = dict(candidate_id=selected['candidate_id'], method=selected['method'], features=list(xframe.columns),
                distance_index=int(selected['distance_index']), distance_atr=float(group.distance_atr.iloc[0]),
                threshold=selected['threshold'], models={'long':pair[1].export(), 'short':pair[-1].export()},
                decision=decision, training_months=[202501,202502,202503,202504], holdout_months=[202505,202506],
                primary_extra_cost_pips=.2, actual_commission='NOT_OBSERVED', rr=1, max_hold_seconds=900)
    core.write_json(spec, output/'frozen_model.json')
    (output/'TickShockTechnicalModel.mqh').write_text(core.mql_export(spec), encoding='utf-8')
    actions = core.choose_actions(group, f, pair[1].predict(x), pair[-1].predict(x))
    trades, skips = core.portfolio(actions, spec['threshold'])
    core.dump_csv(trades, output/'fitted_training_trades.csv')
    monthly = [dict(month=m, scope='IN_SAMPLE_REFIT_NOT_SELECTION', **core.profit_stats(trades[trades.month == m])) for m in (202501,202502,202503,202504)]
    core.dump_csv(monthly, output/'fitted_training_monthly.csv')
    imps=[]
    core.importances(pair, xframe.columns, spec['distance_index'], selected['method'], imps)
    core.dump_csv(sorted(imps, key=lambda v:-v['importance']), output/'selected_feature_importance.csv')
    costs=[dict(extra_cost_pips=c, **core.profit_stats(trades,c)) for c in core.COSTS]
    core.dump_csv(costs, output/'fitted_training_cost_sensitivity.csv')
    # Independent interpreter, no training-library prediction inside the oracle.
    parity=[]
    for side, name in ((1,'long'),(-1,'short')):
        oracle=np.array([independent_score(spec['models'][name], row) for row in x])
        delta=np.abs(oracle-pair[side].predict(x))
        parity.append(dict(check='independent_json_'+name, rows=len(x), max_difference=float(delta.max()), status='PASS' if (delta <= 1e-10).all() else 'FAIL'))
    core.dump_csv(parity, output/'independent_model_parity.csv')
    assert all(v['status']=='PASS' for v in parity)
    freeze=dict(decision=decision, selected=selected, train_episodes=len(f), features=len(catalog),
                inner_rows=len(rows), candidates=len(frontier), passing_candidates=int(frontier.candidate_gate.sum()),
                fitted_stats=core.profit_stats(trades), holdout_outcomes_read=False,
                frozen_model_sha256=sha(output/'frozen_model.json'), mql_model_sha256=sha(output/'TickShockTechnicalModel.mqh'),
                script_sha256=sha(__file__), base_analyzer_sha256=sha(Path(core.__file__)),
                preregistration_sha256=sha(ROOT/'docs/research/tick_shock/technical_4m2m_real_preregistration.md'))
    core.write_json(freeze, output/'freeze_record.json')
    print(json.dumps(core.clean_json(freeze), indent=2), flush=True)


if __name__ == '__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--output',type=Path,default=OUT)
    run(p.parse_args().output)
