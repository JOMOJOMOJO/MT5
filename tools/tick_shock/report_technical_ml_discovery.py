"""Reporting and independent accounting for the frozen technical ML experiment.

Consumes January--April cached data and complete expanding-fold predictions.
Never fits a model, reads May/June outcomes, selects a holdout threshold, edits
MT5 code or claims that selected development performance is unbiased OOS.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import pickle

import numpy as np
import pandas as pd

import technical_ml_discovery as ml

ROOT = Path(__file__).resolve().parents[2]
PRIMARY_COST = .2
COSTS = (0., .1, .2, .5, 1.)
KEYS = ['family', 'target', 'variant', 'geometry', 'policy']
EXECUTED = {'TP', 'SL', 'TIME', 'TIMEOUT'}
SELECTION_NOTE = 'BEST_ON_SAME_DEVELOPMENT_FOLDS_NOT_UNBIASED_OOS'


def save(frame, path):
    pd.DataFrame(frame).to_csv(path, index=False, float_format='%.14g', lineterminator='\n')


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def independent_accounting(trades, cost=PRIMARY_COST):
    """Recalculate trade accounting directly, without the analyzer stats helper."""
    if trades.empty:
        return dict(trades=0, total_r=0., expectancy_r=math.nan, pf=math.nan,
                    maxdd_r=0., win_rate=math.nan, total_pips=0.,
                    expectancy_pips=math.nan, gross_expectancy_r=math.nan,
                    tp=0, sl=0, timeout=0, long=0, short=0,
                    average_win_r=math.nan, average_loss_r=math.nan,
                    top5_removed_total_r=0., longest_losing_streak=0)
    values, pip_values = [], []
    equity = peak = maxdd = 0.
    streak = longest = 0
    for row in trades.itertuples():
        risk_pips = float(row.distance) / float(row.pip_size)
        if not math.isfinite(risk_pips) or risk_pips <= 0:
            raise ValueError('Invalid recorded initial risk')
        net = float(row.gross_r) - cost / risk_pips
        values.append(net)
        pip_values.append(float(row.gross_pips) - cost)
        equity += net
        peak = max(peak, equity)
        maxdd = max(maxdd, peak - equity)
        streak = streak + 1 if net < 0 else 0
        longest = max(longest, streak)
    wins = [value for value in values if value > 0]
    losses = [value for value in values if value < 0]
    positive, negative = sum(wins), -sum(losses)
    return dict(trades=len(values), total_r=sum(values), expectancy_r=sum(values)/len(values),
                pf=positive/negative if negative else (math.inf if positive else math.nan),
                maxdd_r=maxdd, win_rate=len(wins)/len(values), total_pips=sum(pip_values),
                expectancy_pips=sum(pip_values)/len(values),
                gross_expectancy_r=float(trades.gross_r.mean()),
                tp=int((trades.status == 'TP').sum()), sl=int((trades.status == 'SL').sum()),
                timeout=int(trades.status.isin(['TIME', 'TIMEOUT']).sum()),
                long=int((trades.direction == 1).sum()), short=int((trades.direction == -1).sum()),
                average_win_r=sum(wins)/len(wins) if wins else math.nan,
                average_loss_r=sum(losses)/len(losses) if losses else math.nan,
                top5_removed_total_r=sum(values)-sum(sorted(values)[-5:]),
                longest_losing_streak=longest)


def independent_portfolio_keys(actions, threshold):
    """Separate, row-oriented reservation audit; invalid outcomes never change side."""
    records = actions.to_dict('records')
    records.sort(key=lambda r: (r['signal_processing_msc'], r['t0_msc'], r['episode_id']))
    released = -1
    accepted = []
    for row in records:
        if not math.isfinite(float(row['score'])) or row['score'] < threshold:
            continue
        if row['signal_processing_msc'] <= released:
            continue
        status = row['status']
        if status in EXECUTED:
            accepted.append((row['episode_id'], int(row['direction'])))
            released = row['exit_msc']
        elif status == 'NO_ENTRY':
            released = max(released, row['signal_processing_msc'], row['t0_msc']+30000)
        elif status == 'CENSORED':
            released = max(released, row['entry_msc']+900000)
        elif math.isfinite(float(row['entry_msc'])) and row['entry_msc'] > 0:
            released = max(released, row['entry_msc'])
    return accepted


def session_label(time_msc):
    # Naive broker-server clock. Deliberately no unsupported UTC/DST inference.
    hour = (int(time_msc) // 3600000) % 24
    open_sessions = []
    if 0 <= hour < 9:
        open_sessions.append('TOKYO')
    if 8 <= hour < 17:
        open_sessions.append('LONDON')
    if 13 <= hour < 22:
        open_sessions.append('NEW_YORK')
    return 'OVERLAP' if len(open_sessions) > 1 else (open_sessions[0] if open_sessions else 'OTHER')


def enrich(trades):
    trades = trades.copy()
    time = pd.to_datetime(trades.t0_msc, unit='ms')
    trades['server_day'] = time.dt.strftime('%Y-%m-%d')
    trades['server_week'] = time.dt.to_period('W-SUN').astype(str)
    trades['server_session'] = trades.t0_msc.map(session_label)
    trades['side'] = trades.direction.map({1:'LONG', -1:'SHORT'})
    trades['primary_extra_cost_pips'] = PRIMARY_COST
    trades['risk_pips'] = trades.distance / trades.pip_size
    trades['net_r'] = trades.gross_r - PRIMARY_COST / trades.risk_pips
    trades['net_pips'] = trades.gross_pips - PRIMARY_COST
    trades['hold_seconds'] = (trades.exit_msc-trades.entry_msc)/1000
    trades['accounting_basis'] = 'QUOTE_SIDE_GROSS_MINUS_HYPOTHETICAL_EXTRA_COST'
    return trades


def match(frame, config):
    mask = pd.Series(True, index=frame.index)
    for key in KEYS:
        mask &= frame[key] == config[key]
    return frame[mask].sort_values('month')


def best_by(frontier, column):
    records = []
    for value, group in frontier.groupby(column, sort=True):
        qualified = group[group.min_month_trades >= 200]
        pool = qualified if len(qualified) else group
        best = pool.sort_values(['worst_month_ev', 'total_r', *KEYS],
                                ascending=[False, False, True, True, True, True, True]).iloc[0].to_dict()
        best.update(comparison_dimension=column, comparison_value=value,
                    frequency_qualified_policies=len(qualified), tested_policies=len(group),
                    best_is_frequency_qualified=bool(len(qualified)),
                    development_selection_scope=SELECTION_NOTE)
        records.append(best)
    return records


def bootstrap(trades, iterations=2500):
    records = []
    for number, grouping in enumerate(('market_cluster_id', 'server_day')):
        aggregates = trades.groupby(grouping).net_r.agg(['sum', 'count'])
        sums = aggregates['sum'].to_numpy(float)
        counts = aggregates['count'].to_numpy(float)
        rng = np.random.default_rng(20260911 + number)
        samples = np.empty(iterations)
        for index in range(iterations):
            draw = rng.integers(0, len(aggregates), size=len(aggregates))
            samples[index] = sums[draw].sum()/counts[draw].sum()
        records.append(dict(grouping=grouping, groups=len(aggregates), trades=len(trades),
                            iterations=iterations, seed=20260911+number,
                            expectancy_r=float(trades.net_r.mean()), ci_lower=float(np.quantile(samples,.025)),
                            ci_upper=float(np.quantile(samples,.975)), fraction_nonpositive=float((samples<=0).mean()),
                            selection_bias_adjusted=False,
                            scope='POOLED_DEVELOPMENT_SELECTED_POLICY_NOT_VALID_OOS_PROMOTION_CI',
                            dependence_limitation='CLUSTERS_NOT_ASSUMED_INDEPENDENT_ACROSS_DAY; DAYS_MAY_HAVE_SERIAL_DEPENDENCE'))
    return records


def collect_qa(output, data, config, trades, selected_rows):
    f, o, x, columns = data
    rows = []

    def check(name, passed, actual, expected, evidence):
        rows.append(dict(check=name, status='PASS' if passed else 'FAIL', actual=actual,
                         expected=expected, evidence_path=evidence))

    check('dataset_has_only_january_april', set(f.month) == {202501,202502,202503,202504}
          and set(o.month) == set(f.month), ','.join(map(str,sorted(f.month.unique()))),
          '202501,202502,202503,202504', 'dataset.pkl')
    check('episode_key_duplicates', not f.episode_id.duplicated().any(), int(f.episode_id.duplicated().sum()),0,'dataset.pkl')
    dup = o.duplicated(['episode_id','direction','distance_index'])
    check('outcome_key_duplicates', not dup.any(), int(dup.sum()),0,'dataset.pkl')
    check('future_feature_count', bool((f.feature_future_count == 0).all()),int(f.feature_future_count.sum()),0,'dataset.pkl')
    check('completed_bar_after_t0', bool((f.feature_max_close_msc <= f.t0_msc).all()),
          int((f.feature_max_close_msc > f.t0_msc).sum()),0,'dataset.pkl')
    check('source_quote_after_detection', bool((f.t0_quote_msc <= f.t0_msc).all()),
          int((f.t0_quote_msc > f.t0_msc).sum()),0,'dataset.pkl')
    check('processing_before_detection', bool((f.t0_processing_msc >= f.t0_msc).all()),
          int((f.t0_processing_msc < f.t0_msc).sum()),0,'dataset.pkl')
    check('selected_trade_duplicate', not trades.episode_id.duplicated().any(),int(trades.episode_id.duplicated().sum()),0,'diagnostic_trades.csv')
    for name, violation in (
        ('entry_before_processing', trades.entry_msc < trades.signal_processing_msc),
        ('entry_before_eligible', trades.entry_msc < trades.entry_eligible_msc),
        ('exit_before_entry', trades.exit_msc < trades.entry_msc),
        ('invalid_direction', ~trades.direction.isin([1,-1])),
        ('unexecuted_status_in_trades', ~trades.status.isin(EXECUTED)),
    ):
        check(name, not violation.any(),int(violation.sum()),0,'diagnostic_trades.csv')
    risk = trades.direction*(trades.entry_price-trades.sl)
    price_r = trades.direction*(trades.exit_price-trades.entry_price)/trades.distance
    price_pips = trades.direction*(trades.exit_price-trades.entry_price)/trades.pip_size
    entry_price = np.where(trades.direction==1,trades.entry_ask,trades.entry_bid)
    for name, actual, expected, tolerance in (
        ('recorded_risk_vs_entry_sl', risk, trades.distance, 1e-9),
        ('quote_side_entry_price', trades.entry_price, entry_price, 1e-9),
        ('gross_r_reconstructed_from_prices', price_r, trades.gross_r, 2e-7),
        ('gross_pips_reconstructed_from_prices', price_pips, trades.gross_pips, 2e-7),
    ):
        error=float(np.max(np.abs(np.asarray(actual)-np.asarray(expected)))) if len(trades) else 0.
        check(name,error <= tolerance,error,f'<= {tolerance}','diagnostic_trades.csv')
    for record in selected_rows.to_dict('records'):
        month=int(record['month'])
        actions=ml.load_actions(output,config,month,data)
        part=trades[trades.month==month]
        keys=list(zip(part.episode_id,part.direction.astype(int)))
        oracle_keys=independent_portfolio_keys(actions,float(record['threshold']))
        check(f'independent_pending_portfolio_{month}',keys==oracle_keys,
              len(set(keys)^set(oracle_keys)),0,'diagnostic_trades.csv; predictions/')
        accounting=independent_accounting(part)
        for field in ('trades','total_r','expectancy_r','pf','maxdd_r','win_rate','tp','sl','timeout','total_pips'):
            actual=float(accounting[field]); expected=float(record[field])
            equal=(math.isnan(actual) and math.isnan(expected)) or actual==expected or math.isclose(actual,expected,rel_tol=1e-9,abs_tol=1e-9)
            check(f'csv_accounting_{month}_{field}',equal,actual,expected,'walk_forward.csv; diagnostic_trades.csv')
        sorted_part=part.sort_values(['signal_processing_msc','t0_msc','episode_id'],kind='stable')
        overlap=int((sorted_part.signal_processing_msc.to_numpy()[1:]<=sorted_part.exit_msc.to_numpy()[:-1]).sum())
        check(f'closed_trade_position_overlap_{month}',overlap==0,overlap,0,'diagnostic_trades.csv')
    split_details=[]
    for geometry in ml.GEOMETRIES:
        group=o[o.distance_index==geometry]
        latest=group.groupby('episode_id').agg(exit=('exit_msc','max'),entry=('entry_msc','max'))
        observed=f.episode_id.map(latest.exit).to_numpy()
        entry_end=f.episode_id.map(latest.entry).to_numpy()+900000
        horizon=np.maximum.reduce([observed,entry_end,f.t0_msc.to_numpy()+930000])
        for month in ml.MONTHS:
            split=ml.split_indices(f,group,month)
            fit,cal,val=[f.loc[split[k]] for k in ('fit','cal','val')]
            issues=(int((horizon[split['fit']]>=split['cut']).sum())+
                    int((horizon[split['cal']]>=split['boundary']).sum())+
                    len(set(fit.market_cluster_id)&set(cal.market_cluster_id))+
                    len(set(fit.market_cluster_id)&set(val.market_cluster_id))+
                    len(set(cal.market_cluster_id)&set(val.market_cluster_id))+
                    int((fit.t0_msc>=split['cut']).sum())+int((cal.t0_msc<split['cut']).sum())+
                    int((cal.t0_msc>=split['boundary']).sum())+int((val.month!=month).sum()))
            check(f'purged_cluster_split_g{geometry}_{month}',issues==0,issues,0,'dataset.pkl; split_audit.csv')
            split_details.append(dict(geometry=geometry,month=month,fit_rows=len(fit),calibration_rows=len(cal),
                                      validation_rows=len(val),cut_msc=split['cut'],boundary_msc=split['boundary'],
                                      fit_latest_horizon_msc=float(horizon[split['fit']].max()),
                                      calibration_latest_horizon_msc=float(horizon[split['cal']].max()),violations=issues))
    save(split_details,output/'independent_split_audit.csv')
    prediction_errors=0
    tasks=list((output/'tasks').glob('*.json'))
    for path in tasks:
        task=json.loads(path.read_text(encoding='utf-8'))
        family,target,variant,geometry,month=task['task']
        actual=np.load(output/'predictions'/f"{task['task_id']}.npz")['indices']
        desired=f.index[f.month==month].to_numpy()
        prediction_errors+=int(not np.array_equal(actual,desired))
    check('prediction_indices_outer_month',prediction_errors==0,prediction_errors,0,'predictions/')
    hashes=[]
    for manifest in ('input_hashes.csv','protected_source_hashes.csv'):
        for rec in pd.read_csv(output/manifest).to_dict('records'):
            path=ROOT/rec['path']
            value=sha(path) if path.is_file() else 'MISSING'
            match_hash=value.lower()==str(rec['sha256']).lower()
            hashes.append(dict(manifest=manifest,path=rec['path'],before_sha256=rec['sha256'],
                               current_sha256=value,status='PASS' if match_hash else 'FAIL'))
        relevant=[r for r in hashes if r['manifest']==manifest]
        failures=sum(r['status']=='FAIL' for r in relevant)
        check(manifest.replace('.csv','')+'_unchanged',failures==0,failures,0,manifest)
    save(hashes,output/'reporting_hash_verification.csv')
    env=json.loads((output/'environment.json').read_text(encoding='utf-8'))
    for key,path in (
        ('preregistration_sha256',ROOT/'docs/research/tick_shock/technical_ml_discovery_preregistration.md'),
        ('analysis_source_sha256',Path(ml.__file__)),
    ):
        actual=sha(path)
        check(key+'_unchanged',actual.lower()==env[key].lower(),actual,env[key],str(path.relative_to(ROOT)))
    check('environment_holdout_not_read',env['holdout_outcomes_read'] is False,
          env['holdout_outcomes_read'],False,'environment.json')
    return rows


def baseline_comparison(output,data,trades):
    f,o,_,_=data
    rows=[]
    for geometry in ml.GEOMETRIES:
        group=o[o.distance_index==geometry]
        for month in ml.MONTHS:
            features=f[f.month==month]
            direction=features.event_shock_direction.to_numpy(int)
            for name,ls,ss in (
                ('ALWAYS_LONG',np.ones(len(features)),np.zeros(len(features))),
                ('ALWAYS_SHORT',np.zeros(len(features)),np.ones(len(features))),
                ('CONTINUATION',(direction==1).astype(float),(direction==-1).astype(float)),
                ('REVERSAL',(direction==-1).astype(float),(direction==1).astype(float)),
            ):
                actions=ml.choose_actions(group,features,ls,ss)
                selected,skips=ml.simulate(actions,0.)
                rows.append(dict(geometry=geometry,distance_atr=float(group.distance_atr.iloc[0]),
                                 month=month,baseline=name,**independent_accounting(selected),**skips,
                                 scope='UNCONDITIONAL_DIRECTION_SAME_GLOBAL_ONE_POSITION; NO_ORACLE'))
    save(rows,output/'unconditional_baselines.csv')
    return pd.DataFrame(rows)


def geometry_path_diagnostics(output, outcomes):
    """Quote-path excursions are stored in price units; ATR-normalize explicitly."""
    rows=[]
    for (month,geometry,side), frame in outcomes[
        outcomes.distance_index.isin(ml.GEOMETRIES)
    ].groupby(['month','distance_index','direction'],sort=True):
        valid=frame[frame.status.isin(EXECUTED)]
        row=dict(month=month,geometry=geometry,direction=side,action_rows=len(frame),
                 executed_rows=len(valid),distance_atr=float(frame.distance_atr.iloc[0]),
                 tp_first=int((valid.status=='TP').sum()),sl_first=int((valid.status=='SL').sum()),
                 time_exit=int(valid.status.isin(['TIME','TIMEOUT']).sum()),
                 time_exit_rate=float(valid.status.isin(['TIME','TIMEOUT']).mean()),
                 scope='ALL_SIDE_ACTION_ROWS_NOT_INDEPENDENT_PORTFOLIO_TRADES')
        for horizon in (60,300,900):
            for excursion in ('mfe','mae'):
                values=(valid[f'{excursion}_{horizon}']/valid.atr14_m5).replace([np.inf,-np.inf],np.nan).dropna()
                for quantile in (.1,.5,.9):
                    row[f'{excursion}_{horizon}_atr_p{int(quantile*100)}']=float(values.quantile(quantile)) if len(values) else math.nan
        for name,values in (
            ('distance_spread',valid.distance/valid.entry_spread),
            ('distance_risk_pips',valid.distance/valid.pip_size),
            ('entry_spread_atr',valid.entry_spread/valid.atr14_m5),
            ('hold_seconds',(valid.exit_msc-valid.entry_msc)/1000),
        ):
            values=values.replace([np.inf,-np.inf],np.nan).dropna()
            for quantile in (.1,.5,.9):
                row[f'{name}_p{int(quantile*100)}']=float(values.quantile(quantile)) if len(values) else math.nan
        # Touch fields are full-path diagnostics and may follow an opposite exit.
        # Restrict timing summaries to the actual corresponding first-exit status.
        for barrier in ('TP','SL'):
            values=valid.loc[valid.status==barrier,f'{barrier.lower()}_touch_seconds'].dropna()
            values=values[values>=0]
            row[f'{barrier.lower()}_first_touch_seconds_median']=float(values.median()) if len(values) else math.nan
        rows.append(row)
    save(rows,output/'geometry_path_normalized.csv')


def markdown_table(frame,columns):
    frame=frame[columns]
    lines=['| '+' | '.join(columns)+' |','| '+' | '.join(['---']*len(columns))+' |']
    for record in frame.itertuples(index=False,name=None):
        parts=[]
        for value in record:
            if isinstance(value,(float,np.floating)):
                parts.append(f'{value:.5f}' if math.isfinite(value) else str(value))
            else:
                parts.append(str(value))
        lines.append('| '+' | '.join(parts)+' |')
    return '\n'.join(lines)


def run(output,report):
    required=('selection.json','walk_forward.csv','candidate_frontier.csv','split_audit.csv',
              'score_distributions.csv','input_hashes.csv','protected_source_hashes.csv','dataset.pkl')
    for name in required:
        if not (output/name).is_file():
            raise FileNotFoundError(f'Analysis incomplete: {output/name}')
    selection=json.loads((output/'selection.json').read_text(encoding='utf-8'))
    if selection['fold_configurations']!=540:
        raise ValueError('Report refuses incomplete model experiment; expected 540 fold configurations')
    if selection['holdout_outcomes_read']:
        raise ValueError('This report is restricted to pre-holdout development')
    with (output/'dataset.pkl').open('rb') as stream:
        data=pickle.load(stream)
    f,o,_,_=data
    if set(f.month)!={202501,202502,202503,202504} or set(o.month)!=set(f.month):
        raise ValueError('Unexpected month in local development cache')
    wf=pd.read_csv(output/'walk_forward.csv')
    frontier=pd.read_csv(output/'candidate_frontier.csv')
    config=selection['diagnostic_candidate']
    selected=match(wf,config)
    if set(selected.month)!=set(ml.MONTHS):
        raise ValueError('Diagnostic policy lacks an outer fold')
    trade_parts=[]
    for rec in selected.to_dict('records'):
        actions=ml.load_actions(output,config,rec['month'],data)
        frame=ml.simulate(actions,float(rec['threshold']))[0]
        frame['applied_threshold']=rec['threshold']
        frame['model_id']='__'.join(str(config[k]) for k in KEYS)
        trade_parts.append(frame)
    trades=enrich(pd.concat(trade_parts,ignore_index=True).sort_values(
        ['signal_processing_msc','t0_msc','episode_id'],kind='stable'))
    save(trades,output/'diagnostic_trades.csv')
    monthly=[]
    for month,frame in trades.groupby('month',sort=True):
        rec=selected[selected.month==month].iloc[0]
        monthly.append(dict(month=month,threshold=rec.threshold,target_count=rec.target_count,
                            calibration_achieved=rec.calibration_achieved,**independent_accounting(frame),
                            mean_hold_seconds=float(frame.hold_seconds.mean()),
                            max_hold_seconds=float(frame.hold_seconds.max()),
                            timeout_rate=float(frame.status.isin(['TIME','TIMEOUT']).mean())))
    monthly=pd.DataFrame(monthly)
    save(monthly,output/'diagnostic_monthly.csv')
    for grouping,name in (('symbol','symbol'),('side','side'),('server_session','session'),
                          ('server_week','week'),('server_day','day')):
        rows=[]
        grouped=trades.groupby(grouping).net_r.sum()
        positive=grouped.clip(lower=0).sum()
        for label,frame in trades.groupby(grouping,sort=True):
            values=independent_accounting(frame)
            rows.append(dict(group=label,**values,positive_group_profit_share=max(values['total_r'],0)/positive if positive else math.nan,
                             total_r_excluding_group=float(trades.net_r.sum()-frame.net_r.sum())))
        save(rows,output/f'diagnostic_{name}.csv')
    costs=[]
    for cost in COSTS:
        for month,frame in [('POOLED',trades),*list(trades.groupby('month',sort=True))]:
            costs.append(dict(month=month,extra_roundtrip_cost_pips=cost,
                              cost_source='HYPOTHETICAL_STRESS_NOT_OBSERVED_COMMISSION',
                              **independent_accounting(frame,cost)))
    save(costs,output/'diagnostic_cost_sensitivity.csv')
    top5=trades.nlargest(5,'net_r').copy()
    save(top5,output/'diagnostic_top5_profitable_trades.csv')
    without=trades.drop(top5.index)
    save([dict(scope='ALL',**independent_accounting(trades)),
          dict(scope='REMOVE_TOP_5_NET_R',**independent_accounting(without))],output/'diagnostic_top5_robustness.csv')
    for dimension,file in (('family','model_family_comparison.csv'),('target','target_comparison.csv'),
                            ('geometry','geometry_model_comparison.csv'),('variant','feature_variant_comparison.csv'),
                            ('calibration','calibration_comparison.csv')):
        save(best_by(frontier,dimension),output/file)
    frontier_rows=wf.copy()
    frontier_rows['achieved_minus_target']=frontier_rows.trades-frontier_rows.target_count
    frontier_rows['achieved_to_target_ratio']=np.where(frontier_rows.target_count>0,
                                                      frontier_rows.trades/frontier_rows.target_count,np.nan)
    frontier_rows['calibration_count_error']=frontier_rows.calibration_achieved-frontier_rows.target_count
    frontier_rows['calibration_max_meaning']='MAXIMUM_COUNT_OVER_SAMPLED_33_QUANTILES_NOT_THEORETICAL_MAXIMUM'
    frontier_rows['past_exposure_basis']='WHOLE_SERVER_WEEKDAYS_DIVIDED_BY_21.75; PARTIAL_DAY_ROUNDING_APPROXIMATION'
    save(frontier_rows,output/'frequency_expectancy_frontier.csv')
    # Pair exactly the same family/target/geometry/fold/calibration policy.
    paired_keys=['family','target','geometry','month','policy']
    metrics=['trades','expectancy_r','total_r','pf','threshold','calibration_achieved']
    paired=wf[wf.variant=='FULL486'][paired_keys+metrics].merge(
        wf[wf.variant=='SCALE_FREE'][paired_keys+metrics],on=paired_keys,
        suffixes=('_full','_scale_free'),validate='one_to_one')
    for metric in metrics:
        paired[metric+'_delta_scale_free_minus_full']=paired[metric+'_scale_free']-paired[metric+'_full']
    save(paired,output/'raw_scale_exclusion_paired.csv')
    paired_summary=[]
    for family,frame in paired.groupby('family',sort=True):
        finite=frame.expectancy_r_delta_scale_free_minus_full.replace([np.inf,-np.inf],np.nan).dropna()
        paired_summary.append(dict(family=family,paired_policy_months=len(frame),finite_ev_pairs=len(finite),
                                   mean_ev_delta=float(finite.mean()),median_ev_delta=float(finite.median()),
                                   fraction_scale_free_higher=float((finite>0).mean()),
                                   mean_count_delta=float(frame.trades_delta_scale_free_minus_full.mean()),
                                   scope='PAIRED_IDENTICAL_POLICY; REPEATED_OVERLAPPING_CELLS_NOT_INDEPENDENT'))
    save(paired_summary,output/'raw_scale_exclusion_summary.csv')
    same=wf.copy()
    for key in ('family','target','variant','geometry'):
        same=same[same[key]==config[key]]
    save(same,output/'diagnostic_threshold_stability.csv')
    distribution=pd.read_csv(output/'score_distributions.csv')
    for key in ('family','target','variant','geometry'):
        distribution=distribution[distribution[key]==config[key]]
    save(distribution,output/'diagnostic_score_distributions.csv')
    boot=bootstrap(trades) if len(trades) else []
    save(boot,output/'diagnostic_bootstrap.csv')
    baselines=baseline_comparison(output,data,trades)
    geometry_path_diagnostics(output,o)
    comparisons=[]
    for rec in monthly.to_dict('records'):
        for baseline in baselines[(baselines.month==rec['month'])&(baselines.geometry==config['geometry'])].to_dict('records'):
            comparisons.append(dict(month=rec['month'],geometry=config['geometry'],baseline=baseline['baseline'],
                                    model_trades=rec['trades'],baseline_trades=baseline['trades'],
                                    model_ev=rec['expectancy_r'],baseline_ev=baseline['expectancy_r'],
                                    ev_improvement=rec['expectancy_r']-baseline['expectancy_r'],
                                    model_total_r=rec['total_r'],baseline_total_r=baseline['total_r'],
                                    matched_frequency=False,scope='SAME_GEOMETRY_NOT_SAME_SELECTED_EPISODES'))
    save(comparisons,output/'diagnostic_vs_unconditional_baselines.csv')
    qa=collect_qa(output,data,config,trades,selected)
    save(qa,output/'qa_checks.csv')
    failures=[row for row in qa if row['status']=='FAIL']
    report.parent.mkdir(parents=True,exist_ok=True)
    family=pd.read_csv(output/'model_family_comparison.csv')
    pooled=independent_accounting(trades)
    scope='DEVELOPMENT_GATE_PASSED_PENDING_CONDITIONAL_HOLDOUT' if selection['passing_candidates'] else 'NO_DEVELOPMENT_CANDIDATE_PASSED'
    report.write_text(
        '# Tick-Shock Technical ML Discovery: analysis results\n\n'
        f"Verdict: `{scope}`. This is analysis only; **no EA was created**. "
        'No May/June outcomes were read by this experiment/report. '
        'The diagnostic policy below is selected on these same development folds and is not an unbiased OOS result.\n\n'
        '## Data and bounded experiment\n\n'
        f"January--April: {len(f):,} episodes, 486 full features / 448 scale-reduced features. "
        f"Outer evaluation: {sum(f.month.isin(ml.MONTHS)):,} February--April episodes. "
        'Six families × three targets × two feature variants × five RR1 geometries × three folds = 540 configurations; '
        f"{len(frontier):,} three-month policies. No random split or monthly retrospective top-N.\n\n"
        'The first 75% of each outer training prefix fits model parameters; its final 25% is a chronological calibration tail. '
        'Complete label horizons and market clusters are purged. The calibrated model is not refitted, preventing post-calibration score-scale changes. '
        'PERCENTILE/FREQUENCY use fitted-data scores; TAIL_FREQUENCY uses the held-back past tail. All cutoffs are fixed before each outer month.\n\n'
        'Calibration rates approximate exposure using whole server weekdays divided by 21.75; partial-boundary weekdays introduce rounding. '
        'The reported calibration maximum is the maximum over sampled 33-quantile thresholds, not a mathematical capacity bound: portfolio counts need not be monotonic in the threshold.\n\n'
        'Bid/Ask spread is already in quote-side gross outcomes. Primary net R subtracts an additional **hypothetical 0.2 pip round-trip cost**, '
        'not measured commission; spread is not subtracted twice. No live execution is validated.\n\n'
        '## Development-selected family comparison\n\n'
        'For each family, select the frequency-qualified policy with highest worst monthly EV; '
        'if none qualifies, display its diagnostic best and mark it unqualified. This is multiple-comparison-biased development selection, not six fixed OOS strategies.\n\n'
        +markdown_table(family,['family','target','variant','geometry','policy','min_month_trades','trades','worst_month_ev','expectancy_r','positive_months','best_is_frequency_qualified'])+'\n\n'
        '## Diagnostic policy and walk-forward accounting\n\n'
        f"Configuration: `{config['family']} / {config['target']} / {config['variant']} / g{config['geometry']} / {config['policy']}`. "
        f"Gate passing candidates: {selection['passing_candidates']}; basic gate: {selection['basic_gate_candidates']}; "
        f"frequency-qualified policies: {selection['frequency_qualified']}.\n\n"
        +markdown_table(monthly,['month','threshold','trades','win_rate','expectancy_r','pf','maxdd_r','tp','sl','timeout','timeout_rate'])+'\n\n'
        f"Pooled diagnostic: {pooled['trades']} trades, net EV {pooled['expectancy_r']:.6f} R, "
        f"PF {pooled['pf']:.6f}, total {pooled['total_r']:.6f} R, closed-trade max DD {pooled['maxdd_r']:.6f} R. "
        'This is unit-risk accounting, not a money-equity or simultaneous-position claim.\n\n'
        '## Required supporting analyses\n\n'
        f"All paths below are under `{output.relative_to(ROOT).as_posix()}/`.\n\n"
        '- `frequency_expectancy_frontier.csv`: all 100/200/300/500/800 target rates and absolute-threshold cells, actual monthly counts, EV and calibration error. Targets do not guarantee actual frequency.\n'
        '- `target_comparison.csv`, `prediction_quality.csv`: WIN, TP-first and continuous net-R comparisons; probability quality is separate from realized portfolio profit.\n'
        '- `raw_scale_exclusion_paired.csv`, `raw_scale_exclusion_summary.csv`: full/scale-free contrasts for the **same** family, target, geometry, month and policy. Remaining normalized features may still identify symbols.\n'
        '- `geometry_path_normalized.csv`, `path_geometry_diagnostics.csv`, `outcome_funnel.csv`, `geometry_model_comparison.csv`: MFE/MAE, first-touch timing, spread ratios and geometry/state counts. The original excursion columns are price units; the new normalized table divides by frozen ATR. Full-path finite touch times are not TP-first labels; the normalized timing table restricts to the actual TP/SL exit type. Path statistics pool action rows, not independent trades.\n'
        '- `unconditional_baselines.csv`, `diagnostic_vs_unconditional_baselines.csv`: always LONG, SHORT, continuation and reversal with identical geometry, cost and global portfolio rules. These have different counts; no oracle chooses a profitable direction.\n'
        '- `diagnostic_symbol.csv`, `diagnostic_side.csv`, `diagnostic_session.csv`, `diagnostic_week.csv`: dependence and removal diagnostics. Session bins use broker server hours: Tokyo [00,09), London [08,17), New York [13,22); multiple sessions = OVERLAP. No unsupported UTC/DST conversion.\n'
        '- `diagnostic_cost_sensitivity.csv`, `diagnostic_top5_robustness.csv`, `diagnostic_threshold_stability.csv`, `diagnostic_score_distributions.csv`: cost, concentration and threshold stability.\n'
        '- `diagnostic_bootstrap.csv`: 2,500 resamples each of market-cluster and server-day blocks. These are **not selection-bias-adjusted** confidence intervals and cannot promote a development-selected model to OOS. Days may remain serially dependent.\n'
        '- `interpretation_*` artifacts are supplied by the separately reviewed interpretation runner. Importance and partial dependence are associations, not causal trading rules.\n\n'
        '## Integrity, limitations and next gate\n\n'
        f"Independent QA: {len(qa)-len(failures)} PASS / {len(failures)} FAIL. "
        'Checks include quote-side price accounting, CSV EV/PF/DD reconciliation, independent pending-position replay, duplicate/clock checks, '
        'purged fit/calibration/evaluation boundaries, complete prediction indexes, and before/after input/protected-source hashes. '
        'This proves the stated offline accounting checks, not live fill or data-feed completeness.\n\n'
        'Retain the inherited January/April legacy-pool warning and February/March generated-tick fallback limitations; '
        'accepting technical-observer records does not convert those whole runs into globally valid real-tick evidence. '
        'These months have already been explored repeatedly; extensive feature/model/geometry comparisons increase overfitting risk.\n\n'
        'Only a preregistered gate-passing candidate may be frozen for a conditional May/June assessment. '
        'If the gate fails, do not inspect May/June to rescue a policy and do not force an EA. '
        'Previously observed May/June would be a secondary holdout, not pristine OOS. '
        'The user requested analysis first; this report does not authorize or perform EA implementation.\n',encoding='utf-8')
    manifest=[]
    for path in sorted(output.glob('*.csv')):
        if path.name=='reporting_artifact_hashes.csv':
            continue
        manifest.append(dict(path=path.relative_to(ROOT).as_posix(),sha256=sha(path)))
    manifest.extend([dict(path=report.relative_to(ROOT).as_posix(),sha256=sha(report)),
                     dict(path=Path(__file__).resolve().relative_to(ROOT).as_posix(),sha256=sha(__file__))])
    save(manifest,output/'reporting_artifact_hashes.csv')
    print(json.dumps(dict(report=str(report),diagnostic_trades=len(trades),qa_pass=len(qa)-len(failures),
                          qa_fail=len(failures),passing_candidates=selection['passing_candidates'],
                          holdout_outcomes_read=False),indent=2))
    if failures:
        raise AssertionError(f'{len(failures)} independent QA checks failed; report records the failure')


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,default=ml.OUT)
    parser.add_argument('--report',type=Path,default=ROOT/'docs/research/tick_shock/technical_ml_discovery_results.md')
    args=parser.parse_args()
    run(args.output.resolve(),args.report.resolve())


if __name__=='__main__':
    main()
