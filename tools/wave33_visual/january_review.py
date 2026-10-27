"""Frozen January review and charts. No MT5/API/network activity."""
from pathlib import Path
from datetime import datetime
import csv, json, hashlib, random, statistics, math
from collections import defaultdict
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from matplotlib.patches import Rectangle
from january_higher_tf import ema as seeded_ema

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'reports/backtest/analysis/wave33_january_20261026'
DT = '%Y.%m.%d %H:%M:%S'
RUNS = ('gold_v180', 'gold_v190', 'usd_v180')
plt.rcParams['font.family'] = ['Meiryo', 'Yu Gothic', 'DejaVu Sans']
plt.rcParams['axes.unicode_minus'] = False

def rows(p):
    with p.open(encoding='utf-8-sig', newline='') as f:
        yield from csv.DictReader(f, delimiter=';')

def stats(rr):
    rr=list(rr); gp=sum(x for x in rr if x>0); gl=-sum(x for x in rr if x<0)
    return dict(n=len(rr), wins=sum(x>0 for x in rr), losses=sum(x<0 for x in rr),
                net_r=sum(rr), mean_r=statistics.mean(rr) if rr else None,
                pf_r=gp/gl if gl else None)

def streak(rr):
    best=run=0
    for x in rr:
        run=run+1 if x<0 else 0;best=max(best,run)
    return best

