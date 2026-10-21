"""Entry-only dataset. Tester labels with unverified tick provenance remain unlabeled."""
from pathlib import Path
import hashlib,json,re
import numpy as np
import pandas as pd
from analyze_ready_failures import atr,features as old_features,seconds,div
from analyze_m15_regime_position import replay,annotate

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/qa/three_wave/ready_2024_ml'
RAW=OUT/'annual_2024'
TFS={'m1':60,'m5':300,'m15':900,'h1':3600}

def pivot(b,tf,side):
    x=b[side];left=x.shift(1).rolling(2).max() if side=='high' else x.shift(1).rolling(2).min()
    right=pd.concat([x.shift(-1),x.shift(-2)],axis=1).max(axis=1) if side=='high' else pd.concat([x.shift(-1),x.shift(-2)],axis=1).min(axis=1)
    ok=((x>left)&(x>=right)) if side=='high' else ((x<left)&(x<=right))
    ok &= x.shift(-2).notna()
    return np.column_stack([b.bar[ok],(b.bar.shift(-2)+tf)[ok],x[ok]]).astype(float)

def prepare(raw):
    d={}
    for key,tf in TFS.items():
        b=raw[key].copy();b['atr14']=atr(b,14);b['atr5']=atr(b,5)
        b['atr_median100']=b.atr14.rolling(100,min_periods=100).median()
        d[key]=b
        for side in ['high','low']:d[key+'_'+side]=pivot(b,tf,side)
        if key in ['m15','h1']:
            b['asof']=b.bar+tf
            d[key+'_states'],_=replay(b)
    d['p1low']=d['m1_low'];d['p5high']=d['m5_high'];d['p15high']=d['m15_high']
    return d

def safe_ratio(a,b):
    return float(a/b) if np.isfinite(a) and np.isfinite(b) and abs(b)>1e-12 else np.nan

def leg_measures(ph,pl,a):
    ups=[];downs=[]
    for end in ph:
        ix=np.searchsorted(pl[:,0],end[0],side='left')-1
        if ix>=0:ups.append(float(end[2]-pl[ix,2]))
    for end in pl:
        ix=np.searchsorted(ph[:,0],end[0],side='left')-1
        if ix>=0:downs.append(float(ph[ix,2]-end[2]))
    u=ups[-1] if ups else np.nan;v=downs[-1] if downs else np.nan
    ur=div(u,ups[-2]) if len(ups)>1 else np.nan;dr=div(v,downs[-2]) if len(downs)>1 else np.nan
    return dict(recent_up_swing_atr=div(u,a),recent_down_swing_atr=div(v,a),up_down_swing_ratio=div(u,v),
                up_swing_vs_previous=ur,down_swing_vs_previous=dr,
                up_expanding=float(ur>1) if np.isfinite(ur) else np.nan,
                down_contracting=float(dr<1) if np.isfinite(dr) else np.nan)

def unbroken_levels(b,p,tf,m1,cut,entry,side):
    p=p[(p[:,1]<=cut)&(p[:,0]>=b.bar.iloc[max(0,len(b)-800)])]
    pricecol='high' if side=='high' else 'low'
    reducer=np.maximum if side=='high' else np.minimum
    a=reducer.accumulate(b[pricecol].to_numpy()[::-1])[::-1]
    c=reducer.accumulate(m1[pricecol].to_numpy()[::-1])[::-1]
    levels=[]
    for bar,confirmed,price in p:
        if (side=='high' and price<=entry) or (side=='low' and price>=entry):continue
        default=-np.inf if side=='high' else np.inf
        j=np.searchsorted(b.bar,bar+tf);k=np.searchsorted(m1.bar,bar+tf)
        extreme=reducer(a[j] if j<len(a) else default,c[k] if k<len(c) else default)
        good=extreme<=price+1e-10 if side=='high' else extreme>=price-1e-10
        if good:levels.append((float(price),int(bar),int(confirmed)))
    return sorted(levels,reverse=side=='low')

