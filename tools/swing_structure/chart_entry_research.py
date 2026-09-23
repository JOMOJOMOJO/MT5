"""Plot native quotes and actual fills; examples selected by stated outcome categories."""
import csv,json,sys
from datetime import datetime,timedelta
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.dates as md
from matplotlib.patches import Rectangle
from compare_entry_research import rows,key,realized,dt,ROOT,OUT

def main():
    arm=sys.argv[1] if len(sys.argv)>1 else 'hl'
    assert arm in ('hl','choch50')
    base={key(s):s for s in rows(ROOT/'entry_train_current/TW_signals.csv')}
    early={key(s):s for s in rows(ROOT/('entry_train_'+arm)/'TW_signals.csv')}
    bt=realized(ROOT/'entry_train_current');et=realized(ROOT/('entry_train_'+arm))
    categories=[('earlier_win_baseline_loss',lambda k:k in bt and float(et[k]['profit'])>0 and float(bt[k]['profit'])<0),
                ('earlier_loss_baseline_win',lambda k:k in bt and float(et[k]['profit'])<0 and float(bt[k]['profit'])>0),
                ('additional_loss',lambda k:k not in base and float(et[k]['profit'])<0),
                ('additional_win',lambda k:k not in base and float(et[k]['profit'])>0)]
    bars=[(dt(b['time']),*[float(b[c]) for c in ('open','high','low','close')]) for b in rows(ROOT/'recovery_rr/TW_RR_bars.csv')]
    folder=OUT/('charts' if arm=='hl' else 'charts_choch50');folder.mkdir(exist_ok=True)
    manifest=[]
    for category,test in categories:
        keys=[k for k in sorted(et) if test(k)]
        if not keys:continue
        k=keys[0];e=early[k];b=base.get(k)
        start=dt(e['m5_wave1_time'])-timedelta(minutes=10)
        finish=max(dt(et[k]['exit_time']),dt(bt[k]['exit_time']) if k in bt else dt(e['signal_time']))+timedelta(minutes=10)
        data=[r for r in bars if start<=r[0]<=finish]
        fig,ax=plt.subplots(figsize=(14,6))
        for t,o,h,l,c in data:
            x=md.date2num(t);color='#16865b' if c>=o else '#d44d50'
            ax.plot([x,x],[l,h],color=color,lw=.7)
            ax.add_patch(Rectangle((x-.3/1440,min(o,c)),.6/1440,max(abs(c-o),.0005),facecolor=color,edgecolor=color,lw=.5))
        for label,price,color in [('M5 Wave1 high',float(e['m5_wave1_high']),'#b77e00'),('M5 origin',float(e['m5_origin']),'#888888')]:
            ax.axhline(price,color=color,ls=':',lw=1,label=label)
        if arm=='choch50':
            ax.axhline((float(e['m5_wave1_high'])+float(e['m5_origin']))/2,color='#438b6b',ls='--',lw=1,label='M5 50% level')
        early_label='HL confirmation' if arm=='hl' else 'M5 fib50 + CHoCH'
        for label,s,tr,color in [(early_label,e,et[k],'#195acc'),('Current',b,bt.get(k),'#a13ca1')]:
            if not s or not tr:continue
            x=md.date2num(dt(s['decision_tick']));price=float(tr['entry_price']);sl=float(s['sl'])
            ax.scatter([x],[price],marker='^',s=80,color=color,zorder=5,label=f'{label}: {dt(s["decision_tick"]):%H:%M}, P/L ${float(tr["profit"]):.2f}')
            end=md.date2num(dt(tr['exit_time']))
            ax.plot([x,end],[sl,sl],ls='--',color=color,lw=1,label=label+' SL')
            ax.plot([x,end],[float(s['tp']),float(s['tp'])],ls=':',color=color,lw=1)
            ax.axvline(x,color=color,alpha=.3)
        time_field,price_field=('m1_wave2_time','m1_wave2_low') if arm=='hl' else ('m1_reversal_time','m1_reversal_low')
        ax.scatter([dt(e[time_field])],[float(e[price_field])],marker='o',facecolors='none',edgecolors='#195acc',s=65,label='Pivot bar (not yet known here)')
        ax.xaxis.set_major_formatter(md.DateFormatter('%H:%M'))
        ax.set_title(f'{category} | {e["signal_time"][:10]} USDJPY M1 | RR=1, Bid candles / Ask entries')
        ax.set_ylabel('USDJPY');ax.grid(alpha=.15);ax.legend(loc='best',fontsize=8)
        fig.tight_layout();name=category+'.png';fig.savefig(folder/name,dpi=140);plt.close(fig)
        manifest.append({'category':category,'file':name,'early_signal':e['signal_time'],'baseline_signal':b['signal_time'] if b else None,'selection':'first chronological example in category'})
    (folder/'manifest.json').write_text(json.dumps(manifest,indent=2))
    print(json.dumps(manifest))

if __name__=='__main__':main()
