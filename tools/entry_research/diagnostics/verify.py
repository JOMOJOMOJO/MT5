"""Artifact-level audit independent of module-level synthetic tests."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import duckdb
import numpy as np
import pandas as pd

from .run import sha, dump


def verify(output: Path, compare: Path | None = None):
    repo = Path(__file__).resolve().parents[3]
    config = json.loads((output / 'config.json').read_text(encoding='utf-8'))
    manifest = json.loads((output / 'manifest.json').read_text(encoding='utf-8'))
    source = repo / config['source_run']
    bars = pd.read_parquet(repo / config['data_dir'] / 'M5.parquet')
    origins = pd.read_parquet(source / 'candidates.parquet')
    control_origins = pd.read_parquet(source / 'controls.parquet')
    classes = pd.read_parquet(output / 'classifications.parquet')
    events = pd.read_parquet(output / 'timing_events.parquet')
    controls = pd.read_parquet(output / 'baseline_timing_events.parquet')
    summary = pd.read_parquet(output / 'timing_summary.parquet')
    env = pd.read_parquet(output / 'environment_cells.parquet')
    curves = pd.read_parquet(output / 'return_curves.parquet')
    checks = {}

    def require(name, value):
        checks[name] = bool(value)
        if not value:
            raise AssertionError(name)

    require('no_2026_prices', (bars.time < 1767225600).all())
    require('all_original_classifications', set(classes.candidate_id) == set(origins.candidate_id) and len(classes) == len(origins))
    require('complete_cohort_exact', set(classes.loc[classes.complete, 'candidate_id']) == set(origins.loc[origins.eligible, 'candidate_id']))
    require('six_policies_every_origin', len(events) == 6*len(origins) and events.groupby('origin_candidate_id').policy.nunique().eq(6).all())
    require('six_policies_every_control', len(controls) == 6*len(control_origins) and controls.groupby('origin_candidate_id').policy.nunique().eq(6).all())
    require('common_cohort_no_unknown_outcomes', summary.missing_n.eq(0).all() and summary.baseline_missing_n.eq(0).all())
    for label, data in [('strategy', events), ('controls', controls)]:
        filled = data.loc[data.status.eq('filled')]
        require(label+'_fill_after_confirmation', (filled.fill_time >= filled.confirmation_time).all())
        nofill = data.status.isin(['expired','unexecutable'])
        unknown = data.status.eq('data_unavailable')
        for endpoint in ['hold10', 'deadline50']:
            require(label+'_'+endpoint+'_zero_only_known_nofill', data.loc[nofill,'opp_net_'+endpoint].eq(0).all())
            require(label+'_'+endpoint+'_unknown_not_imputed', data.loc[unknown,'opp_net_'+endpoint].isna().all())
            valid = filled.loc[filled['endpoint_complete_'+endpoint]]
            start = valid.fill_index.astype(int).to_numpy()
            end = start+9 if endpoint == 'hold10' else valid.original_entry_index.astype(int).to_numpy()+49
            sign = np.where(valid.side.eq('LONG'),1.,-1.)
            expected = sign*(bars.close.to_numpy()[end]-bars.open.to_numpy()[start])/.01-1.9
            require(label+'_'+endpoint+'_independent_price_arithmetic', np.allclose(valid['net_'+endpoint], expected, atol=1e-12, rtol=0))
        fixed = filled.loc[filled.policy.str.startswith('wait')]
        require(label+'_fixed_wait_offsets', np.array_equal(fixed.wait_bars.to_numpy(), fixed.policy.str[4:].astype(int).to_numpy()))
        require(label+'_conditional_later_bar', (filled.loc[filled.policy.isin(['pullback','breakout']), 'fill_index'] > filled.loc[filled.policy.isin(['pullback','breakout']), 'confirmation_index']).all())
    require('cost_decomposition', np.allclose(summary.delta_immediate,summary.delta_gross_immediate+summary.saved_cost_per_origin,atol=1e-12))
    require('fixed_curve_cohort', curves.groupby(['method','side']).n.nunique().eq(1).all() and len(curves)==300)
    immediate = summary.loc[summary.policy.eq('immediate') & summary.endpoint.eq('hold10')].set_index(['method','side'])
    c10 = curves.loc[curves.horizon.eq(10)].set_index(['method','side']).reindex(immediate.index)
    require('curve_timing_h10_exact', np.allclose(c10.net_pips, immediate.opportunity_net, atol=1e-12))
    old = pd.read_csv(source / 'summary.csv')
    old = old.loc[old.horizon.eq(10)].set_index(['method','side']).reindex(immediate.index)
    # Column name is part of the initial research schema, inspect without guessing.
    prior_name = 'mean_net_pips'
    require('original_h10_unchanged', np.allclose(old[prior_name],immediate.opportunity_net,atol=1e-10))
    require('environment_full_reserved_family', len(env)==732 and env.groupby(['method','side']).size().eq(122).all())
    require('environment_no_unqualified_flags', (~env.exploratory_hypothesis | (env.sample_gates_pass & env.annual_positive_both & env.annual_delta_positive_both & (env.net_ci_low>0) & (env.delta_ci_low>0) & (env.p_delta_net_pips_holm<.05))).all())
    selected = pd.read_csv(output / 'figures/selection.csv')
    require('representatives_one_per_present_complete_class', len(selected)==classes.loc[classes.complete].groupby(['method','side','class_label']).ngroups and not selected.duplicated(['method','side','class_label']).any())
    from hashlib import sha256
    for row in selected.itertuples(index=False):
        group = classes.loc[classes.complete & classes.method.eq(row.method) & classes.side.eq(row.side) & classes.class_label.eq(row.class_label)]
        choice = min(group.candidate_id, key=lambda cid:sha256(f'{config["seed"]}|{cid}'.encode()).hexdigest())
        require('representative_'+row.selection_hash[:16], choice==row.candidate_id and row.post_bars==50)
    require('protected_sources_and_inputs_unchanged', all(sha(repo/name)==digest for name,digest in manifest['input_and_protected_sha256'].items()))
    con = duckdb.connect(str(output/'diagnostics.duckdb'),read_only=True)
    require('duckdb_environment_complete', con.execute('SELECT count(*) FROM environment_cells').fetchone()[0]==732)
    con.close()
    if compare:
        compared = []
        for name in ['classifications','return_curves','timing_summary','environment_cells','barrier_scenarios','timing_events']:
            current = pd.read_parquet(output/(name+'.parquet'))
            prior = pd.read_parquet(compare/(name+'.parquet'))
            # Additive explanatory columns do not alter old estimates.
            columns = [col for col in prior if col in current]
            pd.testing.assert_frame_equal(current[columns],prior[columns],check_exact=False,atol=1e-12,rtol=1e-12,check_dtype=True)
            compared.append(name)
        checks['reproduction_6_tables'] = True
    result = dict(status='PASS',checks=checks,origin_count=len(origins),common_count=int(origins.eligible.sum()),
                  strategy_timing_rows=len(events),control_timing_rows=len(controls),environment_cells=len(env),
                  holdout_2026_used=False)
    dump(output/'qa/artifact_audit.json',result)
    return result


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('output',type=Path)
    parser.add_argument('--compare',type=Path)
    args=parser.parse_args()
    (args.output/'qa').mkdir(exist_ok=True)
    result=verify(args.output,args.compare)
    print(json.dumps({k:v for k,v in result.items() if k!='checks'},ensure_ascii=False))


if __name__=='__main__':
    main()
