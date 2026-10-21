"""Frozen stratified READY sample; 20 label-blind charts and pixel-level audits.

No EA import/execution. Rendering accepts only relative OHLC and verified points.
"""
from pathlib import Path
from dataclasses import dataclass
import hashlib,json,uuid,struct,copy,sys
import numpy as np
import pandas as pd
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/qa/three_wave/ready_blind_chart_200'
SOURCE=ROOT/'reports/qa/three_wave/ready_generated_tick_ml/all_candidates.csv'
TFS={'M1':(60,120),'M5':(300,96),'M15':(900,64),'H1':(3600,48)}
SPECS=[('M5','origin low','m5_origin','m5_origin_time','m5_origin_confirmed','low'),
 ('M5','broken high','m5_return_high','m5_return_time','m5_return_confirmed','high'),
 ('M5','Wave1 high','m5_wave1_high','m5_wave1_time','m5_wave1_confirmed','high'),
 ('M1','reversal low','m1_reversal_low','m1_reversal_time','m1_reversal_confirmed','low'),
 ('M1','broken high','m1_return_high','m1_return_time','m1_return_confirmed','high'),
 ('M1','Wave1 high','m1_wave1_high','m1_wave1_time','m1_wave1_confirmed','high'),
 ('M1','HL / Wave2 low','m1_wave2_low','m1_wave2_time','m1_wave2_confirmed','low'),
 ('M1','return high','m1_wave2_return_high','m1_wave2_return_time','m1_wave2_return_confirmed','high')]
EVENTS=[('M5','m5_choch_time','m5_return_high','m5_return_confirmed'),
        ('M1','m1_choch_time','m1_return_high','m1_return_confirmed')]
SAFE=['entry_msc','bid','point']+sorted({s for q in SPECS for s in q[2:5]}|{e[1] for e in EVENTS})
META=['signal_id','parent_id','signal_time','year','source_run','real_tick_verified_before','label_exclusion']
BARCOLS=['time','available_at','open','high','low','close']
W,H=2400,1600
FONT=Path('C:/Windows/Fonts')
def font(size,bold=False):return ImageFont.truetype(str(FONT/('arialbd.ttf' if bold else 'arial.ttf')),size)
def sha(b):return hashlib.sha256(b).hexdigest()
def ph(im):return sha(im.convert('RGB').tobytes())
def ts(v):
    if pd.isna(v) or str(v).strip()=='':return None
    return int(pd.Timestamp(v).timestamp())
def write_json(path,x):path.write_text(json.dumps(x,indent=2,ensure_ascii=False),encoding='utf-8')

@dataclass(frozen=True)
class Panel:
    tf:str
    ohlc:tuple
    points:tuple  # label, plotted index, relative price

@dataclass(frozen=True)
class Scene:
    blind_id:str
    panels:tuple

def selection(x):
    path=OUT/'blind_sample_manifest_200_private.csv'
    records=[]
    for year in range(2016,2026):
        g=x[x.year.eq(year)].sort_values('signal_id').reset_index(drop=True)
        seed=2026100200+year
        ix=np.random.default_rng(seed).permutation(len(g))[:20]
        for rank,j in enumerate(ix):
            r=g.iloc[j]
            records.append(dict(candidate_id=r.signal_id,year=year,within_year_rank=rank+1,
                sampling_seed=seed,pilot=rank<2,entry_msc=int(r.entry_msc),entry_time=str(pd.to_datetime(r.entry_msc,unit='ms')),
                ready_time=r.signal_time,parent_id=r.parent_id,source_run=r.source_run,
                source_quality='PRIOR_REAL_TICK_VERIFIED' if r.real_tick_verified_before else 'GENERATED_OR_UNVERIFIED_ALLOWED'))
    new=pd.DataFrame(records)
    # The first 20 presentation rows contain exactly two from each year.
    rng=np.random.default_rng(2026100291)
    order=list(rng.permutation(new.index[new.pilot]))+list(rng.permutation(new.index[~new.pilot]))
    new=new.loc[order].reset_index(drop=True);new.insert(0,'presentation_order',np.arange(1,201))
    if path.exists():
        old=pd.read_csv(path)
        pd.testing.assert_frame_equal(old[new.columns],new,check_dtype=False)
        return old
    new.insert(1,'blind_id',[uuid.uuid4().hex for _ in range(200)])
    assert new.blind_id.is_unique and new.candidate_id.is_unique
    new.to_csv(path,index=False)
    return new

