"""Decompose archived entry delay without relabeling historical pivots."""
from pathlib import Path
import json
import pandas as pd

root=Path(__file__).resolve().parents[2]
qa=root/'reports/qa/three_wave'
out=qa/'fib_hl_sl_only'
rows=[]
for mode in ['ready','confirm','retest']:
    source=qa/f'hl_compare_q1_{mode}'
    s=pd.read_csv(source/'TW_signals.csv')
    d=pd.read_csv(source/'TW_deals.csv')
    for x in s[s.sent].itertuples():
        hl=pd.Timestamp(x.m1_wave2_time)
        confirmed=pd.Timestamp(x.m1_wave2_confirmed)
        decision=pd.Timestamp(x.signal_time)
        entry=d[(d.entry==0)&(d.order==x.order)]
        assert len(entry)==1
        fill=pd.to_datetime(int(entry.time_msc.iloc[0]),unit='ms')
        assert hl<confirmed<=decision<=fill
        rows.append(dict(mode=mode,hl_bar=str(hl),hl_confirmed=str(confirmed),decision=str(decision),
                         fill=str(fill),pivot_wait_minutes=(confirmed-hl).total_seconds()/60,
                         post_confirmation_minutes=(decision-confirmed).total_seconds()/60,
                         decision_to_fill_seconds=(fill-decision).total_seconds(),
                         hl_to_entry_minutes=(fill-hl).total_seconds()/60,
                         trigger=x.state_transition_reason))
df=pd.DataFrame(rows)
df.to_csv(out/'hl_entry_delay.csv',index=False)
summary={}
for mode,g in df.groupby('mode'):
    summary[mode]=dict(trades=len(g),pivot_wait_minutes=sorted(g.pivot_wait_minutes.unique().tolist()),
        median_total=float(g.hl_to_entry_minutes.median()),min_total=float(g.hl_to_entry_minutes.min()),
        max_total=float(g.hl_to_entry_minutes.max()),median_after_confirmation=float(g.post_confirmation_minutes.median()),
        max_after_confirmation=float(g.post_confirmation_minutes.max()),
        median_fill_delay_seconds=float(g.decision_to_fill_seconds.median()),
        triggers=g.trigger.value_counts().to_dict())
(out/'hl_entry_delay_summary.json').write_text(json.dumps(summary,indent=2),'utf-8')
print(json.dumps(summary,indent=2))
