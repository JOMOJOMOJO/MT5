"""Reporting and audit-only artifacts. Does not fit or select models."""
from pathlib import Path
import json,hashlib
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from analyze_normal_ready_m15 import markdown

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/qa/three_wave/ready_2024_ml'

def main():
    x=pd.read_csv(OUT/'ready_2024_ml_dataset.csv');strict=x[x.target.notna()]
    tables=['# Fixed research tables','', 'Only JOURNAL_CLEAN_REAL_TICK labels are used by models. No filter adoption.','']
    for file in ['baseline_statistics','monthly_statistics','walkforward_fold_status','walkforward_metrics','htf_group_importance','cluster_quality']:
        q=pd.read_csv(OUT/(file+'.csv'));tables.extend(['## '+file,'',markdown(q),''])
    stats=pd.read_csv(OUT/'win_loss_feature_statistics.csv');stats=stats[stats.scope.eq('JOURNAL_CLEAN_REAL_TICK')]
    focus=['wave1_bullish_fraction','wave1_bullish_body_share','wave1_mean_clv','wave1_er','wave1_max_drawdown_formation_atr',
        'wave1_strength_atr_formation','window20_upper25_fraction','h1_down_swing_vs_previous','h1_up_down_swing_ratio','m15_up_swing_vs_previous']
    tables.extend(['## Prespecified hypothesis features (82 labeled; descriptive)','',markdown(stats[stats.feature.isin(focus)].drop(columns='scope')),''])
    bins=pd.read_csv(OUT/'probability_bin_statistics.csv')
    tables.extend(['## LightGBM fixed probability bins','',markdown(bins[bins.model.eq('LIGHTGBM')]),''])
    period_rows=[]
    for name,z in [('FIT_JUL_OCT',strict[strict.month<'2024-11']),('CHECK_NOV_DEC',strict[strict.month>='2024-11'])]:
        for c in focus+['m1_wave1_efficiency']:
            w=z.loc[z.target.eq(1),c];l=z.loc[z.target.eq(0),c]
            period_rows.append(dict(period=name,feature=c,tp_n=w.count(),sl_n=l.count(),tp_mean=w.mean(),sl_mean=l.mean(),tp_median=w.median(),sl_median=l.median()))
    pd.DataFrame(period_rows).to_csv(OUT/'hypothesis_period_descriptive.csv',index=False)
    (OUT/'tables.md').write_text('\n'.join(tables),encoding='utf-8')
    # Monthly bar chart makes the coverage limit explicit.
    g=x.groupby('month').size();v=strict.groupby('month').size().reindex(g.index,fill_value=0)
    fig,ax=plt.subplots(figsize=(11,4));xx=np.arange(len(g));ax.bar(xx,g-v,label='Tick order unverified',color='#b6b6b6');ax.bar(xx,v,bottom=g-v,label='Journal-clean real tick path',color='#257bb0')
    ax.set_xticks(xx,g.index,rotation=45);ax.set(ylabel='READY candidates',title='2024 coverage: 180 candidates, 82 eligible labels');ax.legend()
    fig.tight_layout();fig.savefig(OUT/'monthly_data_coverage.png',dpi=150);plt.close(fig)
    # Select by chronological index, never by outcome.
    examples=[]
    for i in [0,len(x)//3,2*len(x)//3,len(x)-1]:
        r=x.iloc[i];cut=r.entry_msc/1000;entry_time=pd.to_datetime(r.entry_msc,unit='ms');end=mdates.date2num(entry_time)
        fig,axes=plt.subplots(2,1,figsize=(13,8))
        for ax,key,tf in [(axes[0],'m15',900),(axes[1],'h1',3600)]:
            b=pd.read_csv(OUT/'annual_2024'/f'TW_ml_bars_PERIOD_{key.upper()}.csv');b=b[(b.time+tf<=cut)&(b.available_at<=cut)].tail(48)
            t=mdates.date2num(pd.to_datetime(b.time,unit='s'));width=tf/86400*.6
            colors=np.where(b.close>=b.open,'#1b9e77','#d95f02')
            ax.vlines(t,b.low,b.high,color=colors,linewidth=.8)
            ax.bar(t,np.abs(b.close-b.open),width,bottom=np.minimum(b.close,b.open),color=colors)
            for side,color in [('high','#e69f00'),('low','#0072b2')]:
                pre=key+'_'+side+'_line_';bar=r[pre+'old_bar'];price=r[pre+'old_price'];line=r[pre+'price']
                start=max(mdates.date2num(pd.to_datetime(bar,unit='s')),t[0]);slope=(line-price)/(end-mdates.date2num(pd.to_datetime(bar,unit='s')))
                ystart=line-slope*(end-start)
                ax.plot([start,end],[ystart,line],color=color,linewidth=2,label=f'{side} pivot line')
                for anchor in ['old','new']:
                    tt=mdates.date2num(pd.to_datetime(r[pre+anchor+'_bar'],unit='s'))
                    if tt>=t[0]:ax.scatter(tt,r[pre+anchor+'_price'],c=color,s=40,zorder=5)
            ax.axhline(r[key+'_structure_high'],color='gray',linestyle=':',label='Structure high/low')
            ax.axhline(r[key+'_structure_low'],color='gray',linestyle=':')
            ax.scatter(end,r.entry,marker='*',color='red',s=160,zorder=6,label='Entry Ask')
            ax.set_title(f'{key.upper()} {r[key+"_regime"]}/{r[key+"_position"]} raw={r[key+"_raw_position"]:.3f}; line band valid={int(r[key+"_line_band_valid"])}')
            ax.xaxis.set_major_formatter(mdates.DateFormatter('%m-%d %H:%M'));ax.legend(fontsize=8,loc='best');ax.grid(alpha=.2)
        fig.suptitle(f'Entry-only context: {entry_time} server time | {r.signal_id}\nLatest two confirmed highs/lows; no future candles shown',fontsize=11)
        fig.tight_layout(rect=[0,0,1,.94]);name=f'trendline_example_{i:03d}.png';fig.savefig(OUT/name,dpi=150);plt.close(fig)
        examples.append(dict(row=i,signal_id=r.signal_id,entry_time=str(entry_time),image=name,selection='chronological_index_not_outcome'))
    pd.DataFrame(examples).to_csv(OUT/'trendline_examples.csv',index=False)
    prior=pd.read_csv(ROOT/'reports/qa/three_wave/m15_normal_ready_ema_off/known_2024q3/TW_ready_shadows.csv')
    match=x.merge(prior,on='signal_id',suffixes=('_new','_old'))
    assert len(match)==len(prior)==46
    for c in ['entry_msc','entry','sl','tp','risk']:np.testing.assert_allclose(match[c+'_new'],match[c+'_old'],atol=1e-10,rtol=0)
    # Repeat fit after fixing sklearn/LightGBM column names must not change predictions.
    p0=pd.read_csv(OUT/'predictions_before_named_frame_fix.csv');p1=pd.read_csv(OUT/'walkforward_predictions.csv')
    pd.testing.assert_frame_equal(p0,p1,check_exact=False,rtol=0,atol=1e-12)
    hashes=json.loads((OUT/'source_hashes.json').read_text())
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in hashes.items())
    shared=json.loads((ROOT/'reports/qa/three_wave/ready_failure_diagnostics/production_hashes_before.json').read_text())
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in shared.items())
    audit=dict(prior_q3_entry_sl_tp_parity=46,prediction_repeat_max_tolerance=1e-12,production_unchanged=True,
        shared_prior_baseline_hashes_unchanged=len(shared),
        labeled_parent_count=int(strict.parent_id.nunique()),labeled_count=len(strict),total_parent_count=int(x.parent_id.nunique()),
        model_feature_count=len(json.loads((OUT/'model_features.json').read_text())))
    (OUT/'final_audit.json').write_text(json.dumps(audit,indent=2))
    import numpy,pandas,sklearn,lightgbm
    (OUT/'requirements.txt').write_text('\n'.join(f'{n}=={v}' for n,v in [('numpy',numpy.__version__),('pandas',pandas.__version__),('scikit-learn',sklearn.__version__),('lightgbm',lightgbm.__version__),('matplotlib',matplotlib.__version__)])+'\n')
    print(json.dumps(audit,indent=2))

if __name__=='__main__':main()