def project_context(row):return {k:row[k] for k in SAFE}

def scene(ctx,blind_id,frames):
    """Causal projection; no results/order status/TP/SL accepted by renderer."""
    cut=int(ctx['entry_msc']);pip=.01  # fixed USDJPY quote convention
    bid=float(ctx['bid']);panels=[];ba=[];aa=[];skips=[]
    for tf,(dur,n) in TFS.items():
        f=frames[tf]
        known=f[((f.time+dur)*1000<=cut)&(f.available_at*1000<=cut)].copy()
        assert len(known)>=n
        view=known.tail(n);times=view.time.to_numpy();points=[]
        for r in view.itertuples():
            ba.append(dict(blind_id=blind_id,tf=tf,bar_time=int(r.time),close_time=int(r.time+dur),available_at=int(r.available_at),entry_msc=cut))
        def omit(label,reason):skips.append(dict(blind_id=blind_id,tf=tf,label=label,reason=reason))
        def add(label,bt,ct,at,price,kind):
            assert bt*1000<=cut and ct*1000<=cut and at*1000<=cut
            if bt not in times:omit(label,'OUTSIDE_FIXED_WINDOW');return
            pos=int(np.flatnonzero(times==bt)[0]);points.append((label,pos,(price-bid)/pip))
            aa.append(dict(blind_id=blind_id,tf=tf,label=label,kind=kind,bar_time=bt,confirmed_time=ct,available_at=at,entry_msc=cut))
        for stf,label,pc,bc,cc,side in SPECS:
            if stf!=tf:continue
            bt=ts(ctx[bc]);ct=ts(ctx[cc]);price=ctx[pc]
            if bt is None or ct is None or pd.isna(price) or float(price)<=0:omit(label,'NO_LOGGED_POINT');continue
            ix=np.flatnonzero(known.time.to_numpy()==bt)
            if len(ix)!=1:omit(label,'BAR_NOT_AVAILABLE');continue
            i=int(ix[0])
            if i<2 or i+2>=len(known):omit(label,'PIVOT_CONTEXT_NOT_AVAILABLE');continue
            a=known.iloc[i-2:i+3];v=a[side].to_numpy();candidate=v[2]
            good=(candidate>v[:2]).all() and (candidate>=v[3:]).all() if side=='high' else (candidate<v[:2]).all() and (candidate<=v[3:]).all()
            expected=int(known.iloc[i+2].time)+dur;at=int(a.available_at.max())
            if not good or abs(candidate-float(price))>1e-8 or ct!=expected or max(ct,at)*1000>cut:
                omit(label,'PIVOT_LOG_PRICE_OR_TIMING_MISMATCH');continue
            add(label,bt,ct,at,float(price),'LOGGED_PIVOT_2_2')
        for etf,col,refcol,refconfirmed in EVENTS:
            if etf!=tf:continue
            # CSV writer exports internal break bar_time + TF seconds, i.e. CLOSE time.
            ct=ts(ctx[col]);rc=ts(ctx[refconfirmed]);ref=float(ctx[refcol])
            if ct is None or rc is None:omit('CHoCH','NO_LOGGED_BREAK');continue
            bt=ct-dur
            q=known[known.time.eq(bt)]
            if len(q)!=1:omit('CHoCH','BREAK_BAR_NOT_AVAILABLE');continue
            r=q.iloc[0];at=int(r.available_at)
            # Closed break against the logged, already-confirmed broken high.
            ref_label='broken high'
            verified_ref=any(z['label']==ref_label and z['tf']==tf for z in aa)
            if not verified_ref or rc>ct or max(ct,at)*1000>cut or r.close<=ref:
                omit('CHoCH','BREAK_REFERENCE_OR_TIME_NOT_VERIFIED');continue
            add('CHoCH',bt,ct,at,float(r.close),'LOGGED_CLOSE_BREAK')
        ohlc=tuple(tuple(float(v) for v in a) for a in ((view[['open','high','low','close']].to_numpy()-bid)/pip))
        panels.append(Panel(tf,ohlc,tuple(points)))
    return Scene(blind_id,tuple(panels)),ba,aa,skips

