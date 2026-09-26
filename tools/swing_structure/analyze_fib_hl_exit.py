"""Fixed native MT5 fixed/dynamic HL bracket comparison; no parameter selection."""
from pathlib import Path
import html
import json
import re
import pandas as pd
import argparse

parser=argparse.ArgumentParser()
parser.add_argument('--run-prefix',default='fib_hl_q1')
parser.add_argument('--output',default='fib_hl_exit')
parser.add_argument('--dynamic-run',default=None)
parser.add_argument('--keep-initial-tp',action='store_true')
args=parser.parse_args()

ROOT=Path(__file__).resolve().parents[2]
QA=ROOT/'reports/qa/three_wave'
OUT=QA/args.output
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
for mode in ['static','dynamic']:
    run=args.dynamic_run if mode=='dynamic' and args.dynamic_run else f'{args.run_prefix}_{mode}'
    folder=QA/run
    deals=pd.read_csv(folder/'TW_deals.csv')
    exits=pd.read_csv(folder/'TW_exits.csv')
    signals=pd.read_csv(folder/'TW_signals.csv')
    native=report_values(folder/f'tw_{run}.htm')
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
    updates=pd.read_csv(folder/'TW_hl_exit_updates.csv')
    if mode=='dynamic':
        for row in updates.itertuples():
            assert row.tick_msc>=pd.Timestamp(row.hl_confirmed).value//1_000_000
            assert pd.Timestamp(row.hl_confirmed)>pd.Timestamp(row.signal_time)
            if row.event not in ['SKIP']:
                assert row.new_sl>row.old_sl and row.new_sl<row.fill_price
                assert abs(row.new_sl-(row.hl_price-.01))<1e-8
                if args.keep_initial_tp:
                    initial=signals.loc[signals.sent & (signals.signal_time==row.signal_time),'tp']
                    assert len(initial)==1 and abs(row.new_tp-float(initial.iloc[0]))<1e-8
                    assert abs(row.new_tp-row.old_tp)<1e-8
                else:
                    assert abs(row.new_tp-(row.fill_price+(row.fill_price-row.new_sl)*1.2))<=.00050001
            risk=exits.loc[exits.position_id==row.position,'initial_risk']
            assert len(risk)==1 and abs(float(risk.iloc[0])-row.initial_risk)<1e-7
        applied=updates[updates.event.isin(['MODIFY','RECONCILE'])]
        assert applied.position.is_unique
        diagnostics[mode]['update_events']=updates.event.value_counts().to_dict()
        diagnostics[mode]['update_reasons']=updates.reason.value_counts().to_dict()
    else:
        assert updates.empty
    assert (signals.stop_mode=='STOP_M1_REVERSAL_LOW').all()
    assert not diagnostics[mode]['recovery_blocked']
    all_trades.append(trades)

# Independent closed-bar trigger audit, with the same candidate stream in both runs.
static_signals=pd.read_csv(QA/f'{args.run_prefix}_static/TW_signals.csv')
dynamic_signals=pd.read_csv(QA/(args.dynamic_run or f'{args.run_prefix}_dynamic')/'TW_signals.csv')
assert static_signals.signal_id.tolist()==dynamic_signals.signal_id.tolist()
bars=pd.read_csv(QA/'resistance_research/TW_resistance_M1.csv')
bars.index=pd.to_datetime(bars.time,format='%Y.%m.%d %H:%M:%S')
for row in dynamic_signals.itertuples():
    decision=pd.Timestamp(row.signal_time)
    bar=decision-pd.Timedelta(minutes=1)
    confirmed=pd.Timestamp(row.m1_wave1_confirmed)
    assert bar>=confirmed
    width=row.m1_wave1_high-row.m1_reversal_low
    bottom=row.m1_wave1_high-width*.618;top=row.m1_wave1_high-width*.5
    assert bottom-1e-10<=bars.loc[bar,'close']<=top+1e-10
    prior=bars.loc[(bars.index>=confirmed)&(bars.index<bar),'close']
    assert not ((prior>=bottom-1e-10)&(prior<=top+1e-10)).any()
diagnostics['same_entry_candidates']=True
diagnostics['closed_bar_first_zone_audit_count']=len(dynamic_signals)
trades=pd.concat(all_trades,ignore_index=True)
trades.to_csv(OUT/'trades.csv',index=False)
paired=trades[trades['mode'].eq('static')].merge(
    trades[trades['mode'].eq('dynamic')],on=['entry_msc','parent','choch','wave1'],
    suffixes=('_static','_dynamic'),validate='one_to_one')
paired['delta_R']=paired.net_R_dynamic-paired.net_R_static
paired.to_csv(OUT/'paired_trades.csv',index=False)
diagnostics['paired_executions']=len(paired)
pd.DataFrame(summary).to_csv(OUT/'comparison.csv',index=False)
pd.DataFrame(monthly).to_csv(OUT/'monthly.csv',index=False)
(OUT/'audit.json').write_text(json.dumps(dict(status='PASS',diagnostics=diagnostics),indent=2,ensure_ascii=False),'utf-8')
print(pd.DataFrame(summary).drop(columns=['history_quality']).to_string(index=False))
print(pd.DataFrame(monthly).to_string(index=False))
print('history quality:',ascii(summary[0]['history_quality']),ascii(summary[1]['history_quality']))
