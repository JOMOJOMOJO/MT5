from pathlib import Path
import hashlib,json,sys
import pandas as pd
import numpy as np
from analyze_m15_regime_position import replay,annotate
from verify_m15_display import compare

ROOT=Path(__file__).resolve().parents[2]
B=ROOT/'reports/qa/three_wave/m15_normal_ready_ema_off'
OLD=ROOT/'reports/qa/three_wave/m15_normal_ready'

def same(a,b,names):
    result={}
    for name in names:
        x=pd.read_csv(a/name);y=pd.read_csv(b/name)
        pd.testing.assert_frame_equal(x,y,check_exact=True)
        result[name]={'rows':len(x),'exact':True}
    return result

def main():
    report={}
    report['native_observer']=same(B/'smoke_native',B/'smoke_observer',
        ['TW_signals.csv','TW_deals.csv','TW_exits.csv','TW_M15_environment_USDJPY_260922331.csv'])
    if '--smoke' not in sys.argv:
        report['reproduction']=same(B/'known_2025h1',B/'repeat_2025h1',
            ['TW_signals.csv','TW_deals.csv','TW_exits.csv','TW_M15_environment_USDJPY_260922331.csv','TW_ready_paths.csv','TW_ready_shadows.csv'])
        for run in ['known_2025h1','known_2024q3']:
            x=pd.read_csv(B/run/'TW_signals.csv');old=pd.read_csv(OLD/run/'TW_signals.csv')
            assert x.signal_id.tolist()==old.signal_id.tolist()
            assert x.signal_time.tolist()==old.signal_time.tolist()
            z=pd.read_csv(B/run/'TW_ready_shadows.csv')
            e=pd.read_csv(B/run/'TW_M15_environment_USDJPY_260922331.csv',dtype={'id':str})
            r=e[e.event.eq('READY')]
            prior='known_close_2025h1' if run=='known_2025h1' else 'holdout_close_2024q3'
            bars=pd.read_csv(ROOT/'reports/qa/three_wave/m15_phase_research'/prior/'MP_phases.csv')
            states,_=replay(bars)
            queries=e.rename(columns={'time_msc':'entry_msc','ask':'entry'}).copy();queries['risk']=1.0
            expected=annotate(queries[['id','entry_msc','entry','risk']],states)
            compare(e.sort_values('time_msc',kind='stable').reset_index(drop=True),expected.reset_index(drop=True))
            assert z.signal_id.tolist()==x.signal_id.tolist()
            q=z.merge(r,left_on='signal_id',right_on='id',validate='one_to_one')
            assert (q.entry_msc==q.time_msc).all() and np.allclose(q.entry,q.ask,rtol=0,atol=1e-9)
            assert (q.wave1_confirmed*1000<=q.entry_msc).all()
            assert (q.hl_confirmed*1000<=q.entry_msc).all()
            assert (q['asof']*1000<=q.entry_msc).all() and (q.break_confirmed*1000<=q.entry_msc).all()
            assert not z.outcome.eq('INVALID_RISK').any()
            p={k:v for k,v in (line.split('=',1) for line in (B/run/'default.set').read_text().splitlines() if '=' in line)}
            o={k:v for k,v in (line.split('=',1) for line in (OLD/run/'default.set').read_text().splitlines() if '=' in line)}
            diff={k:[o.get(k),p.get(k)] for k in set(o)|set(p) if o.get(k)!=p.get(k)}
            assert diff=={'InpUseEMAFilter':['true','false']},diff
            report[run]={'ready_count':len(x),'shadow_count':len(z),'same_ready_ids':True,'causal_times':True,'m15_independent_parity':True,'input_diff':diff}
    h=json.loads((B/'production_hashes_before.json').read_text())
    assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==v for p,v in h.items())
    report['production_unchanged']=True
    name='smoke_validation.json' if '--smoke' in sys.argv else 'validation.json'
    (B/name).write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