PALETTE=['#6854bf','#aa6512','#127aad','#bc356a','#42822d','#765441','#298c8a','#7658a1']
def render(s):
    """Only scene fields exist here: random ID, TF, relative candles, verified points."""
    base=Image.new('RGB',(W,H),'#fbfcfe');d=ImageDraw.Draw(base)
    overlay=Image.new('RGBA',(W,H),(0,0,0,0));a=ImageDraw.Draw(overlay)
    d.text((70,25),s.blind_id,font=font(24,bold=True),fill='#263648')
    d.text((2330,32),'Closed candles | Right edge = assessment boundary',anchor='ra',font=font(23),fill='#536579')
    masks=[];texts=[s.blind_id,'Closed candles | Right edge = assessment boundary']
    for k,p in enumerate(s.panels):
        x0=70+(k%2)*1180;y0=92+(k//2)*735
        l=x0+75;t=y0+100;r=x0+1060;b=y0+630
        body=np.asarray(p.ohlc);n=len(body);low=float(body[:,2].min());high=float(body[:,1].max());pad=max((high-low)*.05,.2)
        lo=low-pad;hi=high+pad
        xp=lambda j:l+(j+.5)*(r-l)/n
        yp=lambda price:b-(price-lo)/(hi-lo)*(b-t)
        d.text((x0,y0),p.tf,font=font(33,bold=True),fill='#23394e');texts.append(p.tf)
        d.text((r,y0+8),f'{n} closed bars',anchor='ra',font=font(23),fill='#536579');texts.append(f'{n} closed bars')
        for v in np.linspace(lo,hi,6):
            y=yp(v);d.line((l,y,r,y),fill='#e3e8ee',width=1)
            txt=f'{v:+.1f}';d.text((l-12,y),txt,anchor='rm',font=font(21),fill='#536579');texts.append(txt)
        d.text((x0+5,y0+58),'pips',font=font(20),fill='#536579');texts.append('pips')
        for j in [0,n//4,n//2,3*n//4,n]:
            xx=l+j*(r-l)/n;txt=str(j-n)
            d.line((xx,b,xx,b+6),fill='#8795a5',width=1)
            d.text((xx,b+14),txt,anchor='ma',font=font(20),fill='#536579');texts.append(txt)
        d.text(((l+r)/2,b+45),'Closed bars before boundary',anchor='ma',font=font(20),fill='#536579');texts.append('Closed bars before boundary')
        candle_mask=Image.new('1',(W,H));cm=ImageDraw.Draw(candle_mask)
        width=max(3,int((r-l)/n*.66))
        for j,(op,h,le,cl) in enumerate(body):
            xx=xp(j);color='#148276' if cl>=op else '#bf4651'
            line=(xx,yp(h),xx,yp(le));d.line(line,fill=color,width=2);cm.line(line,fill=1,width=2)
            y1,y2=sorted((yp(op),yp(cl)));y2=max(y2,y1+2)
            box=(xx-width/2,y1,xx+width/2,y2);d.rectangle(box,fill=color);cm.rectangle(box,fill=1)
        d.line((l,b,r,b),fill='#8795a5',width=1)
        d.line((r,t,r,b),fill='#8795a5',width=2)
        # All legend text occupies a reserved gutter; only small hollow marks overlay candles.
        for j,(label,idx,price) in enumerate(p.points):
            color=PALETTE[j%len(PALETTE)];lx=l+(j%4)*245;ly=y0+42+(j//4)*26
            a.ellipse((lx,ly+3,lx+10,ly+13),outline=color,width=2)
            a.text((lx+16,ly),label,font=font(20),fill=color);texts.append(label)
            xx=xp(idx);yy=yp(price)
            a.ellipse((xx-6,yy-6,xx+6,yy+6),outline=color,width=2)
        a.text((r,t-27),'READY boundary',anchor='ra',font=font(18),fill='#536579');texts.append('READY boundary')
        masks.append(candle_mask)
    annotated=Image.alpha_composite(base.convert('RGBA'),overlay).convert('RGB')
    raw=np.asarray(base);ann=np.asarray(annotated);alpha=np.asarray(overlay)[:,:,3]>0
    assert np.array_equal(raw[~alpha],ann[~alpha])
    candle=np.logical_or.reduce([np.asarray(m,dtype=bool) for m in masks])
    overlap=int(np.sum(alpha&candle));total=int(candle.sum())
    return base,annotated,dict(base_pixel_hash=ph(base),annotation_mask_pixels=int(alpha.sum()),
        candle_pixels=total,annotation_over_candle_pixels=overlap,annotation_candle_fraction=overlap/total,
        base_unchanged_outside_annotation_mask=True,visible_text=texts)

def png_chunks(path):
    data=path.read_bytes();assert data[:8]==b'\x89PNG\r\n\x1a\n';i=8;names=[]
    while i<len(data):
        n=struct.unpack('>I',data[i:i+4])[0];name=data[i+4:i+8].decode('ascii');names.append(name);i+=12+n
    assert set(names)<={'IHDR','IDAT','IEND'}
    return names

def main():
    OUT.mkdir(parents=True,exist_ok=True);priv=OUT/'private_audit';priv.mkdir(exist_ok=True)
    public=OUT/'public';(public/'raw').mkdir(parents=True,exist_ok=True);(public/'annotated').mkdir(exist_ok=True)
    # Read a column allowlist, not the candidate outcomes or fixed-price exits.
    x=pd.read_csv(SOURCE,usecols=list(dict.fromkeys(SAFE+META)))
    x=x[x.label_exclusion.eq('INCLUDED')].copy();assert len(x)==2083 and x.signal_id.is_unique
    prod=json.loads((OUT.parent/'ready_generated_tick_ml/audit.json').read_text())['source_hashes']
    before={p:sha((ROOT/p).read_bytes()) for p in prod}
    manifest=selection(x);assert manifest.groupby('year').size().eq(20).all()
    pilot=manifest[manifest.pilot].copy();assert len(pilot)==20 and pilot.groupby('year').size().eq(2).all()
    private=pilot.copy();private.to_csv(OUT/'private_label_manifest_20.csv',index=False)
    # Deliberately no realized outcome or image grades in this management file.
    pub=pd.DataFrame(dict(blind_id=pilot.blind_id,raw_image_path='public/raw/'+pilot.blind_id+'.png',
                         annotated_image_path='public/annotated/'+pilot.blind_id+'.png'))
    pub.to_csv(OUT/'public_sample_manifest_20.csv',index=False)
    cache={};barsaudit=[];annaudit=[];skips=[];audit=[];source_hashes={};scenes={}
    logchecked=[]
    generation=pilot.iloc[np.random.default_rng(2026100292).permutation(20)]
    for number,r in enumerate(generation.itertuples(),1):
        print(f'RENDER_AND_AUDIT {number}/20 {r.blind_id}',flush=True)
        row=x[x.signal_id.eq(r.candidate_id)].iloc[0].to_dict();ctx=project_context(row)
        if r.year not in cache:
            folder=ROOT/r.source_run
            frames={tf:pd.read_csv(folder/f'TW_ml_bars_PERIOD_{tf}.csv',usecols=BARCOLS) for tf in TFS}
            sig=pd.read_csv(folder/'TW_signals.csv',usecols=['signal_id']+[c for c in SAFE if c not in ['entry_msc','bid','point']]).set_index('signal_id')
            quotes=pd.read_csv(folder/'TW_ml_entry_quotes.csv').set_index('signal_id')
            for tf,f in frames.items():assert f.time.is_unique and f.time.is_monotonic_increasing
            for name in [f'TW_ml_bars_PERIOD_{tf}.csv' for tf in TFS]+['TW_signals.csv','TW_ml_entry_quotes.csv']:
                source_hashes[str((folder/name).relative_to(ROOT))]=sha((folder/name).read_bytes())
            cache[r.year]=(frames,sig,quotes)
        frames,sig,quotes=cache[r.year]
        original=sig.loc[r.candidate_id]
        for c in original.index:
            v=row[c];o=original[c]
            assert (pd.isna(v) and pd.isna(o)) or v==o or (isinstance(v,(float,int)) and np.isclose(v,o,rtol=0,atol=1e-10)),(c,v,o)
        assert quotes.loc[r.candidate_id,'time_msc']==row['entry_msc']
        assert abs(quotes.loc[r.candidate_id,'bid']-row['bid'])<1e-10
        logchecked.append(r.blind_id)
        s,ba,aa,om=scene(ctx,r.blind_id,frames);scenes[r.blind_id]=s
        raw,ann,renderaudit=render(s);h0=(ph(raw),ph(ann))
        barsaudit+=ba;annaudit+=aa;skips+=om
        # Prefix-only input must give the same scene AND the same pixels.
        cut=ctx['entry_msc'];prefix={tf:f[((f.time+TFS[tf][0])*1000<=cut)&(f.available_at*1000<=cut)].copy() for tf,f in frames.items()}
        ps,*_=scene(ctx,r.blind_id,prefix);pr,pa,_=render(ps);assert (ph(pr),ph(pa))==h0
        altered={tf:f.copy() for tf,f in frames.items()};mutated=0
        for tf,f in altered.items():
            mask=((f.time+TFS[tf][0])*1000>cut)|(f.available_at*1000>cut);mutated+=int(mask.sum())
            f.loc[mask,['open','high','low','close']]=np.array([1e8,2e8,-1e8,1.5e8])
        fs,*_=scene(ctx,r.blind_id,altered);fr,fa,_=render(fs);assert (ph(fr),ph(fa))==h0 and mutated>0
        # Mutation is performed before the context allowlist boundary, including unknown aliases.
        poison=dict(row);rng=np.random.default_rng(2026100203+number)
        for key in ['outcome','R','result_r','TP','tp','SL','sl','exit','exit_msc','MFE','MAE','mfe_to_exit','mae_to_exit','mfe_until_sl_or_24h','mae_until_sl_or_24h']:
            poison[key]=str(uuid.uuid4()) if key=='outcome' else float(rng.normal()*1e12)
        lc=project_context(poison);assert lc==ctx
        ls,*_=scene(lc,r.blind_id,frames);lr,la,_=render(ls);assert (ph(lr),ph(la))==h0
        # Changes to future annotation metadata must be omitted, not displayed.
        blocked=dict(ctx)
        for sp in SPECS:blocked[sp[4]]=str(pd.to_datetime(cut+86400000,unit='ms'))
        bs,_,blocked_audit,_=scene(blocked,r.blind_id,frames)
        assert not blocked_audit and all(not p.points for p in bs.panels)
        for kind,im in [('raw',raw),('annotated',ann)]:
            path=public/kind/f'{r.blind_id}.png'
            if kind=='raw' and path.exists():assert ph(Image.open(path))==h0[0], 'Frozen raw image changed'
            im.save(path,format='PNG',compress_level=6)
            assert not Image.open(path).info;png_chunks(path)
            assert ph(Image.open(path))==h0[0 if kind=='raw' else 1]
            # Uniform filesystem timestamps prevent generation metadata from identifying chronology.
            import os
            os.utime(path,(946684800,946684800))
        audit.append(dict(blind_id=r.blind_id,raw_pixel_hash=h0[0],annotated_pixel_hash=h0[1],
            prefix_pixel_match=True,future_mutation_pixel_match=True,label_mutation_pixel_match=True,
            future_annotation_blocked=True,mutated_future_rows=mutated,metadata_empty=True,**renderaudit))
    assert len(list((public/'raw').glob('*.png')))==len(list((public/'annotated').glob('*.png')))==20
    assert {p.name for p in public.rglob('*') if p.is_file()}=={v+'.png' for v in pilot.blind_id}
    assert all(p.suffix=='.png' for p in public.rglob('*') if p.is_file())
    assert list(pub)==['blind_id','raw_image_path','annotated_image_path']
    assert pub.blind_id.is_unique and manifest.candidate_id.is_unique
    assert all(len(v)==32 and all(c in '0123456789abcdef' for c in v) for v in pub.blind_id)
    pd.DataFrame(barsaudit).to_csv(priv/'ohlc_availability.csv',index=False)
    pd.DataFrame(annaudit).to_csv(priv/'annotation_availability.csv',index=False)
    pd.DataFrame(skips).to_csv(priv/'annotation_omissions.csv',index=False)
    pd.DataFrame(audit).drop(columns='visible_text').to_csv(priv/'pixel_audit.csv',index=False)
    write_json(priv/'visible_text.json',{r['blind_id']:r['visible_text'] for r in audit})
    assert before=={p:sha((ROOT/p).read_bytes()) for p in prod}
    # Text is generated solely from the Scene contract and constants, never source identifiers.
    text='\n'.join(v for a in audit for v in a['visible_text'])
    for forbidden in ['source_run','candidate_id','outcome','TP','SL','MFE','MAE','C:\\','reports/','2016.','2025.']:
        assert forbidden not in text
    qa=priv/'visual_pairs';qa.mkdir(exist_ok=True)
    for rr in pilot.itertuples():
        # Half-size preview for all-pair visual review, originals remain 2400x1600.
        pair=Image.new('RGB',(1200,1600),'white')
        for i,kind in enumerate(['raw','annotated']):
            im=Image.open(public/kind/f'{rr.blind_id}.png').resize((1200,800),Image.Resampling.LANCZOS);pair.paste(im,(0,800*i))
        pair.save(qa/f'{rr.blind_id}.png')
    result=dict(status='MACHINE_AUDIT_PASS_VISUAL_REVIEW_PENDING',frozen_n=200,pilot_n=20,
        annual_frozen=manifest.groupby('year').size().to_dict(),annual_pilot=pilot.groupby('year').size().to_dict(),
        rendered_files=40,ohlc_rows=len(barsaudit),annotation_rows=len(annaudit),omissions=len(skips),
        log_snapshot_matches=len(logchecked),all_20_prefix_pass=True,all_20_future_mutation_pass=True,all_20_label_mutation_pass=True,
        production_unchanged=True,source_candidate_sha256=sha(SOURCE.read_bytes()),source_hashes=source_hashes,
        production_hashes=before,sample_sha256=sha((OUT/'blind_sample_manifest_200_private.csv').read_bytes()),
        max_candle_overlay_fraction=max(a['annotation_candle_fraction'] for a in audit),
        generator_sha256=sha(Path(__file__).read_bytes()),public_no_labels=True,PNG_chunks=['IHDR','IDAT','IEND'])
    write_json(priv/'machine_audit.json',result)
    print('MACHINE_AUDIT_COMPLETE',len(barsaudit),len(annaudit),len(skips),flush=True)

if __name__=='__main__':main()
