"""Interpret development only and independently recount frozen study evidence."""
import argparse
import json
import math
import pickle
import numpy as np
import pandas as pd
import usdjpy_only_ml as u
import interpret_technical_ml_discovery as interp
from technical_discovery_independent_recalculation import aggregate


def interpret():
    u.check_freeze();f,o,xf,cols=u.read_data();cfg=json.loads((u.OUT/'selection.json').read_text())
    names=pd.read_csv(u.OUT/'feature_catalog.csv').feature.tolist();names=[names[i] for i in cols[cfg['variant']]]
    x=xf[:,cols[cfg['variant']]];group=o[o.distance_index.eq(cfg['geometry'])]
    wf=pd.read_csv(u.OUT/'selected_development_monthly.csv')
    native=[];pg=[];pf=[];bins=[];pdp=[];shap=[];qa=[];splits=[]
    # Selected model interpretation and distinct LightGBM diagnostic, no reselection.
    families=[cfg['family']] if cfg['family']=='LIGHTGBM' else [cfg['family'],'LIGHTGBM']
    for family in families:
        for month in u.s.MONTHS:
            sp=u.split(f,group,month);pair,_=u.s.fit_pair(family,'NET_R',x,f,group,sp['fit'])
            meta=dict(family=family,month=month,geometry=cfg['geometry'],variant=cfg['variant'],
                scope='SELECTED_FORWARD' if family==cfg['family'] else 'LIGHTGBM_ATTRIBUTION_ONLY_NOT_SELECTED')
            for side,m in pair.items():
                imp,kind=interp.native_importance(m,names)
                for n,v in zip(names,imp): native.append({**meta,'direction':side,'feature':n,'importance':v,'kind':kind})
            if family==cfg['family']:
                z=np.load(u.OUT/'predictions'/f'{u.s.task_id(family,"NET_R",cfg["variant"],int(cfg["geometry"]),month)}.npz')
                for side,key in ((1,'long_score'),(-1,'short_score')):
                    error=float(np.max(np.abs(pair[side].predict(x[sp['val']])-z[key])))
                    qa.append({**meta,'check':f'deterministic_refit_{side}','max_difference':error,'status':'PASS' if error<=1e-10 else 'FAIL'})
                cutoff=float(wf.loc[wf.month.eq(month),'threshold'].iloc[0])
                truth=interp.side_targets(f,group,sp['val'])
                base,_=interp.evaluate(pair,x[sp['val']],f.loc[sp['val']],group,cutoff,truth)
                values=sum(interp.native_importance(m,names)[0]/max(np.sum(interp.native_importance(m,names)[0]),1e-30) for m in pair.values())
                top=np.argsort(-values)
                a,b=interp.permutation_rows(pair,x[sp['val']],f.loc[sp['val']],group,cutoff,truth,base,names,top,meta)
                pg+=a;pf+=b
                # Supplement the fixed bin list with RSI percentile/activity/shock interactions.
                interp.BIN_FEATURES=list(dict.fromkeys(interp.BIN_FEATURES+[
                    n for n in names if any(k in n for k in ('rsi14_pct64','tick_volume_pct64','shock_x_ema20','m1_m5_rsi_x'))]))
                bins+=interp.feature_bins(names,x[sp['fit']],x[sp['val']],f,group,sp['val'],meta)
                pdp+=interp.partial_dependence(pair,names,x[sp['fit']],x[sp['val']],top,meta)
                splits.append(dict(month=month,fit_rows=len(sp['fit']),val_rows=len(sp['val']),
                    last_fit_t0=int(f.loc[sp['fit'],'t0_msc'].max()),boundary=sp['boundary'],
                    cluster_overlap=len(set(f.loc[sp['fit'],'market_cluster_id'])&set(f.loc[sp['val'],'market_cluster_id']))))
            if family=='LIGHTGBM':
                a,b=interp.shap_rows(pair,names,x[sp['val']],meta);shap+=a;qa+=b
            print('interpretation',family,month,flush=True)
    for rows,name in [(native,'feature_importance'),(pg,'group_permutation'),(pf,'feature_permutation'),
         (bins,'feature_bins'),(pdp,'partial_dependence'),(shap,'lightgbm_shap'),(qa,'interpretation_qa'),(splits,'selected_split_audit')]:
        u.dump(rows,name+'.csv')
    assert all(q['status']=='PASS' for q in qa)
    n=pd.DataFrame(native);n=n[n.family.eq(cfg['family'])].copy()
    n['normalized']=n.importance/n.groupby(['month','direction']).importance.transform('sum').replace(0,np.nan)
    ranked=n.groupby('feature').normalized.mean().sort_values(ascending=False).reset_index()
    ranked['interaction']=ranked.feature.map(interp.interaction)
    u.dump(ranked,'feature_ranking.csv')
    u.dump(ranked[ranked.interaction],'interaction_ranking.csv')


