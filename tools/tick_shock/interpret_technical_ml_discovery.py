"""Interpret frozen development configurations without selecting new models.

Only the trusted January-April dataset cache and completed discovery outputs are
read. This does not open May/June, alter training labels, or construct an EA.
"""
from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path

import numpy as np
import pandas as pd
from threadpoolctl import threadpool_limits

import technical_ml_discovery as study


GROUPS = ('TREND', 'MOMENTUM', 'VOLATILITY', 'STRUCTURE', 'LIQUIDITY', 'INTERACTIONS')
BIN_FEATURES = [
    f'{tf}_{name}' for tf in ('m1', 'm5', 'm15') for name in
    ('ema20_price_gap_atr', 'ema20_50_gap_atr', 'rsi14_value',
     'macd_hist_atr', 'atr14_pct64', 'spread_atr', 'ema_alignment')
] + [f'{left}_{right}_alignment_product' for left, right in
     (('m1', 'm5'), ('m1', 'm15'), ('m5', 'm15'))]
KEYS = ['family', 'target', 'variant', 'geometry', 'policy']


def interaction(name):
    return '_x_' in name or bool(re.match(r'^(m1_m5|m1_m15|m5_m15)_', name))


def feature_group(name):
    if interaction(name):
        return 'INTERACTIONS'
    if 'spread' in name or 'tick_volume' in name:
        return 'LIQUIDITY'
    if any(v in name for v in ('rsi', 'macd', 'stoch', 'williams', 'cci', 'roc')):
        return 'MOMENTUM'
    if any(v in name for v in ('ema', 'sma', 'adx', '_di', 'di_', 'shock_direction')):
        return 'TREND'
    if any(v in name for v in ('realized_vol', 'bb20', '_atr7', '_atr14', '_atr28')):
        return 'VOLATILITY'
    return 'STRUCTURE'


def config_key(config):
    return '__'.join(str(config[k]) for k in KEYS)


def candidates(output):
    selection = json.loads((output/'selection.json').read_text())
    primary = selection['diagnostic_candidate']
    frontier = pd.read_csv(output/'candidate_frontier.csv')
    pool = frontier[frontier.family.eq('LIGHTGBM') & frontier.all_converged]
    eligible = pool[pool.min_month_trades.ge(200)]
    if len(eligible):
        lgb = eligible.sort_values(['worst_month_ev', 'total_r', *KEYS],
                                  ascending=[False, False, True, True, True, True, True]).iloc[0].to_dict()
    else:
        lgb = pool.sort_values(['min_month_trades', 'worst_month_ev', 'total_r', *KEYS],
                              ascending=[False, False, False, True, True, True, True, True]).iloc[0].to_dict()
    if config_key(primary) == config_key(lgb):
        return [('DIAGNOSTIC_AND_LIGHTGBM', primary)]
    return [('DIAGNOSTIC', primary), ('LIGHTGBM_INTERPRETATION_ONLY', lgb)]


def native_importance(model, names):
    if model.estimator is None:
        return np.zeros(len(names)), 'CONSTANT'
    if hasattr(model.estimator, 'booster_'):
        return model.estimator.booster_.feature_importance(importance_type='gain'), 'SPLIT_GAIN'
    if hasattr(model.estimator, 'feature_importances_'):
        return model.estimator.feature_importances_, 'IMPURITY'
    return np.abs(np.asarray(model.estimator.coef_).reshape(-1)), 'ABS_STANDARDIZED_COEFFICIENT'


def side_targets(f, group, indices):
    """Align recorded net R for evaluation only, never predictor construction."""
    result = {}
    ids = f.loc[indices, 'episode_id'].to_numpy()
    for direction in (1, -1):
        rows = group[(group.direction == direction) & group.status.isin(study.core.EXECUTED)].set_index('episode_id')
        positions = np.flatnonzero(np.isin(ids, rows.index))
        actual = rows.loc[ids[positions]]
        y = actual.gross_r.to_numpy(float) - .2/(actual.distance/actual.pip_size).to_numpy(float)
        result[direction] = positions, y
    return result


def evaluate(pair, xval, fval, group, threshold, truth):
    scores = {side: pair[side].predict(xval) for side in (1, -1)}
    actions = study.choose_actions(group, fval, scores[1], scores[-1])
    trades, skips = study.simulate(actions, threshold)
    squared = np.concatenate([(scores[side][truth[side][0]]-truth[side][1])**2 for side in (1, -1)])
    return {**study.stats(trades), **skips, 'ev_rmse': float(np.sqrt(squared.mean()))}, scores


