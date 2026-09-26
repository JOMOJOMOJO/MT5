"""Fixed native MT5 READY/HL comparison; no parameter selection."""
from pathlib import Path
import html
import json
import re
import pandas as pd

ROOT=Path(__file__).resolve().parents[2]
QA=ROOT/'reports/qa/three_wave'
OUT=QA/'hl_entry_research'
OUT.mkdir(exist_ok=True)

def report_values(path):
    s=path.read_text('utf-16')
    values={}
    for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>',s,re.S|re.I):
        cells=[' '.join(html.unescape(re.sub('<[^>]+>',' ',c)).split())
               for c in re.findall(r'<td\b[^>]*>(.*?)</td>',row,re.S|re.I)]
        for i in range(len(cells)-1):
            if cells[i].endswith(':'):
                values[cells[i]]=cells[i+1]
    return values

all_trades=[]
summary=[]
monthly=[]
diagnostics={}
for mode in ['ready','confirm','retest']:
    folder=QA/f'hl_compare_q1_{mode}'
    deals=pd.read_csv(folder/'TW_deals.csv')
    exits=pd.read_csv(folder/'TW_exits.csv')
    signals=pd.read_csv(folder/'TW_signals.csv')
    native=report_values(folder/f'tw_hl_compare_q1_{mode}.htm')
    deals['net']=deals[['profit','commission','swap','fee']].sum(axis=1)
    rows=[]
    for position,g in deals.groupby('position'):
        entries=g[g.entry==0]
        out=g[g.entry==1]
        assert len(entries)==1 and len(out)==1, 'Investigate partial/netted trade before aggregation'
        ex=exits[exits.position_id==position]
        assert len(ex)==1 and ex.initial_risk.iloc[0]>0
        risk=float(ex.initial_risk.iloc[0])
        entry=entries.iloc[0]
        signal=signals[signals.sent & (signals.signal_time==ex.signal_time.iloc[0])]
        assert len(signal)==1
        s=signal.iloc[0]
        net=float(g.net.sum())
        rows.append(dict(mode=mode,position=int(position),entry_time=entry.time,
                         exit_time=out.time.iloc[0],entry_price=entry.price,
                         entry_msc=int(entry.time_msc),exit_msc=int(out.time_msc.iloc[0]),
                         exit_price=out.price.iloc[0],sl=s.sl,tp=s.tp,initial_risk=risk,
                         hl=s.m1_wave2_low,hl_confirmed=s.m1_wave2_confirmed,
                         reversal_low=s.m1_reversal_low,
                         entry_to_hl_pips=(entry.price-s.m1_wave2_low)/.01,
                         risk_pips=(entry.price-s.sl)/.01,
                         hl_wait_minutes=(pd.Timestamp(entry.time)-pd.Timestamp(s.m1_wave2_confirmed)).total_seconds()/60,
                         net=net,net_R=net/risk,month=entry.time[:7].replace('.','-'),
                         parent=s.m5_choch_time,choch=s.m1_choch_time,wave1=s.m1_wave1_time))
    trades=pd.DataFrame(rows)
    chronological=trades.sort_values('entry_msc')
    assert (chronological.entry_msc.iloc[1:].to_numpy()>=chronological.exit_msc.iloc[:-1].to_numpy()).all()
    assert len(trades)==int(signals.sent.sum())
    assert abs(trades.net.sum()-float(native['\u7dcf\u640d\u76ca:'].replace(' ','')))<.011
    wins=trades.net>0
    gross_profit=trades.loc[wins,'net'].sum()
    gross_loss=-trades.loc[trades.net<0,'net'].sum()
    summary.append(dict(mode=mode,trades=len(trades),win_rate_pct=float(wins.mean()*100),
                        net_usd=round(float(trades.net.sum()),2),
                        expectancy_R=float(trades.net_R.mean()),total_R=float(trades.net_R.sum()),
                        mean_entry_to_hl_pips=float(trades.entry_to_hl_pips.mean()),
                        mean_risk_pips=float(trades.risk_pips.mean()),
                        profit_factor=float(gross_profit/gross_loss) if gross_loss else None,
                        balance_dd=native['\u6b8b\u9ad8\u6700\u5927\u30c9\u30ed\u30fc\u30c0\u30a6\u30f3:'],
                        equity_dd=native['\u8a3c\u62e0\u91d1\u6700\u5927\u30c9\u30ed\u30fc\u30c0\u30a6\u30f3:'],
                        history_quality=native['\u30d2\u30b9\u30c8\u30ea\u30fc\u54c1\u8cea:']))
    for month in ['2025-01','2025-02','2025-03']:
        g=trades[trades.month==month]
        monthly.append(dict(mode=mode,month=month,trades=len(g),net_usd=round(float(g.net.sum()),2),
                            win_rate_pct=float((g.net>0).mean()*100),expectancy_R=float(g.net_R.mean())))
    entries=deals[deals.entry==0].sort_values('time_msc')
    assert (entries.time_msc.diff().dropna()>=900000).all()
    log=(folder/'tester.log').read_text('utf-8-sig')
    diagnostics[mode]=dict(signal_reasons=signals.reason.value_counts().to_dict(),
                          recovery_blocked='RECOVERY_BLOCKED' in log,
                          fee_totals=deals[['commission','swap','fee']].sum().to_dict(),
                          march27_trades=int(((trades.entry_time.str[:10]=='2025.03.27')|
                                              (trades.exit_time.str[:10]=='2025.03.27')).sum()),
                          data_warning_lines=[l for l in log.splitlines() if any(t in l.lower() for t in
                              ['ticks absent','ticks discarded','tick mismatch','no real ticks','real ticks absent'])])
    if mode!='ready':
        events=pd.read_csv(folder/'TW_hl_events.csv')
        arms=events[events.event=='ARM'].set_index('key')
        decisions=events[events.event=='DECISION'].set_index('key')
        assert arms.index.is_unique and decisions.index.is_unique and decisions.parent.is_unique
        for key,d in decisions.iterrows():
            arm=arms.loc[key]
            assert d.tick_msc>=arm.tick_msc>=pd.Timestamp(d.hl_confirmed).value//1_000_000
            assert d.hl==arm.hl and d.zone_top==arm.zone_top and d.sl==arm.sl
            assert abs(d.zone_top-(d.hl+.25*(d.hl-d.sl)))<1e-9
            assert d.bid>=d.hl
            if mode=='confirm': assert d.tick_msc==arm.tick_msc
            if mode=='retest': assert d.hl<=d.ask<=d.zone_top
            if d.sent:
                when=pd.Timestamp(d.tick_msc,unit='ms').floor('s')
                match=signals[(pd.to_datetime(signals.signal_time)==when)&signals.sent]
                assert len(match)==1
                sig=match.iloc[0]
                assert abs(sig.entry_price-d.ask)<1e-9
                assert abs(sig.sl-(d.reversal_low-.01))<1e-8
                assert sig.expected_loss<=sig.equity*.01+1e-7
        diagnostics[mode]['events']=events.event.value_counts().to_dict()
    assert (signals.stop_mode=='STOP_M1_REVERSAL_LOW').all()
    assert not diagnostics[mode]['recovery_blocked']
    all_trades.append(trades)