def recount_portfolio(a,cutoff):
    keys=[];release=-1
    for r in sorted(a.to_dict('records'),key=lambda r:(r['signal_processing_msc'],r['t0_msc'],r['episode_id'])):
        if r['score']<cutoff or r['signal_processing_msc']<=release: continue
        if r['status'] in ('TP','SL','TIME','TIMEOUT'):
            keys.append(r['episode_id']);release=r['exit_msc']
        elif r['status']=='NO_ENTRY': release=max(release,r['signal_processing_msc'],r['t0_msc']+30000)
        elif r['status']=='CENSORED': release=max(release,r['entry_msc']+900000)
        elif pd.notna(r['entry_msc']) and r['entry_msc']>0: release=max(release,r['entry_msc'])
    return keys


def bootstrap(tr,label):
    rows=[];net=tr.gross_r-.2/(tr.distance/tr.pip_size)
    for kind,ids in (('market_cluster',tr.market_cluster_id),('day',tr.t0_msc//86400000)):
        frame=pd.DataFrame({'id':ids,'r':net}).groupby('id').r.agg(['sum','count'])
        rng=np.random.default_rng(20260912);values=[]
        for _ in range(2500):
            idx=rng.integers(len(frame),size=len(frame));b=frame.iloc[idx]
            values.append(b['sum'].sum()/b['count'].sum())
        rows.append(dict(scope=label,cluster_kind=kind,clusters=len(frame),resamples=2500,
            low=np.quantile(values,.025),high=np.quantile(values,.975),mean=float(net.mean()),
            warning='SELECTION_BIAS_NOT_CORRECTED' if label=='DEVELOPMENT' else 'PREVIOUSLY_OBSERVED_PERIOD_NOT_PRISTINE_OOS'))
    return rows


def summarize(holdout=False):
    u.check_freeze();data=u.read_data();f,o,xf,cols=data
    cfg=json.loads((u.OUT/'selection.json').read_text());spec=json.loads((u.OUT/'frozen_model.json').read_text())
    qa=[];monthly=[];costs=[];strata=[];boots=[]
    def check(name,good,actual='',expected=''):
        qa.append(dict(check=name,status='PASS' if good else 'FAIL',actual=actual,expected=expected))
    check('only_usdjpy_training',f.symbol.eq('USDJPY').all() and o.symbol.eq('USDJPY').all())
    check('causal_features',not f.feature_future_count.sum() and (f.feature_max_close_msc<=f.t0_msc).all())
    check('no_duplicate_episodes',not f.episode_id.duplicated().any())
    wf=pd.read_csv(u.OUT/'selected_development_monthly.csv');dev=pd.read_csv(u.OUT/'selected_development_trades.csv')
    frames=[('DEVELOPMENT',dev)]
    if holdout: frames.append(('HOLDOUT',pd.read_csv(u.OUT/'holdout_trades.csv')))
    for label,tr in frames:
        check(label+'_only_usdjpy',tr.symbol.eq('USDJPY').all())
        check(label+'_entry_processing',(tr.entry_msc>=tr.signal_processing_msc).all())
        check(label+'_entry_source_quote',(tr.entry_msc>tr.source_quote_msc).all())
        check(label+'_exit_after_entry',(tr.exit_msc>=tr.entry_msc).all())
        check(label+'_entry_eligible',(tr.entry_msc>=tr.entry_eligible_msc).all())
        check(label+'_unique',not tr.episode_id.duplicated().any())
        recompute=aggregate(tr.to_dict('records'),.2);stats=u.s.stats(tr)
        for key in ('trades','tp','sl','timeout','total_r','expectancy_r','pf','maxdd_r'):
            check(label+'_independent_'+key,abs(recompute[key]-stats[key])<1e-7,recompute[key],stats[key])
        for month,t in tr.groupby('month'):
            monthly.append(dict(scope=label,month=month,**u.s.stats(t)))
            if label=='DEVELOPMENT':
                a=u.actions(cfg,month,data);cut=float(wf.loc[wf.month.eq(month),'threshold'].iloc[0])
            else:
                a=pd.read_csv(u.OUT/f'holdout_{month}_actions.csv');cut=spec['threshold']
            check(f'{label}_{month}_portfolio',recount_portfolio(a,cut)==t.episode_id.tolist())
        monthly.append(dict(scope=label,month='ALL',**stats))
        for c in (0,.1,.2,.4,.5,1): costs.append(dict(scope=label,cost_pips=c,**u.s.stats(tr,c)))
        tr=tr.copy();tr['week']=pd.to_datetime(tr.t0_msc,unit='ms').dt.strftime('%Y-%W')
        h=pd.to_datetime(tr.t0_msc,unit='ms').dt.hour
        tr['session']=np.select([(h<9)&(h>=8),(h>=13)&(h<17),h<9,(h>=8)&(h<17),(h>=13)&(h<22)],['OVERLAP','OVERLAP','TOKYO','LONDON','NEW_YORK'],default='OTHER')
        for dimension in ('direction','session','week'):
            for value,t in tr.groupby(dimension): strata.append(dict(scope=label,dimension=dimension,value=value,**u.s.stats(t)))
        boots+=bootstrap(tr,label)
    u.dump(monthly,'comparison_monthly.csv');u.dump(costs,'cost_sensitivity.csv');u.dump(strata,'stratified_results.csv');u.dump(boots,'bootstrap.csv')
    # Every fitting run provenance and convergence, not just selected runs.
    taskrows=[];score=[]
    for path in (u.OUT/'tasks').glob('*.json'):
        r=json.loads(path.read_text());sp=u.split(f,o[o.distance_index.eq(r['geometry'])],r['month'])
        check(path.stem+'_fit_indices',r['fit_indices']==sp['fit'].tolist())
        check(path.stem+'_converged',r['all_converged'])
        for d in r['distributions']: score.append({k:r[k] for k in ('family','variant','geometry','month')}|d)
    u.dump(score,'score_distributions.csv')
    # Frozen estimator deterministic rerun on the same Jan-Apr indices.
    group=o[o.distance_index.eq(spec['distance_index'])];x=xf[:,spec['full_feature_indices']]
    pair,_=u.s.fit_pair(cfg['family'],'NET_R',x,f,group,np.array(spec['fit_indices']))
    with (u.OUT/'frozen_model.pkl').open('rb') as fh: original=pickle.load(fh)
    for side in (1,-1):
        error=float(np.max(np.abs(pair[side].predict(x)-original[side].predict(x))))
        check(f'frozen_refit_{side}',error<1e-10,error,0)
    for row in pd.read_csv(u.OUT/'pre_source_hashes.csv').itertuples():
        check('preserved_'+row.path,u.sha(u.ROOT/row.path)==row.sha256)
    u.dump(qa,'qa_checks.csv');assert all(r['status']=='PASS' for r in qa)
    # Geometry first-touch and normalized path, side labels not a portfolio.
    geom=[]
    for (g,side),t in o[o.distance_index.isin(u.s.GEOMETRIES)&o.status.isin(u.s.core.EXECUTED)].groupby(['distance_index','direction']):
        r=dict(geometry=g,direction=side,**u.s.stats(t))
        for col in ('mfe_60','mae_60','mfe_300','mae_300','mfe_900','mae_900'):
            r[col+'_atr_median']=(t[col]/t.atr14_m5).median()
        r['distance_spread_median']=(t.distance/t.entry_spread).median()
        for status in ('TP','SL','TIME'):
            z=t[t.status.eq(status)];r[status+'_hold_seconds_median']=((z.exit_msc-z.entry_msc)/1000).median()
        geom.append(r)
    u.dump(geom,'geometry_diagnostics.csv')
    front=pd.read_csv(u.OUT/'candidate_frontier.csv');rankcols=['worst_month_ev','expectancy_r','trades'];familyrows=[];freq=[]
    for family,g in front.groupby('family'):
        for tier in (200,150,100,0):
            p=g[g.min_month_trades.ge(tier)&g.all_converged]
            if len(p): break
        familyrows.append(p.sort_values(rankcols,ascending=False).iloc[0].to_dict())
        for target in u.COUNTS:
            p=g[g.policy.isin([f'FREQUENCY_{target}',f'PERCENTILE_{target}'])]
            chosen=p.sort_values(rankcols,ascending=False).iloc[0].to_dict();freq.append(dict(target_frequency=target,**chosen))
    u.dump(familyrows,'model_family_comparison.csv');u.dump(freq,'frequency_frontier.csv')
    # Same pre-existing common model predictions; filter USDJPY before portfolio.
    prior=u.ROOT/'reports/analysis/tick_shock/technical_ml_discovery_20260911'
    common=json.loads((prior/'selection.json').read_text())['diagnostic_candidate'];cw=pd.read_csv(prior/'walk_forward.csv')
    with (prior/'dataset.pkl').open('rb') as fh: prior_data=pickle.load(fh)
    cr=[]
    for month in u.s.MONTHS:
        a=u.s.load_actions(prior,common,month,prior_data);a=a[a.symbol.eq('USDJPY')]
        p=cw[cw.month.eq(month)]
        for k in u.KEYS: p=p[p[k].eq(common[k])]
        t,_=u.s.simulate(a,float(p.threshold.iloc[0]));cr.append(dict(month=month,model='PREVIOUS_SIX_SYMBOL_MODEL_USDJPY_ONLY_PORTFOLIO',**u.s.stats(t)))
    u.dump(cr,'six_symbol_common_usdjpy_comparison.csv')
    print('QA',len(qa),'PASS; holdout=',holdout,flush=True)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('command',choices=['interpret','summarize']);p.add_argument('--holdout',action='store_true')
    a=p.parse_args();interpret() if a.command=='interpret' else summarize(a.holdout)