def permutation_indices(symbols, seed):
    # Preserve symbol scale while breaking within-symbol feature/time association.
    rng = np.random.default_rng(seed)
    index = np.arange(len(symbols))
    for symbol in np.unique(symbols):
        positions = np.flatnonzero(symbols == symbol)
        index[positions] = rng.permutation(positions)
    return index


def permutation_rows(pair, xval, fval, group, threshold, truth, base,
                     names, top, metadata):
    grouped, individual = [], []
    tasks = [(name, np.array([i for i, f in enumerate(names) if feature_group(f) == name], int), True)
             for name in GROUPS]
    tasks += [(names[i], np.array([i]), False) for i in top[:12]]
    symbols = fval.symbol.to_numpy()
    for number, (name, columns, is_group) in enumerate(tasks):
        if not len(columns):
            continue
        for repeat in range(3):
            seed = study.SEED + int(metadata['month']) + repeat + number*101
            perm = permutation_indices(symbols, seed)
            changed = xval.copy()
            changed[:, columns] = xval[perm][:, columns]
            metric, _ = evaluate(pair, changed, fval, group, threshold, truth)
            row = {**metadata, 'feature_or_group': name, 'features': len(columns),
                   'repeat': repeat, 'seed': seed, 'permutation_scope': 'WITHIN_VALIDATION_MONTH_AND_SYMBOL',
                   'baseline_trades': base['trades'], 'permuted_trades': metric['trades'],
                   'baseline_total_r': base['total_r'], 'permuted_total_r': metric['total_r'],
                   'total_r_degradation': base['total_r']-metric['total_r'],
                   'baseline_ev': base['expectancy_r'], 'permuted_ev': metric['expectancy_r'],
                   'ev_degradation': base['expectancy_r']-metric['expectancy_r'],
                   'baseline_ev_rmse': base['ev_rmse'], 'permuted_ev_rmse': metric['ev_rmse'],
                   'ev_rmse_increase': metric['ev_rmse']-base['ev_rmse'],
                   'interpretation': 'CORRELATED_FEATURE_DIAGNOSTIC_NOT_CAUSAL'}
            (grouped if is_group else individual).append(row)
    return grouped, individual


def feature_bins(names, xfit, xval, f, group, indices, metadata):
    rows = []
    ids = f.loc[indices, 'episode_id'].to_numpy()
    for name in BIN_FEATURES:
        if name not in names:
            continue
        column = names.index(name)
        finite = xfit[:, column][np.isfinite(xfit[:, column])]
        if len(np.unique(finite)) < 2:
            continue
        # Outer edges stay unbounded so a new-month extreme is not discarded.
        internal = np.unique(np.quantile(finite, [.2, .4, .6, .8]))
        edges = np.r_[-np.inf, internal, np.inf]
        values = xval[:, column]
        buckets = np.searchsorted(internal, values, side='right')
        for side in (1, -1):
            labels = group[(group.direction == side) & group.status.isin(study.core.EXECUTED)].set_index('episode_id')
            mask = np.isfinite(values) & np.isin(ids, labels.index)
            for bucket in range(len(edges)-1):
                subset = mask & (buckets == bucket)
                actual = labels.loc[ids[subset]]
                if not len(actual):
                    continue
                net = actual.gross_r-.2/(actual.distance/actual.pip_size)
                rows.append({**metadata, 'feature': name, 'direction': side,
                             'bin': bucket, 'lower': edges[bucket], 'upper': edges[bucket+1],
                             'edge_fit_rows': len(finite), 'rows': len(actual),
                             'tp_first_rate': float(actual.status.eq('TP').mean()),
                             'net_win_rate': float(net.gt(0).mean()),
                             'net_expectancy_r': float(net.mean()), 'total_r': float(net.sum()),
                             'scope': 'ALL_EXECUTABLE_SIDE_LABELS_NOT_PORTFOLIO_NOT_ADOPTED_RULE'})
    return rows


def partial_dependence(pair, names, xfit, xval, top, metadata):
    rows = []
    chosen = np.linspace(0, len(xval)-1, min(256, len(xval)), dtype=int)
    for column in top[:6]:
        finite = xfit[:, column][np.isfinite(xfit[:, column])]
        if not len(finite):
            continue
        for q, value in zip((.1, .3, .5, .7, .9), np.quantile(finite, (.1, .3, .5, .7, .9))):
            changed = xval[chosen].copy()
            changed[:, column] = value
            for side in (1, -1):
                rows.append({**metadata, 'feature': names[column], 'fit_quantile': q,
                             'feature_value': value, 'direction': side, 'subsample_rows': len(chosen),
                             'mean_predicted_ev': float(pair[side].predict(changed).mean()),
                             'mean_raw_prediction': float(pair[side].raw_predict(changed).mean()),
                             'scope': 'MODEL_RESPONSE_ONLY_CORRELATED_FEATURE_COMBINATIONS_MAY_BE_UNREALISTIC'})
    return rows