trades=pd.concat(all_trades,ignore_index=True)
confirm_events=pd.read_csv(QA/'hl_compare_q1_confirm/TW_hl_events.csv')
retest_events=pd.read_csv(QA/'hl_compare_q1_retest/TW_hl_events.csv')
assert confirm_events.loc[confirm_events.event=='ARM','key'].tolist()==retest_events.loc[retest_events.event=='ARM','key'].tolist()
diagnostics['same_initial_hl_opportunities']=True
trades.to_csv(OUT/'trades.csv',index=False)
paired=trades[trades['mode']=='ready'].merge(trades[trades['mode']!='ready'],on=['parent','choch'],suffixes=('_ready','_alternative'))
assert (abs(paired.sl_ready-paired.sl_alternative)<1e-9).all()
paired.to_csv(OUT/'paired_trades.csv',index=False)
pd.DataFrame(summary).to_csv(OUT/'comparison.csv',index=False)
pd.DataFrame(monthly).to_csv(OUT/'monthly.csv',index=False)
(OUT/'audit.json').write_text(json.dumps(dict(status='PASS',diagnostics=diagnostics),indent=2,ensure_ascii=False),'utf-8')
print(pd.DataFrame(summary).drop(columns=['history_quality']).to_string(index=False))
print(pd.DataFrame(monthly).to_string(index=False))
print('history quality:',*[ascii(row['history_quality']) for row in summary])
