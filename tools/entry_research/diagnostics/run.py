"""Read-only consumption of the validated run; diagnostics have a separate output."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import platform
import subprocess
import time

import duckdb
import numpy as np
import pandas as pd

from .paths import classify_paths, iter_path_curves
from .timing import evaluate_timing
from .exits import barrier_scenarios
from .environment import explore_environment
from .statistics import (aggregate_curve_chunks, summarize_curves, class_summary,
                         timing_summary, summarize_barriers)


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def dump(path, value):
    Path(path).write_text(json.dumps(value, indent=2, ensure_ascii=False, default=str), encoding='utf-8')


def save(out, name, frame):
    frame.to_parquet(out / (name + '.parquet'), index=False)
    frame.to_csv(out / (name + '.csv'), index=False, encoding='utf-8-sig', float_format='%.12g')


def _read_outcomes(source, baseline=False):
    glob = 'baseline/*/outcomes_*.parquet' if baseline else 'events/outcomes_*.parquet'
    files = sorted(source.glob(glob))
    if not files:
        raise ValueError(f'Missing validated outcomes: {glob}')
    return pd.concat([pd.read_parquet(file, filters=[('horizon', '==', 10)]) for file in files], ignore_index=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', default='reports/research/entry_candidates/diagnostics_20261015')
    parser.add_argument('--config', default=str(Path(__file__).with_name('config.json')))
    parser.add_argument('--render-only', action='store_true', help='Regenerate derived report/charts from completed tables')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[3]
    out = (repo / args.output).resolve()
    new_config = json.loads(Path(args.config).read_text(encoding='utf-8'))
    source = repo / new_config['source_run']
    data_dir = repo / new_config['data_dir']
    config = {**json.loads((source / 'config.json').read_text(encoding='utf-8')), **new_config}
    if config['end_exclusive'] != 1767225600 or config['methods'] != ['ichimoku_cloud', 'kijun_bounce', 'ema_cross']:
        raise ValueError('Frozen period/methods differ from the preanalysis plan')
    if args.render_only:
        if not (out / 'status.json').exists():
            raise ValueError('No analysis exists to render')
        render(data_dir, source, out, config)
        status = json.loads((out / 'status.json').read_text(encoding='utf-8'))
        status['stage'] = 'complete'
        dump(out / 'status.json', status)
        return
    if out.exists():
        raise FileExistsError('Choose a fresh output directory; existing evidence is preserved')
    out.mkdir(parents=True)
    (out / '.gitignore').write_text('*.parquet\n*.duckdb*\ntiming_events.csv\nfigures/\nplotly.min.js\ndashboard.html\nrepresentatives/\n',encoding='utf-8')
    started = time.time()
    dump(out / 'status.json', {'stage': 'running', 'started_epoch': started})
    dump(out / 'config.json', config)
    protected_paths = sorted(p for p in (repo / 'tools/entry_research').rglob('*.py')
                             if '.venv' not in p.parts and 'diagnostics' not in p.parts)
    protected_paths += sorted((repo / 'mql/Experts').glob('*.mq5'))
    inputs = [source / f for f in ['config.json', 'manifest.json', 'candidates.parquet', 'controls.parquet', 'features.parquet']]
    inputs += [data_dir / 'M5.parquet', data_dir / 'dataset_manifest.json']
    inputs += sorted(source.glob('events/*.parquet')) + sorted(source.glob('baseline/*/outcomes_*.parquet'))
    protected = {str(p.relative_to(repo)): sha(p) for p in protected_paths + inputs}
    manifest = dict(config_sha256=sha(args.config), input_and_protected_sha256=protected,
                    git_head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip(),
                    python=platform.python_version(), seed=config['seed'],
                    discovery_years=[2024, 2025], holdout_2026_used=False,
                    preanalysis_sha256=sha(repo / 'knowledge/experiments/2026-10-15-entry-diagnostics-plan.md'))
    dump(out / 'manifest.json', manifest)
    bars = pd.read_parquet(data_dir / 'M5.parquet')
    candidates = pd.read_parquet(source / 'candidates.parquet')
    controls = pd.read_parquet(source / 'controls.parquet')
    if (bars.time >= config['end_exclusive']).any() or not candidates.year.isin([2024, 2025]).all():
        raise ValueError('2026 is locked')
    print(f'Input {len(candidates)} origins; common {int(candidates.eligible.sum())}; controls {len(controls)}', flush=True)
    classes = classify_paths(bars, candidates, config)
    save(out, 'classifications', classes)
    save(out, 'class_summary', class_summary(classes))
    base_classes = classify_paths(bars, controls, config)
    base_class_summary = base_classes.groupby(['replicate', 'method', 'side', 'class_label']).size().rename('n').reset_index()
    base_class_summary['ratio'] = base_class_summary.n / base_class_summary.groupby(['replicate', 'method', 'side']).n.transform('sum')
    save(out, 'baseline_class_summary', base_class_summary)
    print('Classification complete; calculating fixed-cohort H1..H50 curves', flush=True)
    aggregates = pd.concat([
        aggregate_curve_chunks(iter_path_curves(bars, candidates, config), 'strategy'),
        aggregate_curve_chunks(iter_path_curves(bars, controls, config), 'baseline')], ignore_index=True)
    save(out, 'curve_aggregates', aggregates)
    curves = summarize_curves(aggregates)
    save(out, 'return_curves', curves)
    costs = pd.concat([curves.assign(assumed_cost_pips=cost, expected_net_at_cost=curves.gross_pips-cost)
                       for cost in config['cost_grid_pips']], ignore_index=True)
    save(out, 'cost_sensitivity', costs)
    print('Evaluating six timing policies for every origin and every control', flush=True)
    timing = evaluate_timing(bars, candidates, config)
    save(out, 'timing_events', timing)
    baseline_timing = pd.concat([evaluate_timing(bars, frame, config)
                                for _, frame in controls.groupby('replicate', sort=True)], ignore_index=True)
    baseline_timing.to_parquet(out / 'baseline_timing_events.parquet', index=False)
    for population, frame in [('all_origins', timing), ('common50', timing.loc[timing.common_pool])]:
        save(out, 'timing_status_' + population, frame.groupby(['method', 'side', 'policy', 'status']).size().rename('n').reset_index())
    print('Timing policies complete; paired week-cluster inference', flush=True)
    summary = timing_summary(timing, baseline_timing, config)
    save(out, 'timing_summary', summary)
    print('Evaluating fixed symmetric TP/SL scenarios', flush=True)
    barriers = barrier_scenarios(bars, candidates.loc[candidates.eligible], config)
    barriers.to_parquet(out / 'barrier_events.parquet', index=False)
    base_barriers = pd.concat([barrier_scenarios(bars, frame, config)
                              for _, frame in controls.groupby('replicate', sort=True)], ignore_index=True)
    base_barriers.to_parquet(out / 'baseline_barrier_events.parquet', index=False)
    save(out, 'barrier_scenarios', summarize_barriers(barriers, base_barriers))
    print('Exploring exactly 732 reserved environment cells (20,000 week resamples)', flush=True)
    envconfig = {**config, **config['environment']}
    h10 = _read_outcomes(source)
    common_ids = candidates.loc[candidates.eligible, 'candidate_id']
    environments = explore_environment(candidates.loc[candidates.eligible], controls,
                                        h10.loc[h10.candidate_id.isin(common_ids)],
                                        _read_outcomes(source, True), envconfig)
    save(out, 'environment_cells', environments)
    con = duckdb.connect(str(out / 'diagnostics.duckdb'))
    for name in ['classifications', 'class_summary', 'return_curves', 'cost_sensitivity',
                 'timing_summary', 'environment_cells', 'barrier_scenarios']:
        frame = pd.read_parquet(out / (name + '.parquet'))
        con.register('frame', frame)
        con.execute(f'CREATE TABLE {name} AS SELECT * FROM frame')
        con.unregister('frame')
    con.close()
    after = {name: sha(repo / name) for name in protected}
    if after != protected:
        raise AssertionError('Protected source or input changed during diagnostics')
    manifest['protected_unchanged'] = True
    manifest['code_sha256'] = {str(p.relative_to(repo)): sha(p) for p in sorted(Path(__file__).parent.rglob('*.py'))}
    manifest['packages'] = json.loads(subprocess.check_output([str(repo / 'tools/entry_research/.venv/Scripts/python.exe'), '-m', 'pip', 'list', '--format=json'], text=True))
    dump(out / 'manifest.json', manifest)
    dump(out / 'status.json', dict(stage='tables_complete', elapsed_seconds=time.time()-started))
    render(data_dir, source, out, config)
    dump(out / 'status.json', dict(stage='complete', elapsed_seconds=time.time()-started))
    print(f'Completed {out}', flush=True)


def render(data_dir, source, out, config):
    from .visuals import render_visuals
    from .report import write_report
    bars = pd.read_parquet(data_dir / 'M5.parquet')
    candidates = pd.read_parquet(source / 'candidates.parquet')
    classes = pd.read_parquet(out / 'classifications.parquet')
    curves = pd.read_parquet(out / 'return_curves.parquet')
    timing = pd.read_parquet(out / 'timing_summary.parquet')
    env = pd.read_parquet(out / 'environment_cells.parquet')
    if not (out / 'figures/dashboard.html').exists():
        render_visuals(bars, candidates, classes, curves, timing, env, out / 'figures', config)
    write_report(out, config)


if __name__ == '__main__':
    main()
