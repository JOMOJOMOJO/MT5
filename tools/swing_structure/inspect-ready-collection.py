"""Post-run integrity and tick-provenance counts only; no model fitting."""
from pathlib import Path
import sys,json,re
import pandas as pd
import numpy as np

def inspect(p):
    journal=(p/'tester.log').read_text(encoding='utf-8-sig')
    start=re.search(r'real ticks begin from ([0-9.]+ [0-9:]+)',journal)
    start=pd.Timestamp(start.group(1)) if start else None
    warnings=sorted(set(re.findall(r'(\d{4}\.\d{2}\.\d{2}) 23:59 - (?:all the )?real ticks (?:absent|discarded)',journal)))
    shadow=pd.read_csv(p/'TW_ready_shadows.csv');signals=pd.read_csv(p/'TW_signals.csv');quotes=pd.read_csv(p/'TW_ml_entry_quotes.csv')
    assert len(shadow)==len(signals)==len(quotes)
    assert shadow.signal_id.is_unique and set(shadow.signal_id)==set(signals.signal_id)==set(quotes.signal_id)
    q=shadow.merge(quotes,on='signal_id',validate='one_to_one')
    assert (q.entry_msc==q.time_msc).all() and np.allclose(q.entry,q.ask,atol=0,rtol=0)
    source='KNOWN_REAL_TICK_START' if start is not None else 'REAL_TICK_START_NOT_IDENTIFIED'
    rows=[]
    for _,r in shadow.iterrows():
        a=pd.to_datetime(r.entry_msc,unit='ms');b=pd.to_datetime(r.exit_msc if r.exit_msc>0 else r.last_msc,unit='ms')
        clean=start is not None and a>=start and not any(a.normalize()<=pd.Timestamp(d)<=b.normalize() for d in warnings)
        rows.append(dict(signal_id=r.signal_id,entry_msc=r.entry_msc,month=a.strftime('%Y-%m'),tester_outcome=r.outcome,
            tick_path_clean=clean,training_label_available=clean and r.outcome in ['TP','SL']))
    quality=pd.DataFrame(rows);quality.to_csv(p/'candidate_tick_quality.csv',index=False)
    bars={}
    for tf,seconds in [('M1',60),('M5',300),('M15',900),('H1',3600)]:
        b=pd.read_csv(p/f'TW_ml_bars_PERIOD_{tf}.csv')
        assert b.time.is_unique and (b.time.diff().dropna()>0).all() and (b.time+seconds<=b.available_at).all()
        bars[tf]=dict(rows=len(b),first=int(b.time.min()),last=int(b.time.max()))
    baseline=p.parents[1]/'ready_2024_ml/annual_2024/default.set'
    def inputs(path):return dict(line.strip().split('=',1) for line in path.read_text(encoding='utf-8-sig').splitlines() if '=' in line)
    assert inputs(p/'default.set')==inputs(baseline),'Fixed inputs changed'
    result=dict(status='COLLECTED_PENDING_ANALYSIS',candidate_count=len(shadow),outcomes=shadow.outcome.value_counts().to_dict(),
        real_tick_begin=str(start) if start is not None else None,tick_provenance=source,warning_days=warnings,
        verified_label_count=int(quality.training_label_available.sum()),bars=bars,inputs_match_2024=True)
    (p/'collection_quality.json').write_text(json.dumps(result,indent=2))
    return result

if __name__=='__main__':
    result=inspect(Path(sys.argv[1]));print(json.dumps({k:v for k,v in result.items() if k not in ['warning_days','bars']},indent=2))
