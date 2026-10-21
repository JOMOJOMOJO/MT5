"""Fixed-family exploratory inference with aligned calendar resampling."""
import hashlib
import numpy as np
import pandas as pd

from ..statistics import holm_adjust
from .data import stamp


def seed_for(seed, key):
    return int.from_bytes(hashlib.sha256(f'{seed}|{key}'.encode()).digest()[:8], 'little')


def random_controls(features, candidates, kind, config):
    columns = ['year'] + (['hour', 'weekday', 'vol_bucket'] if kind == 'conditional' else [])
    pool = features[features.comparison_eligible].sort_values('signal_index')
    pools = {key: sub for key, sub in pool.groupby(columns, observed=True)}
    sampled, audit = [], []
    for (method, side), group in candidates.groupby(['method', 'side'], sort=True):
        rng = np.random.default_rng(seed_for(config['seed'], f'{pool.symbol.iloc[0]}|{pool.timeframe.iloc[0]}|{method}|{side}|{kind}'))
        indices, origins, replicates = [], [], []
        for key, origin in group.sort_values('candidate_id').groupby(columns, observed=True):
            choices = pools.get(key)
            if choices is None or len(choices) < len(origin):
                raise ValueError('exact control matching unavailable; do not relax strata')
            for rep in range(config['baseline_repeats']):
                indices.append(choices.index.to_numpy()[rng.choice(len(choices), len(origin), replace=False)])
                origins.append(origin.candidate_id.to_numpy())
                replicates.append(np.full(len(origin), rep))
                audit.append({'method': method, 'side': side, 'kind': kind, 'replicate': rep,
                              'stratum': str(key), 'requested_n': len(origin), 'pool_n': len(choices), 'sampled_n': len(origin)})
        if indices:
            selected = features.loc[np.concatenate(indices)].copy()
            selected['origin_candidate_id'] = np.concatenate(origins)
            selected['method'], selected['side'] = method, side
            selected['replicate'], selected['baseline_kind'] = np.concatenate(replicates), kind
            selected['candidate_id'] = [f'{kind}_{rep}_{x}' for rep, x in zip(selected.replicate, selected.origin_candidate_id)]
            sampled.append(selected)
    if not sampled:
        empty = candidates.iloc[:0].copy()
        empty['replicate'] = pd.Series(dtype=int)
        empty['baseline_kind'] = pd.Series(dtype=str)
        return empty, pd.DataFrame(audit)
    return pd.concat(sampled, ignore_index=True), pd.DataFrame(audit)


def calendar_weights(config):
    start, end = pd.Timestamp(config['start']), pd.Timestamp(config['end'])
    first = start - pd.Timedelta(days=start.dayofweek)
    weeks = pd.date_range(first, end, freq='W-MON', inclusive='left').strftime('%Y-%m-%d')
    rng = np.random.default_rng(config['seed'])
    return weeks, rng.multinomial(len(weeks), np.full(len(weeks), 1/len(weeks)), config['bootstrap_reps'])


def distributions(strategy, controls, weeks, weights, config):
    sums, counts = [], []
    samples = [strategy]
    for kind in ['unconditional', 'conditional']:
        sub = controls[controls.baseline_kind.eq(kind)]
        samples += [sub[sub.replicate.eq(rep)] for rep in range(config['baseline_repeats'])]
    for sample in samples:
        group = sample.groupby('week').net_atr.agg(['sum', 'count']).reindex(weeks, fill_value=0)
        sums.append(group['sum'].to_numpy())
        counts.append(group['count'].to_numpy())
    with np.errstate(invalid='ignore', divide='ignore'):
        values = (weights @ np.asarray(sums).T) / (weights @ np.asarray(counts).T)
    r = config['baseline_repeats']
    return values[:, 0], values[:, 0]-values[:, 1:1+r].mean(axis=1), values[:, 0]-values[:, 1+r:].mean(axis=1)


def infer_cell(strategy, controls, weeks, weights, config):
    row = {'n': len(strategy), 'weeks': strategy.week.nunique()}
    mean = strategy.net_atr.mean()
    means = [mean] + [mean-controls[controls.baseline_kind.eq(k)].groupby('replicate').net_atr.mean().mean()
                      for k in ['unconditional', 'conditional']]
    boots = distributions(strategy, controls, weeks, weights, config)
    enough = len(strategy) >= config['minimum_candidates'] and row['weeks'] >= config['minimum_weeks']
    for name, point, dist in zip(['net', 'delta_unconditional', 'delta_conditional'], means, boots):
        good = dist[np.isfinite(dist)]
        row[name + '_atr'] = point
        row[name + '_ci_low'], row[name + '_ci_high'] = np.quantile(good, [.025, .975]) if len(good) else [np.nan, np.nan]
        row[name + '_p'] = (1+np.sum(np.abs(good-point) >= abs(point))) / (len(good)+1) if len(good) and np.isfinite(point) else np.nan
        row[name + '_valid_bootstrap'] = len(good)
    row['sample_gate'] = enough
    row['annual_gate'] = True
    for year in [2024, 2025]:
        ss, cc = strategy[strategy.year.eq(year)], controls[controls.year.eq(year)]
        net = ss.net_atr.mean()
        row[f'n_{year}'], row[f'weeks_{year}'], row[f'net_atr_{year}'] = len(ss), ss.week.nunique(), net
        stable = len(ss) >= config['minimum_candidates_per_year'] and net > 0
        for kind in ['unconditional', 'conditional']:
            diff = net-cc[cc.baseline_kind.eq(kind)].groupby('replicate').net_atr.mean().mean()
            row[f'delta_{kind}_{year}'] = diff
            stable &= diff > 0
        row['annual_gate'] &= bool(stable)
    return row


def adjust_family(frame, config):
    names = ['net', 'delta_unconditional', 'delta_conditional']
    p = frame[[n+'_p' for n in names]].to_numpy()
    adjusted = holm_adjust(p.ravel(), family_size=config['hypothesis_cells'] * 3).reshape(p.shape)
    passed = frame.sample_gate & frame.annual_gate
    for i, name in enumerate(names):
        frame[name + '_holm'] = adjusted[:, i]
        passed &= (frame[name + '_holm'] <= .05) & (frame[name + '_ci_low'] > 0)
    frame['exploratory_hypothesis_pass'] = passed
    frame['live_promotion'] = False
    return frame


def walk_forward(frame, config):
    """Actual signal->label-end intervals; past-only training with embargo."""
    rows = []
    for start, end in zip(config['walk_forward_validation_starts'], config['walk_forward_validation_ends']):
        left, right = stamp(start), stamp(end)
        past = frame.signal_time < left
        train = past & (frame.exit_time <= left - config['embargo_seconds'])
        valid = (frame.signal_time >= left) & (frame.exit_time <= right)
        for label, mask in [('train', train), ('development_validation', valid)]:
            sub = frame[mask]
            rows.append({'validation_start': start, 'validation_end': end, 'partition': label,
                         'n': len(sub), 'weeks': sub.week.nunique(), 'mean_net_atr': sub.net_atr.mean(),
                         'mean_net_pips': sub.net_pips.mean(), 'purged_or_embargoed_train_n': int((past & ~train).sum()),
                         'independent_oos': False})
    return pd.DataFrame(rows)
