"""Compare only HL recognition variants against the archived January READY run."""
from pathlib import Path
import re,html,json
import pandas as pd

ROOT=Path(__file__).resolve().parents[2]
QA=ROOT/'reports/qa/three_wave'
OUT=QA/'hl_recognition'
runs={'original':'ema_filter_off','right1':'hl_rec_right1_jan','reversal':'hl_rec_reversal_jan'}
bars=pd.read_csv(QA/'resistance_research/TW_resistance_M1.csv')
bars.index=pd.to_datetime(bars.time)

def report(path):
    result={}
    for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>',path.read_text('utf-16'),re.S|re.I):
        cells=[' '.join(html.unescape(re.sub('<[^>]+>',' ',c)).split()) for c in re.findall(r'<td\b[^>]*>(.*?)</td>',row,re.S|re.I)]
        for i in range(len(cells)-1):
            if cells[i].endswith(':'): result[cells[i]]=cells[i+1]
    return result

summaries=[]; all_trades=[]; audits={}; signal_tables={}
for mode,run in runs.items():
    folder=QA/run
    s=pd.read_csv(folder/'TW_signals.csv'); signal_tables[mode]=s
    d=pd.read_csv(folder/'TW_deals.csv'); e=pd.read_csv(folder/'TW_exits.csv')
    d['net']=d[['profit','commission','swap','fee']].sum(axis=1)
    native=report(folder/f'tw_{run}.htm')
    rows=[]
    for position,g in d.groupby('position'):
        entry=g[g.entry==0]; exit=g[g.entry==1]
        assert len(entry)==len(exit)==1
        ent=entry.iloc[0]; ex=e[e.position_id==position]
        assert len(ex)==1
        sig=s[s.sent & (s.order==ent.order)]
        assert len(sig)==1
        x=sig.iloc[0]; risk=float(ex.initial_risk.iloc[0]); assert risk>0
        hl=pd.Timestamp(x.m1_wave2_time); known=pd.Timestamp(x.m1_wave2_confirmed)
        decision=pd.Timestamp(x.signal_time); fill=pd.to_datetime(int(ent.time_msc),unit='ms')
        assert hl<known<=decision<=fill
        assert abs(x.sl-(x.m1_wave2_low-.010))<1e-8
        rows.append(dict(mode=mode,position=position,entry_time=ent.time,entry_msc=int(ent.time_msc),
            exit_time=exit.time.iloc[0],exit_msc=int(exit.time_msc.iloc[0]),entry_price=ent.price,
            net=float(g.net.sum()),net_R=float(g.net.sum())/risk,initial_risk=risk,
            parent=x.m5_choch_time,choch=x.m1_choch_time,wave1=x.m1_wave1_time,
            hl_bar=x.m1_wave2_time,hl_price=x.m1_wave2_low,hl_confirmed=x.m1_wave2_confirmed,
            pivot_wait_minutes=(known-hl).total_seconds()/60,
            post_confirm_minutes=(decision-known).total_seconds()/60,
            total_delay_minutes=(fill-hl).total_seconds()/60,
            entry_bar_delay_minutes=(fill.floor('min')-hl).total_seconds()/60,
            entry_to_hl_pips=(ent.price-x.m1_wave2_low)*100,
            trigger=x.state_transition_reason))
    t=pd.DataFrame(rows); assert len(t)==int(s.sent.sum())
    c=t.sort_values('entry_msc')
    assert (c.entry_msc.diff().dropna()>=900000).all()
    assert (c.entry_msc.iloc[1:].to_numpy()>=c.exit_msc.iloc[:-1].to_numpy()).all()
    assert abs(t.net.sum()-float(native['総損益:'].replace(' ','')))<.011
    wins=t.net>0; gp=t.loc[wins,'net'].sum(); gl=-t.loc[t.net<0,'net'].sum()
    summaries.append(dict(mode=mode,candidates=len(s),trades=len(t),win_rate_pct=wins.mean()*100,
        net_usd=round(t.net.sum(),2),expectancy_R=t.net_R.mean(),profit_factor=gp/gl if gl else None,
        equity_dd=native['証拠金最大ドローダウン:'],history_quality=native['ヒストリー品質:'],
        median_recognition_delay=t.pivot_wait_minutes.median(),median_post_confirm=t.post_confirm_minutes.median(),
        median_entry_delay=t.total_delay_minutes.median(),max_entry_delay=t.total_delay_minutes.max(),
        entries_within_one_bar=int((t.entry_bar_delay_minutes<=1).sum()),mean_entry_to_hl_pips=t.entry_to_hl_pips.mean()))
    log=(folder/'tester.log').read_text('utf-8-sig')
    assert 'RECOVERY_BLOCKED' not in log
    a=dict(reasons=s.reason.value_counts().to_dict(),fees=d[['commission','swap','fee']].sum().to_dict())
    if mode!='original':
        events=pd.read_csv(folder/'TW_hl_recognition.csv').drop_duplicates()
        rec=events[events.event.eq('RECOGNIZED')]
        for row in rec.itertuples():
            now=pd.Timestamp(row.time); low_time=pd.Timestamp(row.hl_bar); w1=pd.Timestamp(row.wave1)
            assert now>=pd.Timestamp(row.wave1_known) and low_time>w1 and now>low_time
            assert abs(bars.loc[low_time,'low']-row.hl_price)<1e-8
            last=bars.loc[now-pd.Timedelta(minutes=1)]
            assert abs(last.close-row.close)<1e-8
            if mode=='right1':
                assert now-low_time==pd.Timedelta(minutes=2)
                left=bars.loc[low_time-pd.Timedelta(minutes=2):low_time-pd.Timedelta(minutes=1)]
                assert len(left)==2 and (left.low>row.hl_price).all()
                assert bars.loc[low_time+pd.Timedelta(minutes=1),'low']>=row.hl_price
            else:
                previous=bars.loc[low_time-pd.Timedelta(minutes=1)]
                assert abs(previous.high-row.threshold)<1e-8 and row.close>row.threshold
                available=bars.loc[(bars.index>w1)&(bars.index<now)]
                assert abs(available.low.min()-row.hl_price)<1e-8
                assert available.low.idxmin()==low_time
        a['recognitions']=len(rec)
        a['broken_events']=int(events.event.eq('BROKEN').sum())
    audits[mode]=a; all_trades.append(t)

