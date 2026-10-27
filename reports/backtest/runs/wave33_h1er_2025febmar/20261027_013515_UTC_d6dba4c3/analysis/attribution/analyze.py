"""Independent native OFF/ON trade attribution. Frozen evidence only."""
from pathlib import Path
import csv,json,math
import pandas as pd

OUT=Path(__file__).resolve().parent
BATCH=OUT.parents[1]

def read(src,suffix):
    path=next(src.glob('*'+suffix+'.csv'))
    if suffix=='daytrade':
        with path.open(encoding='utf-8-sig',newline='') as f:r=list(csv.reader(f,delimiter=';'))
        h=r[0]; assert len(h)==24
        rows=[x[:4]+[';'.join(x[4:len(x)-19])]+x[-19:] for x in r[1:]]
        assert all(len(x)==24 for x in rows)
        return pd.DataFrame(rows,columns=h)
    return pd.read_csv(path,sep=';',low_memory=False).fillna('')

def stats(g):
    r=g.net_r.astype(float); c=g.net_cash.astype(float)
    return dict(n=len(g),wins=int((r>1e-9).sum()),losses=int((r< -1e-9).sum()),winning_r=float(r[r>0].sum()),losing_r=float(r[r<0].sum()),winning_cash=float(c[c>0].sum()),losing_cash=float(c[c<0].sum()),net_r=float(r.sum()),net_cash=float(c.sum()),mean_r=float(r.mean()) if len(g) else None,pf_r=float(r[r>0].sum()/-r[r<0].sum()) if (r<0).any() else None,pf_cash=float(c[c>0].sum()/-c[c<0].sum()) if (c<0).any() else None)

def extract(arm):
    src=BATCH/arm/'source';e=read(src,'events');raw=read(src,'raw_deals');day=read(src,'daytrade');h1=read(src,'h1_efficiency')
    fills=e[e.event_type=='FILL'];exits=e[e.event_type=='EXIT']
    assert fills.setup_id.is_unique and exits.setup_id.is_unique
    assert set(fills.setup_id)==set(exits.setup_id)
    rows=[]
    for _,f in fills.iterrows():
        sid=f.setup_id;x=exits[exits.setup_id==sid].iloc[0];r=raw[raw.setup_id==sid]
        din=r[r.entry=='DEAL_ENTRY_IN'];dout=r[r.entry=='DEAL_ENTRY_OUT']
        assert len(din)>0 and len(dout)>0
        frozen=day[(day.setup_id==sid)&(day.event=='DAYTRADE_RISK_FROZEN')].iloc[0]
        cash=float(r[['profit','commission','swap','fee']].astype(float).sum().sum()); risk=float(frozen.initial_risk_money); realized=cash/risk
        assert abs(cash-float(x.execution_net_cash))<1e-7
        assert abs(risk-float(x.execution_initial_risk_money))<1e-7
        assert abs(realized-float(x.realized_r))<1e-7
        entry=float((din.volume.astype(float)*din.price.astype(float)).sum()/din.volume.astype(float).sum())
        assert abs(entry-float(f.entry_price))<1e-7
        assert abs(abs(entry-float(frozen.original_sl))-float(frozen.fixed_risk_price))<1e-7
        assert abs(din.volume.astype(float).sum()-dout.volume.astype(float).sum())<1e-7
        h=h1[h1.setup_id==sid].iloc[0]
        o=e[(e.setup_id==sid)&(e.event_type=='ORDER')].iloc[0]
        rows.append(dict(arm=arm,setup_id=sid,direction=f.direction,fill_at=f.fill_at,exit_at=x.exit_at,day=f.fill_at[:10],month=f.fill_at[:7],candidate=f.candidate_detected_at,wave1_start=f.wave1_start_time,wave1_peak=f.wave1_peak_time,entry=entry,initial_sl=float(frozen.original_sl),risk_price=float(frozen.fixed_risk_price),risk_money=risk,volume=float(din.volume.astype(float).sum()),net_cash=cash,net_r=realized,exit_reason=x.exit_reason,exit_price=float(x.exit_price),exit_msc=int(dout.time_msc.astype(float).max()),entry_msc=int(din.time_msc.astype(float).min()),mfe_r=float(day[(day.setup_id==sid)&(day.event=='DAYTRADE_POSITION_CLOSED')].iloc[-1].max_favorable_r),er=float(h.er),roundtrip=float(h.roundtrip),h1_decision=h.decision_at,h1_precedence=h.precedence,partial_out_deals=len(dout)-1,commission=float(r.commission.astype(float).sum()),swap=float(r.swap.astype(float).sum()),fee=float(r.fee.astype(float).sum()),gross_profit=float(r.profit.astype(float).sum()),signal_at=o.signal_at))
    t=pd.DataFrame(rows).sort_values('fill_at').reset_index(drop=True)
    t.to_csv(OUT/f'{arm}_trades.csv',index=False)
    return t,e,raw,day,h1