def extract(run):
    source=OUT/'source'/run
    conf={r['parameter']:r['value'] for r in rows(source/'config.csv')}
    fills={}; exits={}; final_event=''; final_type=''; fill_count=exit_count=0
    for r in rows(source/'events.csv'):
        if not r.get('event_type') or None in r: continue
        final_event=r['event_at'];final_type=r['event_type']
        if r['event_type']=='FILL':
            fill_count+=1
            if r['setup_id'] in fills: raise ValueError('Multiple fills need weighted ledger: '+r['setup_id'])
            fills[r['setup_id']]=r
        if r['event_type']=='EXIT':exit_count+=1;exits[r['setup_id']]=r
    records=[]
    for sid,f in fills.items():
        if sid not in exits:continue
        e=exits[sid]; initial=float(f['sl_price']); entry=float(f['entry_price'])
        rec=dict(run=run,setup_id=sid,symbol=conf['symbol'],version=conf['ea_version'],
                 fill_at=f['fill_at'],exit_at=e['exit_at'],direction=f['direction'],entry=entry,
                 initial_sl=initial,final_sl=float(e['sl_price']),tp=float(f['tp_price']),
                 risk_price=abs(entry-initial),net_r=float(e['realized_r']),
                 net_cash=float(e['execution_net_cash']),initial_risk_money=float(e['execution_initial_risk_money']),
                 exit_reason=e['exit_reason'],exit_price=float(e['exit_price']),h1_label=f['h1_direction'])
        for k in ('wave1_start_time','wave1_peak_time','wave1_peak_known_at','wave2_extreme_time','wave2_extreme_known_at','candidate_detected_at','wave1_start_price','wave1_peak_price','wave2_extreme_price','spread_points','wave1_room_r','actual_rr','nearest_obstacle_price','obstacle_distance_r'):
            rec[k]=f.get(k,'')
        records.append(rec)
    records.sort(key=lambda r:r['fill_at'])
    frame=pd.DataFrame(records); frame['entry_dt']=pd.to_datetime(frame.fill_at,format=DT);frame['exit_dt']=pd.to_datetime(frame.exit_at,format=DT)
    frame['month']=frame.entry_dt.dt.strftime('%Y-%m');frame['day']=frame.entry_dt.dt.strftime('%Y-%m-%d')
    frame['hour']=frame.entry_dt.dt.hour;frame['broker_hour_bin']=(frame.hour//6*6).astype(str).str.zfill(2)+'-'+(frame.hour//6*6+5).astype(str).str.zfill(2)
    frame['hold_minutes']=(frame.exit_dt-frame.entry_dt).dt.total_seconds()/60
    frame['cross_weekend']=(frame.exit_dt-frame.entry_dt).dt.total_seconds()>48*3600
    summary=dict(config=conf,last_event=final_event,last_type=final_type,fill_events=fill_count,exit_events=exit_count,
                 unique_fills=len(fills),unique_closed=len(exits),unclosed_ids=sorted(set(fills)-set(exits)),months={})
    for month,g in frame.groupby('month'):
        a=stats(g.net_r);a['net_cash']=float(g.net_cash.sum());a['max_loss_streak']=streak(g.net_r)
        a['directions']={d:{**stats(h.net_r),'net_cash':float(h.net_cash.sum())} for d,h in g.groupby('direction')}
        a['h1_labels']={d:stats(h.net_r) for d,h in g.groupby('h1_label')}
        summary['months'][month]=a
    jan=frame[frame.month=='2025-01']
    # Conditional permutation describes clustering given this already-low win rate.
    rng=random.Random(330125);r=jan.net_r.tolist();observed=streak(r)
    samples=[]
    for i in range(10000):
        rng.shuffle(r);samples.append(streak(r))
    summary['january_streak_permutation']=dict(observed=observed,conditional_tail_probability=sum(x>=observed for x in samples)/len(samples),
        simulations=len(samples),limitation='Conditional random ordering, not proof that real trades are independent or a formal strategy gate')
    groups=[g.net_r.tolist() for _,g in jan.groupby('day')]
    bootstrap=[]
    for i in range(10000):
        sample=[v for day in rng.choices(groups,k=len(groups)) for v in day]
        bootstrap.append(statistics.mean(sample))
    summary['january_day_cluster_bootstrap_mean_r_95pct']=np.quantile(bootstrap,[.025,.975]).tolist()
    frame.drop(columns=['entry_dt','exit_dt']).to_csv(OUT/f'{run}_trades.csv',index=False)
    return frame,summary

def hourly(run):
    b=pd.read_csv(OUT/'source'/run/'upper_bars.csv',sep=';')
    b['t']=pd.to_datetime(b.bar_time,format=DT);b['known']=pd.to_datetime(b.known_at,format=DT)
    b=b.drop_duplicates('t').set_index('t').sort_index()
    h=b.resample('h').agg(open=('open','first'),high=('high','max'),low=('low','min'),close=('close','last'),count=('close','size'),known=('known','max'))
    # These are chart-only H1 bars, complete constituent count still enforced.
    h=h[h['count']==12].dropna();h['ema20']=seeded_ema(h.close.tolist(),20);h['ema50']=seeded_ema(h.close.tolist(),50)
    return h

def candles(ax,b,width):
    for at,r in b.iterrows():
        t=mdates.date2num(at);col='#8bb4c7' if r.close>=r.open else '#8b8d96'
        ax.plot([t,t],[r.low,r.high],color=col,lw=.65)
        ax.add_patch(Rectangle((t-width/2,min(r.open,r.close)),width,max(abs(r.close-r.open),(r.high-r.low)*.02),facecolor=col,edgecolor=col,lw=.4))

def figures(allframes):
    figs=OUT/'figures';figs.mkdir(exist_ok=True)
    fig,axes=plt.subplots(3,1,figsize=(14,10),dpi=130,constrained_layout=True)
    for ax,run in zip(axes,RUNS):
        f=allframes[run];j=f[f.month=='2025-01'];h=hourly(run);h=h[h.index<'2025-02-01'];h.index=h.index+pd.Timedelta(hours=1)
        candles(ax,h,.028)
        contiguous=h.index.to_series().diff().dt.total_seconds().fillna(3600)<=3600
        ax.plot(h.index,h.ema20.where(contiguous),color='#2366b5',lw=.8,label='H1 EMA20')
        ax.plot(h.index,h.ema50.where(contiguous),color='#dd8800',lw=.8,label='H1 EMA50')
        for win,col,mark in [(False,'#d73136','x'),(True,'#008553','o')]:
            g=j[j.net_r>0] if win else j[j.net_r<0];ax.scatter(g.entry_dt,g.entry,c=col,marker=mark,s=32,lw=1.4,zorder=4,label=('勝ち' if win else '負け'))
        z=j[j.net_r==0]
        if len(z):ax.scatter(z.entry_dt,z.entry,c='#777777',marker='s',s=25,zorder=4,label='同値')
        ax.set_title(f'{run} | {len(j)}件 / {int((j.net_r>0).sum())}勝 / 合計 {j.net_r.sum():+.2f}R',loc='left',fontsize=11)
        ax.xaxis.set_major_formatter(mdates.DateFormatter('%m/%d'));ax.grid(alpha=.18);ax.legend(loc='upper left',ncol=4,fontsize=8)
    fig.suptitle('2025年1月：1時間足と全エントリー位置（各実行は別集計）\n赤×＝負け、緑○＝勝ち。横軸はブローカー時刻。表示後半は結果説明用。',fontsize=13)
    fig.savefig(figs/'h1_overview.png');plt.close(fig)
    fig,axes=plt.subplots(1,2,figsize=(13,4.6),dpi=140,constrained_layout=True)
    colors=['#ca6727','#4679b7','#58824b']
    for run,col in zip(RUNS,colors):
        j=allframes[run].query("month=='2025-01'")
        axes[0].plot(j.exit_dt,j.net_r.cumsum(),marker='.',lw=1.3,label=run,color=col)
        for k,d in enumerate(['LONG','SHORT']):
            values=j[j.direction==d].net_r
            axes[1].bar(k+(RUNS.index(run)-1)*.24,values.sum(),width=.22,color=col,label=run if k==0 else None)
    axes[0].set_title('1月の累積損益R（初回の全量リスク基準）');axes[0].xaxis.set_major_formatter(mdates.DateFormatter('%m/%d'));axes[0].legend(fontsize=8)
    axes[1].set_title('方向別の損益R');axes[1].set_xticks([0,1],['ロング','ショート']);axes[1].legend(fontsize=8)
    for ax in axes:ax.grid(axis='y',alpha=.2);ax.axhline(0,color='black',lw=.6)
    fig.savefig(figs/'january_outcomes.png');plt.close(fig)

def main():
    frames={};sums={}
    for run in RUNS:frames[run],sums[run]=extract(run)
    pd.concat(frames.values(),ignore_index=True).drop(columns=['entry_dt','exit_dt']).to_csv(OUT/'trades.csv',index=False)
    (OUT/'root_totals.json').write_text(json.dumps(sums,indent=2,ensure_ascii=False),encoding='utf-8')
    tables=[]
    for run,f in frames.items():
        j=f[f.month=='2025-01']
        for feature in ['direction','h1_label','broker_hour_bin','exit_reason','cross_weekend']:
            for value,g in j.groupby(feature):tables.append(dict(run=run,feature=feature,value=str(value),**stats(g.net_r),net_cash=float(g.net_cash.sum())))
    pd.DataFrame(tables).to_csv(OUT/'root_slices.csv',index=False)
    figures(frames)
    print(json.dumps({k:v['months'].get('2025-01') for k,v in sums.items()},ensure_ascii=True))

if __name__=='__main__':main()