def context(r,d,key,cut,m1):
    tf=TFS[key];b=d[key];b=b[(b.bar+tf<=cut)&(b.available_at<=cut)]
    a=float(b.atr14.iloc[-1]);states=d[key+'_states'];state=states[states['asof']<=b.bar.iloc[-1]+tf].iloc[-1]
    q=annotate(pd.DataFrame([{'entry_msc':r.entry_msc,'entry':r.entry,'risk':r.risk}]),pd.DataFrame([state])).iloc[0]
    ph=d[key+'_high'];pl=d[key+'_low'];ph=ph[ph[:,1]<=cut];pl=pl[pl[:,1]<=cut]
    f={key+'_regime':q.regime,key+'_position':q.position,key+'_raw_position':q.raw_position,
       key+'_range_location':q.range_location,key+'_last_break_direction':q.last_break_direction.upper(),
       key+'_minutes_since_break':q.last_break_age_minutes,key+'_break_distance_atr':div(q.last_break_level_minus_entry,a),
       key+'_atr14':a,key+'_atr_state':div(a,float(b.atr_median100.iloc[-1])),
       key+'_structure_high_distance_R':div(q.structure_high-r.entry,r.risk)}
    meta={key+'_structure_high':q.structure_high,key+'_structure_low':q.structure_low,key+'_asof':int(q['asof'])}
    for direction in ['bullish','bearish']:
        f[key+'_'+direction+'_break_age_minutes']=q[direction+'_break_age_minutes']
        f[key+'_'+direction+'_break_distance_atr']=div(q[direction+'_break_level_minus_entry'],a)
        meta[key+'_'+direction+'_break_time']=q[direction+'_break_asof']
    f.update({key+'_'+k:v for k,v in leg_measures(ph,pl,a).items()})
    for side,points in [('high',ph),('low',pl)]:
        pre=key+'_'+side+'_line_'
        f[pre+'slope_atr_per_hour']=np.nan;f[pre+'entry_distance_atr']=np.nan;f[pre+'side']='UNKNOWN'
        if len(points)>=2:
            p0,p1=points[-2:];assert max(p0[1],p1[1])<=cut
            slope=(p1[2]-p0[2])/(p1[0]-p0[0]);line=p1[2]+slope*(r.entry_msc/1000-p1[0])
            dist=r.entry-line
            f[pre+'slope_atr_per_hour']=div(slope*3600,a);f[pre+'entry_distance_atr']=div(dist,a)
            f[pre+'side']='ABOVE' if dist>1e-10 else ('BELOW' if dist<-1e-10 else 'ON')
            meta[pre+'price']=line
            for name,p in [('old',p0),('new',p1)]:
                for col,v in zip(['bar','confirmed','price'],p):meta[pre+name+'_'+col]=v
        levels=unbroken_levels(b,points,tf,m1,cut,r.entry,side)
        tag='resistance' if side=='high' else 'support'
        distance=(levels[0][0]-r.entry) if side=='high' and levels else (r.entry-levels[0][0] if levels else np.nan)
        f[key+'_nearest_'+tag+'_R']=div(distance,r.risk)
        f[key+'_nearest_'+tag+'_atr']=div(distance,a)
        if side=='high':f[key+'_pivot_count_before_tp']=sum(z[0]<r.tp for z in levels)
    upper=meta.get(key+'_high_line_price',np.nan);lower=meta.get(key+'_low_line_price',np.nan)
    f[key+'_line_band_valid']=float(np.isfinite(upper) and np.isfinite(lower) and upper>lower)
    f[key+'_line_band_position']=div(r.entry-lower,upper-lower) if f[key+'_line_band_valid'] else np.nan
    return f,meta