def main():
    off,eo,ro,do,ho=extract('off');on,en,rn,dn,hn=extract('on')
    common=set(off.setup_id)&set(on.setup_id);removed=off[~off.setup_id.isin(common)].copy();new=on[~on.setup_id.isin(common)].copy();retained=off[off.setup_id.isin(common)]
    # Match immutable candidate identity also: setup counters must not hide collisions.
    m=off.merge(on,on='setup_id',suffixes=('_off','_on'))
    samefields=['direction','candidate','wave1_start','wave1_peak','entry','initial_sl','risk_price','exit_msc','entry_msc','exit_reason','exit_price','er','partial_out_deals']
    diff={k:int(((m[k+'_off']-m[k+'_on']).abs()>1e-8).sum()) if pd.api.types.is_numeric_dtype(m[k+'_off']) else int((m[k+'_off']!=m[k+'_on']).sum()) for k in samefields}
    changed=m.copy()
    for k in ['net_cash','net_r','risk_money','volume']:
        changed[k+'_delta']=changed[k+'_on']-changed[k+'_off']
    changed.to_csv(OUT/'matched_trades.csv',index=False)
    removed['on_h1_outcome']='';removed['on_h1_precedence']=''
    for i,r in removed.iterrows():
        h=hn[hn.setup_id==r.setup_id]
        assert len(h)==1
        removed.loc[i,'on_h1_outcome']=h.iloc[0].outcome
        removed.loc[i,'on_h1_precedence']=h.iloc[0].precedence
    removed.to_csv(OUT/'removed_off_fills.csv',index=False);new.to_csv(OUT/'new_on_fills.csv',index=False)
    slices=[]
    for label,frame in [('off',off),('on',on),('removed',removed),('retained_off',retained),('new_on',new)]:
        for feature in ['direction','day','month','exit_reason']:
            for val,g in frame.groupby(feature):slices.append(dict(group=label,feature=feature,value=val,**stats(g)))
    pd.DataFrame(slices).to_csv(OUT/'slices.csv',index=False)
    precedence=hn.groupby(['outcome','precedence']).size().reset_index(name='n')
    precedence.to_csv(OUT/'h1_precedence.csv',index=False)
    h1skips=hn[hn.outcome=='SKIP']
    signatures=[]
    for sid in sorted(common):
        def sig(raw):
            g=raw[raw.setup_id==sid].sort_values(['time_msc','deal_ticket']);v=g.loc[g.entry=='DEAL_ENTRY_IN','volume'].astype(float).sum()
            return [(int(x.time_msc),x.entry,x.type,round(float(x.volume)/v,10),float(x.price),x.reason) for x in g.itertuples()]
        signatures.append(sig(ro)==sig(rn))
    daily=off.groupby('day').net_r.sum().rename('off_net_r').to_frame().join(on.groupby('day').net_r.sum().rename('on_net_r'),how='outer').fillna(0)
    daily['on_minus_off_r']=daily.on_net_r-daily.off_net_r
    daily['removed_off_net_r']=removed.groupby('day').net_r.sum().reindex(daily.index,fill_value=0)
    daily['new_on_net_r']=new.groupby('day').net_r.sum().reindex(daily.index,fill_value=0)
    daily['retained_delta_r']=daily.on_minus_off_r+daily.removed_off_net_r-daily.new_on_net_r
    assert all(abs(daily.retained_delta_r)<1e-8)
    daily.to_csv(OUT/'daily_effect.csv')
    effect_day=daily.loc[abs(daily.on_minus_off_r)>1e-9,'on_minus_off_r'].sort_values(ascending=False)
    result=dict(off=stats(off),on=stats(on),retained_off=stats(retained),removed=stats(removed),new=stats(new),all_closed=True,trade_match_identity='setup_id validated against immutable direction/candidate/start and executable entry',common_count=len(common),matched_field_differences=diff,retained_net_r_delta=float(changed.net_r_delta.sum()),removed_r_avoided=float(-removed.net_r.sum()),new_r=float(new.net_r.sum()),net_r_improvement=float(on.net_r.sum()-off.net_r.sum()),attribution_r_residual=float(on.net_r.sum()-off.net_r.sum()+removed.net_r.sum()-new.net_r.sum()-changed.net_r_delta.sum()),cash_remainder_retained=float(changed.net_cash_delta.sum()),risk_money_changed=int((abs(changed.risk_money_delta)>1e-8).sum()),volume_changed=int((abs(changed.volume_delta)>1e-8).sum()),h1_rows_off=len(ho),h1_rows_on=len(hn),h1_on_outcomes=hn.outcome.value_counts().to_dict(),event_counts_off=eo.event_type.value_counts().to_dict(),event_counts_on=en.event_type.value_counts().to_dict(),raw_deal_cash_off=float(ro[['profit','commission','swap','fee']].astype(float).sum().sum()),raw_deal_cash_on=float(rn[['profit','commission','swap','fee']].astype(float).sum().sum()),caveats=['Two subsequent native months with fixed preregistered threshold; only two months and not proof of a general edge.','R is frozen initial monetary risk and includes original/full position entry commission, all partial exits, swap, fee.','Dynamic lot sizes depend on equity; cash improvement is not a pure fixed-lot entry-filter effect.','H1 filter rejection count must not be equated to removed actual OFF fills: H1 gate precedes busy/weekend/volume guards.','Native H1 is observed bars over session gaps, not consecutive elapsed hours.'])
    result['retained_normalized_deal_signatures_identical']=sum(signatures)
    result['retained_normalized_deal_signatures_changed']=len(signatures)-sum(signatures)
    result['months']={mo:{'off':stats(off[off.month==mo]),'on':stats(on[on.month==mo]),'removed':stats(removed[removed.month==mo]),'new':stats(new[new.month==mo]),'retained_net_r_delta':float(changed.loc[changed.month_off==mo,'net_r_delta'].sum())} for mo in sorted(set(off.month)|set(on.month))}
    result['censored_candidates']={'off':eo.loc[eo.event_type=='TEST_END',['setup_id','entry_status','state','entry_price','reason']].to_dict(orient='records'),'on':en.loc[en.event_type=='TEST_END',['setup_id','entry_status','state','entry_price','reason']].to_dict(orient='records')}
    result['raw_deal_reason_counts']={'off':ro.reason.value_counts().to_dict(),'on':rn.reason.value_counts().to_dict()}
    result['raw_setup_id_sets_match_fills']={'off':set(ro.setup_id)==set(off.setup_id),'on':set(rn.setup_id)==set(on.setup_id)}
    result['effect_day_count']=len(effect_day)
    result['effect_positive_days']=int((effect_day>0).sum())
    result['effect_negative_days']=int((effect_day<0).sum())
    result['effect_best_day']=dict(day=effect_day.index[0],r=float(effect_day.iloc[0]))
    result['effect_worst_day']=dict(day=effect_day.index[-1],r=float(effect_day.iloc[-1]))
    result['effect_top3_absolute_days_share']=float(effect_day.abs().nlargest(3).sum()/effect_day.abs().sum())
    result['effect_leave_one_affected_day_out_min_r']=float(effect_day.sum()-effect_day.max())
    result['effect_leave_one_affected_day_out_max_r']=float(effect_day.sum()-effect_day.min())
    result['mean_r_improvement_per_actual_trade']=float(on.net_r.mean()-off.net_r.mean())
    result['cash_reduction_fraction']=float(1-on.net_cash.sum()/off.net_cash.sum())
    result['r_reduction_fraction']=float(1-on.net_r.sum()/off.net_r.sum())
    result['removed_ids_equal_h1_skip_ids_this_batch']=set(removed.setup_id)==set(h1skips.setup_id)
    result['new_branches']=[]
    for p in new.itertuples(index=False):
        fields=['event_at','event_type','reason','entry_status','state']
        prior=off[(off.direction==p.direction)&(off.fill_at<p.candidate)&(off.exit_at>p.candidate)]
        result['new_branches'].append(dict(setup_id=p.setup_id,off_candidate_events=eo.loc[(eo.setup_id==p.setup_id)&(eo.event_type.isin(['WAVE1_BREAK','SKIP'])),fields].to_dict(orient='records'),off_same_direction_position_open_at_candidate=prior.to_dict(orient='records')))
    rejected=eo[eo.event_type=='DAY_PARTIAL_REJECTED']
    result['off_partial_execution_rejections']=rejected[['event_at','setup_id','reason']].to_dict(orient='records')
    assert abs(result['attribution_r_residual'])<1e-8
    (OUT/'summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=True,indent=2))

if __name__=='__main__':main()
