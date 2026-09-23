"""Causality, independent HTF pivot reconstruction, baseline parity; no return inspection."""
from pathlib import Path
import hashlib,json,sys
import numpy as np
import pandas as pd
import audit_three_wave_features as previous
R=Path(__file__).resolve().parents[2]
ROOT=R/'reports/qa/three_wave/context_research'
FMT='%Y.%m.%d %H:%M:%S'

def audit(name):
    previous.ROOT=ROOT
    base=previous.audit(name)
    run=ROOT/name;c=pd.read_csv(run/'TW_features.csv');x=pd.read_csv(run/'TW_context.csv')
    bars=pd.read_csv(run/'TW_context_bars.csv');bars['dt']=pd.to_datetime(bars.time,format=FMT)
    issues=list(base['issues'])
    def check(ok,msg):
        if not bool(ok):issues.append(msg)
    check(len(x)==len(c)*2 and not x.duplicated(['id','tf']).any(),'context cardinality')
    check(set(x.id)==set(c.id),'context IDs')
    check(set(x.tf)=={'H1','M15'},'context timeframes')
    check((x.status=='OK').all(),'context missing values')
    check(not bars.duplicated(['tf','time']).any(),'duplicate raw bars')
    merged=x.merge(c[['id','signal_time','entry_ask']],on='id',suffixes=('','_candidate'),validate='many_to_one')
    check((merged['asof']==merged.signal_time).all(),'context not at candidate signal')
    check(np.allclose(merged.entry_ask,merged.entry_ask_candidate),'entry mismatch')
    for col in ['closed_time','high_confirmed','old_high_confirmed','low_confirmed','old_low_confirmed']:
        check((pd.to_datetime(x[col],format=FMT)<=pd.to_datetime(x['asof'],format=FMT)).all(),'future '+col)
    check(np.allclose(x.ema_slope_atr,(x.ema20-x.ema_lag3)/(3*x.atr14),atol=1e-8),'EMA slope formula')
    check(np.allclose(x.room_price,x.high-x.entry_ask,atol=1e-9),'room formula')
    pos=x.high>x.low
    check(np.allclose(x.loc[pos,'position'],((x.entry_ask-x.low)/(x.high-x.low))[pos],atol=1e-8),'position formula')
    check(x.loc[~pos,'position'].isna().all(),'invalid range not missing')
    # Reconstruct from exported CLOSED bar prefixes independently of native code.
    reconstructed=0
    for (tf,closed_bar),part in x.groupby(['tf','closed_bar']):
        seconds=3600 if tf=='H1' else 900
        r=bars[(bars.tf==tf)&(bars.time<=closed_bar)].tail(800).reset_index(drop=True)
        check(len(r)==int(part.bars.iloc[0]),'raw prefix length '+tf+'/'+closed_bar)
        high=np.ones(len(r),dtype=bool);low=np.ones(len(r),dtype=bool)
        for k in [1,2]:
            high &= (r.high>r.high.shift(k))&(r.high>r.high.shift(-k))
            low &= (r.low<r.low.shift(k))&(r.low<r.low.shift(-k))
        hi=r[high].tail(2);lo=r[low].tail(2)
        check(len(hi)==2 and len(lo)==2,'missing pivot pair '+tf)
        if len(hi)<2 or len(lo)<2:continue
        for prefix,row in [('high',hi.iloc[-1]),('old_high',hi.iloc[0]),('low',lo.iloc[-1]),('old_low',lo.iloc[0])]:
            kind='high' if 'high' in prefix else 'low'
            check(np.allclose(part[prefix],row[kind]),'pivot price '+prefix)
            check((part[prefix+'_time']==row.time).all(),'pivot bar time '+prefix)
            confirmed=r.loc[int(row.name)+2,'dt']+pd.Timedelta(seconds=seconds)
            check((pd.to_datetime(part[prefix+'_confirmed'],format=FMT)==confirmed).all(),'pivot confirmation '+prefix)
        hdelta=hi.high.iloc[-1]-hi.high.iloc[0];ldelta=lo.low.iloc[-1]-lo.low.iloc[0]
        regime='UP' if hdelta>0 and ldelta>0 else 'DOWN' if hdelta<0 and ldelta<0 else 'RANGE'
        check((part.regime==regime).all(),'independent regime mismatch')
        reconstructed+=1
    log=(run/'tester.log').read_text(encoding='utf-8-sig')
    check('TW_CONTEXT_UNIT up=true down=true range=true unknown=true future=true equal=true' in log,'native deterministic fixtures')
    check(f'TW_CONTEXT_RESULT rows={len(x)} errors=0 orders_sent=0' in log,'context completion')
    parity={}
    prior_name={'smoke':'smoke_fixed','smoke_repeat':'smoke_fixed','discovery':'discovery','replication':'replication'}.get(name)
    if prior_name:
        for f in ['TW_features.csv','TW_feature_outcomes.csv']:
            prior=R/'reports/qa/three_wave/feature_research'/prior_name/f
            parity[f]=prior.read_bytes()==(run/f).read_bytes()
            check(parity[f],'previous research parity '+f)
    manifest=json.loads((ROOT/'baseline_manifest.json').read_text())
    unchanged=all(hashlib.sha256((R/p).read_bytes()).hexdigest()==h for p,h in manifest.items())
    check(unchanged,'baseline mutation')
    result={'run':name,'context_rows':len(x),'independent_snapshots':reconstructed,'regime_counts_raw':x.groupby(['tf','regime']).size().to_dict(),
            'baseline_unchanged':unchanged,'previous_csv_parity':parity,'issues':issues,'passed':not issues}
    result['regime_counts_raw']={'/'.join(k):int(v) for k,v in result['regime_counts_raw'].items()}
    (run/'context_audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result));return result
if __name__=='__main__':
    results=[audit(n) for n in sys.argv[1:]]
    if not results or not all(x['passed'] for x in results):raise SystemExit(1)