def extra_features(r,d):
    cut=int(r.entry_msc//1000);entry=float(r.entry);risk=float(r.risk)
    m1=d['m1'];m1=m1[(m1.bar+60<=cut)&(m1.available_at<=cut)]
    m5=d['m5'];m5=m5[(m5.bar+300<=cut)&(m5.available_at<=cut)]
    f={};meta={}
    for key in ['m15','h1']:
        g,h=context(r,d,key,cut,m1);f.update(g);meta.update(h)
    origin=seconds(r.m5_origin_time);top=seconds(r.m5_wave1_time);choch=seconds(r.m5_choch_time)
    confirmed=seconds(r.m5_wave1_confirmed);a=float(m5.atr14.iloc[-1]);width=r.m5_wave1_high-r.m5_origin
    w=m5[(m5.bar>=origin)&(m5.bar<=top)];body=w.close.to_numpy()-w.open.to_numpy();pos=body[body>0];neg=-body[body<0]
    atrc=float(m5.loc[m5.bar+300<=choch,'atr14'].iloc[-1]);atrh=float(m5.loc[m5.bar+300<=confirmed,'atr14'].iloc[-1])
    formation=float(w.atr14.median());path=np.r_[r.m5_origin,w.loc[w.bar<top,'close'].to_numpy(),r.m5_wave1_high]
    dd=float(np.max(np.maximum.accumulate(path)-path));h=w.high.to_numpy();lo=w.low.to_numpy()
    interbar=max(0,float(np.max(np.maximum.accumulate(h)[:-1]-lo[1:]))) if len(w)>1 else 0
    maximum=streak=0
    for v in body:streak=streak+1 if v<0 else 0;maximum=max(maximum,streak)
    clv=(w.close-w.low)/(w.high-w.low).replace(0,np.nan)
    mid=len(path)//2;v1=(path[mid]-path[0])/max(mid,1);v2=(path[-1]-path[mid])/max(len(path)-1-mid,1)
    cb=m5[m5.bar+300==choch].iloc[0]
    f.update(wave1_bars=len(w),wave1_bullish_body_sum=float(pos.sum()),wave1_bearish_body_sum=float(neg.sum()),
        wave1_bullish_body_share=div(pos.sum(),np.abs(body).sum()),wave1_max_drawdown_price=dd,
        wave1_max_drawdown_range=div(dd,width),wave1_max_drawdown_formation_atr=div(dd,formation),
        wave1_running_high_drawdown_atr=div(interbar,formation),wave1_max_consecutive_bearish=maximum,
        wave1_mean_bull_body=float(pos.mean()) if len(pos) else np.nan,wave1_mean_bear_body=float(neg.mean()) if len(neg) else np.nan,
        wave1_body_ratio=div(pos.mean(),neg.mean()) if len(pos) and len(neg) else np.nan,
        wave1_mean_clv=clv.mean(),wave1_high_close_fraction=float((clv>=.75).mean()),
        wave1_first_half_speed_atr=div(v1,formation),wave1_second_half_speed_atr=div(v2,formation),
        wave1_acceleration=safe_ratio(v2,v1),wave1_atr_at_choch=atrc,wave1_median_formation_atr=formation,
        wave1_atr_at_high_confirmation=atrh,wave1_strength_atr_choch=div(width,atrc),
        wave1_strength_atr_formation=div(width,formation),wave1_strength_atr_confirmation=div(width,atrh),
        wave1_choch_break_price=cb.close-r.m5_return_high,wave1_choch_body_atr=div(cb.close-cb.open,atrc))
    w2=m5[m5.bar>top];f['wave2_atr_ratio']=div(a,atrh)
    for side in ['high','low']:
        ps=d['m5_'+side];ps=ps[ps[:,1]<=cut]
        ix=[i for i in range(1,len(ps)) if ps[i,0]>top]
        f['wave2_'+('lower_high_count' if side=='high' else 'higher_low_count')]=sum((ps[i,2]<ps[i-1,2]) if side=='high' else (ps[i,2]>ps[i-1,2]) for i in ix)
    hh=w2.high.to_numpy();cc=w2.close.to_numpy()
    f['wave2_wave1_retests']=int(np.sum((hh>=r.m5_wave1_high)&(cc<=r.m5_wave1_high)))
    f['wave2_failed_high_tests']=int(np.sum((hh[1:]>=np.maximum.accumulate(hh)[:-1])&(cc[1:]<=np.maximum.accumulate(hh)[:-1]))) if len(hh)>1 else 0
    l0=seconds(r.m1_reversal_time);h1=seconds(r.m1_wave1_time);wm=m1[(m1.bar>=l0)&(m1.bar<=h1)]
    path1=np.r_[r.m1_reversal_low,wm.loc[wm.bar<h1,'close'],r.m1_wave1_high]
    wa=r.m1_wave1_high-r.m1_reversal_low
    f.update(m1_atr14=float(m1.atr14.iloc[-1]),m1_wave1_strength=div(wa,float(m1.atr14.iloc[-1])),
             m1_wave1_efficiency=div(wa,np.abs(np.diff(path1)).sum()),m1_wave2_retrace=div(r.m1_wave1_high-r.m1_wave2_low,wa))
    for n in [5,10,20]:
        end=cut//60*60;win=m1[(m1.bar>=end-n*60)&(m1.bar<end)];prev=m1[(m1.bar>=end-2*n*60)&(m1.bar<end-n*60)]
        p=f'window{n}_';keys=['net_return_atr','range_atr','realized_movement_atr','compression_ratio','bullish_fraction','higher_lows','lower_lows','higher_highs','failed_high_tests','upper25_fraction','lower25_fraction','entry_position']
        for key in keys:f[p+key]=np.nan
        meta[p+'bar_count']=len(win)
        if len(win)!=n:continue
        h=win.high.to_numpy();l=win.low.to_numpy();c=win.close.to_numpy();rng=h.max()-l.min();closes=np.r_[win.open.iloc[0],c]
        f.update({p+'net_return_atr':div(c[-1]-closes[0],a),p+'range_atr':div(rng,a),
            p+'realized_movement_atr':div(np.abs(np.diff(closes)).sum(),a),
            p+'compression_ratio':div((h-l).sum(),(prev.high-prev.low).sum()) if len(prev)==n else np.nan,
            p+'bullish_fraction':float((win.close>win.open).mean()),p+'upper25_fraction':float((c>=l.min()+.75*rng).mean()),
            p+'lower25_fraction':float((c<=l.min()+.25*rng).mean()),p+'entry_position':div(entry-l.min(),rng),
            p+'failed_high_tests':int(np.sum((h[1:]>=np.maximum.accumulate(h)[:-1])&(c[1:]<=np.maximum.accumulate(h)[:-1])))})
        for side in ['high','low']:
            ps=d['m1_'+side];ps=ps[ps[:,1]<=cut];ix=[i for i in range(1,len(ps)) if ps[i,0]>=end-n*60]
            if side=='high':f[p+'higher_highs']=sum(ps[i,2]>ps[i-1,2] for i in ix)
            else:
                f[p+'higher_lows']=sum(ps[i,2]>ps[i-1,2] for i in ix);f[p+'lower_lows']=sum(ps[i,2]<ps[i-1,2] for i in ix)
    ts=pd.to_datetime(r.entry_msc,unit='ms');hour=ts.hour+ts.minute/60
    f.update(server_hour=hour,server_day_of_week=ts.dayofweek,hour_sin=np.sin(hour*2*np.pi/24),hour_cos=np.cos(hour*2*np.pi/24),
        weekday_sin=np.sin(ts.dayofweek*2*np.pi/7),weekday_cos=np.cos(ts.dayofweek*2*np.pi/7),
        spread_price=r.ask-r.bid,spread_R=div(r.ask-r.bid,risk),spread_m1_atr=div(r.ask-r.bid,float(m1.atr14.iloc[-1])))
    # Do not claim geographic sessions without a verified historical server/UTC mapping.
    meta['session_timezone_status']='SERVER_UTC_OFFSET_UNVERIFIED'
    return f,meta

def all_features(r,d):
    a,b=old_features(r,d);c,e=extra_features(r,d);a.update(c);b.update(e)
    return a,b

def main(raw_path=None,out_path=None):
    global RAW,OUT
    baseline_out=ROOT/'reports/qa/three_wave/ready_2024_ml'
    if raw_path is not None:RAW=Path(raw_path)
    if out_path is not None:OUT=Path(out_path);OUT.mkdir(parents=True,exist_ok=True)
    raw={k:pd.read_csv(RAW/f'TW_ml_bars_PERIOD_{k.upper()}.csv').rename(columns={'time':'bar'}) for k in TFS}
    audit={}
    for key,b in raw.items():
        assert b.bar.is_unique and (b.bar.diff().dropna()>0).all()
        assert (b.bar+TFS[key]<=b.available_at).all()
        audit[key+'_bars']=len(b)
    d=prepare(raw)
    sig=pd.read_csv(RAW/'TW_signals.csv');shadow=pd.read_csv(RAW/'TW_ready_shadows.csv');quotes=pd.read_csv(RAW/'TW_ml_entry_quotes.csv')
    env=pd.read_csv(RAW/'TW_M15_environment_USDJPY_260922331.csv');env=env[env.event.eq('READY')]
    assert len(sig)==len(shadow)==len(quotes)==len(env) and sig.signal_id.is_unique
    keep=[c for c in sig if c not in shadow or c=='signal_id']
    x=shadow.merge(sig[keep],on='signal_id',validate='one_to_one').merge(quotes,on='signal_id',validate='one_to_one')
    x=x.merge(env[['id','regime','position','raw_position','range_location','structure_high','structure_low','last_break_direction','minutes_since_break']],left_on='signal_id',right_on='id',validate='one_to_one')
    assert (x.entry_msc==x.time_msc).all() and np.allclose(x.entry,x.ask,atol=0,rtol=0)
    assert x.stop_mode.eq('STOP_M1_REVERSAL_LOW').all() and x.rr.eq(1.2).all()
    assert np.allclose(x.sl,x.m1_reversal_low-.01,atol=.00101,rtol=0)
    for c in ['m1_wave1_confirmed','m1_wave2_confirmed','m1_reversal_confirmed','m5_wave1_confirmed']:
        assert all(seconds(v)<=t/1000 for v,t in zip(x[c],x.entry_msc))
    expected=np.where(x.early_break,'WAVE2_RETURN_HIGH_CLOSE_BREAK','WAVE1_HIGH_CLOSE_BREAK')
    assert (x.state_transition_reason==expected).all()
    x['parent_id']=x.signal_id.str.split('/').str[0]
    journal=(RAW/'tester.log').read_text(encoding='utf-8-sig')
    warnings=sorted(set(re.findall(r'(\d{4}\.\d{2}\.\d{2}) 23:59 - (?:all the )?real ticks (?:absent|discarded)',journal)))
    start_match=re.search(r'real ticks begin from ([0-9.]+ [0-9:]+)',journal)
    start=pd.Timestamp(start_match.group(1)) if start_match else None
    bad=[]
    for _,r in x.iterrows():
        a=pd.to_datetime(r.entry_msc,unit='ms');b=pd.to_datetime(r.exit_msc if r.exit_msc>0 else r.last_msc,unit='ms')
        bad.append(start is None or a<start or any(a.normalize()<=pd.Timestamp(day)<=b.normalize() for day in warnings))
    x['tick_order_unverified']=bad
    x['tester_outcome']=x.outcome;x['tester_target']=x.outcome.map({'TP':1,'SL':0})
    x['target']=x.tester_target.where(~x.tick_order_unverified)
    x['label_status']=np.where(x.outcome.eq('END_CENSORED'),'CENSORED',np.where(x.tick_order_unverified,'UNVERIFIED_TICK_PATH','JOURNAL_CLEAN_REAL_TICK_PATH'))
    x['month']=pd.to_datetime(x.entry_msc,unit='ms').dt.strftime('%Y-%m')
    allf=[];allmeta=[]
    for _,r in x.iterrows():
        f,m=all_features(r,d);allf.append(f);allmeta.append(m)
    feats=pd.DataFrame(allf).replace([np.inf,-np.inf],np.nan);metadata=pd.DataFrame(allmeta)
    for col in ['m15_regime','m15_position','m15_range_location','m15_last_break_direction']:
        old={'m15_regime':'regime','m15_position':'position','m15_range_location':'range_location','m15_last_break_direction':'last_break_direction'}[col]
        assert (feats[col].str.upper()==x[old].str.upper()).all(),col
    np.testing.assert_allclose(feats.m15_raw_position,x.raw_position,atol=1e-10,rtol=0)
    np.testing.assert_allclose(feats.m15_minutes_since_break,x.minutes_since_break,atol=1e-8,rtol=0)
    x=pd.concat([x,feats,metadata],axis=1)
    assert not x.columns.duplicated().any()
    tested=[]
    # Entire feature recomputation from prefixes for quarterly anchors.
    for i in [0,len(x)//4,len(x)//2,3*len(x)//4,len(x)-1]:
        r=x.iloc[i];cut=int(r.entry_msc//1000)
        prefix={k:b[(b.bar+TFS[k]<=cut)&(b.available_at<=cut)].copy() for k,b in raw.items()}
        ff,mm=all_features(r,prepare(prefix));original=allf[i]
        for k in original:
            if isinstance(original[k],str):assert original[k]==ff[k]
            else:np.testing.assert_allclose(original[k],ff[k],atol=1e-10,rtol=0,equal_nan=True)
        tested.append(r.signal_id)
    # Future mutation has no effect before the selected decision.
    idx=len(x)//2;r=x.iloc[idx];cut=int(r.entry_msc//1000);altered={k:b.copy() for k,b in raw.items()}
    for key,b in altered.items():b.loc[(b.bar+TFS[key]>cut)|(b.available_at>cut),['open','high','low','close']]+=100
    f,_=all_features(r,prepare(altered))
    for k,v in allf[idx].items():
        if isinstance(v,str):assert v==f[k]
        else:np.testing.assert_allclose(v,f[k],atol=1e-10,rtol=0,equal_nan=True)
    hashes=json.loads((baseline_out/'source_hashes.json').read_text());assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in hashes.items())
    audit.update(candidates=len(x),feature_count=len(feats.columns),labels=int(x.target.notna().sum()),unverified=int(x.tick_order_unverified.sum()),
        tick_begin=str(start),warning_days=warnings,m15_native_parity='PASS',prefix_ids=tested,future_mutation='PASS',production_frozen_hashes='UNCHANGED')
    x.to_csv(OUT/'ready_2024_ml_dataset.csv',index=False)
    (OUT/'all_feature_columns.json').write_text(json.dumps(list(feats),indent=2))
    (OUT/'dataset_audit.json').write_text(json.dumps(audit,indent=2))
    (OUT/'tick_quality_excerpt.txt').write_text('\n'.join(s for s in journal.splitlines() if 'real ticks' in s and ('absent' in s or 'discarded' in s or 'begin from' in s)),encoding='utf-8')
    print(json.dumps({k:v for k,v in audit.items() if k!='warning_days'},indent=2))

if __name__=='__main__':
    import sys
    main(*sys.argv[1:])