def shap_rows(pair, names, xval, metadata):
    rows, checks = [], []
    chosen = np.linspace(0, len(xval)-1, min(512, len(xval)), dtype=int)
    for side in (1, -1):
        model = pair[side]
        if model.family != 'LIGHTGBM' or model.estimator is None:
            continue
        z = model.transform(xval[chosen])
        booster = model.estimator.booster_
        with threadpool_limits(limits=1):
            contributions = booster.predict(z, pred_contrib=True, num_threads=1)
            raw = booster.predict(z, raw_score=True, num_threads=1)
        error = float(np.max(np.abs(contributions.sum(axis=1)-raw)))
        checks.append({**metadata, 'direction': side, 'rows': len(chosen),
                       'max_raw_additivity_error': error, 'tolerance': 1e-9,
                       'status': 'PASS' if error <= 1e-9 else 'FAIL'})
        unit = 'NET_R' if model.target == 'NET_R' else 'LOG_ODDS_NOT_NET_R'
        for i, name in enumerate(names):
            rows.append({**metadata, 'direction': side, 'feature': name,
                         'mean_abs_shap': float(np.abs(contributions[:, i]).mean()),
                         'mean_signed_shap': float(contributions[:, i].mean()),
                         'unit': unit, 'rows': len(chosen), 'baseline_mean': float(contributions[:, -1].mean()),
                         'scope': 'NATIVE_TREE_SHAP_MODEL_ATTRIBUTION_NOT_CAUSAL'})
    return rows, checks


def ablation(pair, names, x, f, group, split, config, base, metadata):
    retained = [i for i, name in enumerate(names) if not interaction(name)]
    reduced = x[:, retained]
    newpair, _ = study.fit_pair(config['family'], config['target'], reduced, f, group, split['fit'])
    actions = {}
    for part in ('fit', 'cal', 'val'):
        ix = split[part]
        actions[part] = study.choose_actions(group, f.loc[ix], newpair[1].predict(reduced[ix]), newpair[-1].predict(reduced[ix]))
    cutoff = next(p for p in study.policies(actions['fit'], actions['cal'], split) if p['policy'] == config['policy'])
    trades, skipped = study.simulate(actions['val'], cutoff['threshold'])
    metric = study.stats(trades)
    return {**metadata, 'ablation': 'NO_INTERACTIONS_SAME_FAMILY_TARGET_GEOMETRY_POLICY',
            'original_features': len(names), 'retained_features': len(retained),
            'removed_features': len(names)-len(retained), 'recalibration_scope': 'FIT_OR_CALIBRATION_TAIL_ONLY',
            'new_threshold': cutoff['threshold'], 'new_converged': all(m.converged for m in newpair.values()),
            'baseline_trades': base['trades'], 'ablated_trades': metric['trades'],
            'baseline_ev': base['expectancy_r'], 'ablated_ev': metric['expectancy_r'],
            'baseline_total_r': base['total_r'], 'ablated_total_r': metric['total_r'],
            'ablation_total_r_change': metric['total_r']-base['total_r'],
            'baseline_pf': base['pf'], 'ablated_pf': metric['pf'], **skipped,
            'scope': 'DEVELOPMENT_DIAGNOSTIC_NO_NEW_CANDIDATE_SELECTION'}