trades=pd.concat(all_trades,ignore_index=True)
trades.to_csv(OUT/'trades.csv',index=False)
pd.DataFrame(summaries).to_csv(OUT/'comparison.csv',index=False)
base=trades[trades['mode'].eq('original')]
pairs=[]
for mode in ['right1','reversal']:
    alt=trades[trades['mode'].eq(mode)]
    paired=base.merge(alt,on=['parent','choch','wave1'],suffixes=('_original','_alternative'),validate='one_to_one')
    paired['entry_earlier_minutes']=(paired.entry_msc_original-paired.entry_msc_alternative)/60000
    paired['entry_improvement_pips']=(paired.entry_price_original-paired.entry_price_alternative)*100
    paired['alternative_vs_original_hl_minutes']=(pd.to_datetime(paired.entry_msc_alternative,unit='ms').dt.floor('min')-pd.to_datetime(paired.hl_bar_original)).dt.total_seconds()/60
    pairs.append(paired)
    audits[mode]['paired_executed_structures']=len(paired)
    audits[mode]['paired_entries_earlier']=int((paired.entry_earlier_minutes>0.001).sum())
    audits[mode]['paired_median_minutes_earlier']=float(paired.entry_earlier_minutes.median())
pd.concat(pairs).to_csv(OUT/'paired_entries.csv',index=False)
(OUT/'audit.json').write_text(json.dumps(dict(status='PASS',details=audits),indent=2),'utf-8')
print(pd.DataFrame(summaries).drop(columns=['history_quality']).to_string(index=False))
print(json.dumps(audits,indent=2))