def run(output):
    if not (output/'selection.json').is_file():
        raise FileNotFoundError('Main discovery must finish before interpretation execution')
    study.init_worker(output/'dataset.pkl')
    f, o, xf, columns = study._DATA
    assert set(f.month) == {202501, 202502, 202503, 202504}, 'Holdout data forbidden'
    catalog = pd.read_csv(output/'feature_catalog.csv')
    files = dict(native='interpretation_native_importance.csv', grouped='interpretation_group_permutation.csv',
                 individual='interpretation_feature_permutation.csv', bins='interpretation_feature_bins.csv',
                 pdp='interpretation_partial_dependence.csv', shap='interpretation_shap_importance.csv',
                 shapqa='interpretation_shap_additivity.csv', ablation='interpretation_ablation.csv',
                 qa='interpretation_qa.csv')
    result = {k: [] for k in files}
    configurations = candidates(output)
    for role, config in configurations:
        ixcols = columns[config['variant']]
        names = catalog.feature.iloc[ixcols].tolist()
        x = xf[:, ixcols]
        group = o[o.distance_index == int(config['geometry'])]
        for month in study.MONTHS:
            task = (config['family'], config['target'], config['variant'], int(config['geometry']), month)
            ident = study.task_id(*task)
            saved = json.loads((output/'tasks'/f'{ident}.json').read_text())
            policy = next(p for p in saved['rows'] if p['policy'] == config['policy'])
            split = study.split_indices(f, group, month)
            pair, _ = study.fit_pair(config['family'], config['target'], x, f, group, split['fit'])
            indices = split['val']
            xfit, xval, fval = x[split['fit']], x[indices], f.loc[indices]
            truth = side_targets(f, group, indices)
            base, scores = evaluate(pair, xval, fval, group, policy['threshold'], truth)
            metadata = dict(role=role, candidate=config_key(config), family=config['family'],
                            target=config['target'], variant=config['variant'], geometry=int(config['geometry']),
                            policy=config['policy'], threshold=policy['threshold'], month=month)
            frozen = np.load(output/'predictions'/f'{ident}.npz')
            assert np.array_equal(frozen['indices'], indices)
            score_diff = max(float(np.abs(scores[1]-frozen['long_score']).max()),
                             float(np.abs(scores[-1]-frozen['short_score']).max()))
            total_diff = abs(base['total_r']-policy['total_r'])
            passed = score_diff <= 1e-9 and base['trades'] == policy['trades'] and total_diff <= 1e-8
            result['qa'].append({**metadata, 'check': 'FROZEN_REFIT_SCORE_AND_PORTFOLIO_PARITY',
                                 'score_max_diff': score_diff, 'total_r_diff': total_diff,
                                 'recorded_trades': policy['trades'], 'replayed_trades': base['trades'],
                                 'status': 'PASS' if passed else 'FAIL'})
            if not passed:
                study.dump(result['qa'], output/files['qa'])
                raise AssertionError(f'Frozen interpretation refit parity failed: {ident}')
            weight = np.zeros(len(names))
            for side in (1, -1):
                values, kind = native_importance(pair[side], names)
                normalized = values/values.sum() if values.sum() else values
                weight += normalized
                result['native'].extend({**metadata, 'direction': side, 'feature': name,
                                         'feature_group': feature_group(name), 'importance': float(values[i]),
                                         'normalized_importance': float(normalized[i]), 'kind': kind}
                                        for i, name in enumerate(names))
            top = np.argsort(-weight, kind='stable')
            grouped, individual = permutation_rows(pair, xval, fval, group, policy['threshold'], truth, base, names, top, metadata)
            result['grouped'].extend(grouped); result['individual'].extend(individual)
            result['bins'].extend(feature_bins(names, xfit, xval, f, group, indices, metadata))
            result['pdp'].extend(partial_dependence(pair, names, xfit, xval, top, metadata))
            values, checks = shap_rows(pair, names, xval, metadata)
            result['shap'].extend(values); result['shapqa'].extend(checks)
            result['ablation'].append(ablation(pair, names, x, f, group, split, config, base, metadata))
            for key, path in files.items():
                if result[key]:
                    study.dump(result[key], output/path)
            print(f'Interpretation complete {role} {month}', flush=True)
    assert all(row['status'] == 'PASS' for row in result['shapqa'])
    study.write_json(dict(status='COMPLETE', analyzed_months=[202501, 202502, 202503, 202504],
                          holdout_outcomes_read=False, candidate_selection_changed=False,
                          configurations=[dict(role=role, **config) for role, config in configurations],
                          source_sha256=study.sha(__file__), main_source_sha256=study.sha(study.__file__),
                          permutation_repeats=3, permutation_scope='WITHIN_VALIDATION_MONTH_AND_SYMBOL',
                          pdp_scope='MODEL_RESPONSE_NOT_CAUSAL_OR_COUNTERFACTUAL_PROFIT',
                          ablation_scope='PAST_ONLY_RECALIBRATION_SAME_POLICY_NO_MODEL_SELECTION',
                          shap_scope='RAW_MODEL_NET_R_OR_CLASSIFIER_LOG_ODDS',
                          artifacts={path: len(result[key]) for key, path in files.items()}),
                     output/'interpretation_metadata.json')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=study.OUT)
    args = parser.parse_args()
    run(args.output)
