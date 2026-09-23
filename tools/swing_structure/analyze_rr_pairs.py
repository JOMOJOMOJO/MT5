"""Paired level-reach audit and reproducible chart diagnostics, not fills."""
import csv
import argparse
import json
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

ROOT = Path(__file__).resolve().parents[2] / 'reports/qa/three_wave'
parser = argparse.ArgumentParser()
parser.add_argument('--out', default='recovery_rr')
parser.add_argument('--source', default='rr_baseline')
args = parser.parse_args()
OUT = ROOT / args.out
FMT = '%Y.%m.%d %H:%M:%S'


def read(p):
    with p.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))


def dt(s):
    return datetime.strptime(s, FMT)


def stats(rs, suffix):
    values = []
    for r in rs:
        outcome = r['outcome' + suffix]
        if outcome == 'CENSORED':
            continue
        risk = float(r['entry']) - float(r['sl'])
        values.append((float(r['tp' + suffix]) - float(r['entry'])) / risk if outcome == 'TP' else -1)
    gains, losses = sum(v for v in values if v > 0), -sum(v for v in values if v < 0)
    return dict(n=len(values), wins=sum(v > 0 for v in values), net_R=sum(values),
                mean_R=sum(values) / len(values) if values else None,
                PF=gains / losses if losses else None)


def main():
    pairs = read(OUT / 'TW_RR_pairs.csv')
    source = {r['signal_id']: r for r in read(ROOT / args.source / 'TW_signals.csv')}
    bars = read(OUT / 'TW_RR_bars.csv')
    bars = [(dt(b['time']), *(float(b[k]) for k in ('open', 'high', 'low', 'close'))) for b in bars]
    selected = []
    issues = []
    for r in pairs:
        s = source[r['signal_id']]
        entry, sl, peak, high = (float(r[k]) for k in ('entry', 'sl', 'peak_bid', 'm5_high'))
        risk = entry - sl
        r['peak_distance_to_m5_R'] = (peak - high) / risk
        r['near_m5_high_0_1R'] = abs(peak - high) <= 0.1 * risk
        hc, hp = dt(r['hl_confirmed']), dt(r['hl_time'])
        trigger = float(s['m1_wave2_return_high']) if s['early_break'] == 'true' else float(s['m1_wave1_high'])
        available = dt(s['m1_wave2_return_confirmed'] if s['early_break'] == 'true' else s['m1_wave1_confirmed'])
        prior = [b for b in bars if hp < b[0] + timedelta(minutes=1) < hc
                 and b[0] + timedelta(minutes=1) >= available and b[4] > trigger]
        r['trigger_cross_before_hl_confirmation'] = bool(prior)
        r['earliest_prior_cross'] = (prior[0][0]+timedelta(minutes=1)).strftime(FMT) if prior else ''
        r['entry_above_first_prior_close_pips'] = (entry-prior[0][4])/.01 if prior else ''
        r['ask_change_after_hl_confirmation_pips'] = (entry-float(r['ask_at_hl_confirmation']))/.01
        if r['status'] != 'OK' or int(r['ticks']) <= 0:
            issues.append(r['signal_id'] + ': invalid tick history')
        if r['outcome12'] == 'TP' and r['outcome1'] != 'TP':
            issues.append(r['signal_id'] + ': inconsistent nested targets')
        if r['outcome1'] == 'TP' and r['outcome12'] == 'SL':
            selected.append(r)
    months = defaultdict(list)
    for r in pairs:
        months[r['signal_time'][:7]].append(r)
    summary = dict(candidates=len(pairs), source_candidates=len(source), issues=issues,
                   rr1=stats(pairs, '1'), rr12=stats(pairs, '12'),
                   one_R_then_SL_without_1_2R=len(selected),
                   selected_near_M5_high=sum(r['near_m5_high_0_1R'] for r in selected),
                   selected_cross_before_HL_confirm=sum(r['trigger_cross_before_hl_confirmation'] for r in selected),
                   all_rr12_losses=sum(r['outcome12']=='SL' for r in pairs),
                   losses_near_M5=sum(r['outcome12']=='SL' and r['near_m5_high_0_1R'] for r in pairs),
                   losses_preconfirm_cross=sum(r['outcome12']=='SL' and r['trigger_cross_before_hl_confirmation'] for r in pairs),
                   wins_preconfirm_cross=sum(r['outcome12']=='TP' and r['trigger_cross_before_hl_confirmation'] for r in pairs),
                   censored=sum(r['outcome12']=='CENSORED' for r in pairs),
                   monthly={m:dict(rr1=stats(rs,'1'),rr12=stats(rs,'12')) for m,rs in months.items()},
                   assumptions=['Ask entry / Bid exits; fixed SL for both targets',
                                'Nominal R at target or stop; no added commission, execution delay or stop slippage',
                                'Maximum 7 calendar days or test end; censored results reported',
                                'Near M5 = peak within 0.1 initial R of fixed parent high; diagnostic only',
                                'Pre-confirmation price cross is hindsight diagnosis, NOT a tradable confirmed HL'])
    with (OUT/'rr_classified.csv').open('w',newline='',encoding='utf-8') as f:
        w=csv.DictWriter(f,fieldnames=list(pairs[0]));w.writeheader();w.writerows(pairs)
    charts=OUT/'charts';charts.mkdir(exist_ok=True)
    extra=[]
    for key in ('near_m5_high_0_1R','trigger_cross_before_hl_confirmation'):
        example=next((r for r in pairs if r['outcome12']=='SL' and r[key] and r not in selected and r not in extra),None)
        if example:extra.append(example)
    for idx,r in enumerate(selected+extra):
        s=source[r['signal_id']]
        start=min(dt(s['m1_choch_time']),dt(s['m1_wave2_time']))-timedelta(minutes=15)
        end=datetime.fromtimestamp(int(r['exit12'])/1000, tz=__import__('datetime').timezone.utc).replace(tzinfo=None)+timedelta(minutes=5)
        data=[b for b in bars if start<=b[0]<=end]
        if not data:continue
        fig,ax=plt.subplots(figsize=(14,6),layout='constrained')
        for i,(_,o,h,l,c) in enumerate(data):
            color='#00846a' if c>=o else '#cf4655'
            ax.vlines(i,l,h,color=color,linewidth=.7)
            ax.add_patch(Rectangle((i-.3,min(o,c)),.6,max(abs(c-o),.0003),facecolor=color,edgecolor=color))
        levels=[('Entry','entry','#333333'),('SL','sl','#cf4655'),('TP 1R','tp1','#158d62'),('TP 1.2R','tp12','#086a39'),('M5 Wave1 high','m5_high','#d28a00')]
        for label,key,col in levels:
            price=float(r[key]);ax.axhline(price,color=col,linestyle='--',linewidth=1)
            left=key=='m5_high'
            ax.text(.01 if left else .99,price,label,transform=ax.get_yaxis_transform(),ha='left' if left else 'right',va='bottom',color=col,fontsize=9)
        trigger=float(s['m1_wave2_return_high']) if s['early_break']=='true' else float(s['m1_wave1_high'])
        ax.axhline(trigger,color='#0085c5',linestyle=':',linewidth=.8)
        ax.text(.01,trigger,'M1 trigger',transform=ax.get_yaxis_transform(),ha='left',va='bottom',color='#0085c5',fontsize=9)
        for label,when,col in [('HL pivot',r['hl_time'],'#004dba'),('HL confirmed',r['hl_confirmed'],'#0085c5'),('Entry',r['entry_time'],'#444444')]:
            j=min(range(len(data)),key=lambda x:abs((data[x][0]-dt(when)).total_seconds()))
            ax.axvline(j,color=col,linestyle=':',linewidth=1)
            ax.text(j,.72 if label=='Entry' else .02,label,transform=ax.get_xaxis_transform(),rotation=90,va='bottom',fontsize=8,color=col,
                    bbox=dict(facecolor='white',alpha=.7,edgecolor='none',pad=1))
        exit_time=datetime.fromtimestamp(int(r['exit12'])/1000,tz=__import__('datetime').timezone.utc).replace(tzinfo=None)
        j=min(range(len(data)),key=lambda x:abs((data[x][0]-exit_time).total_seconds()))
        ax.axvline(j,color='#cf4655',linestyle=':',linewidth=1)
        ax.text(j,.72,'SL reached',transform=ax.get_xaxis_transform(),rotation=90,va='bottom',fontsize=8,color='#cf4655')
        stride=max(1,len(data)//10);xs=list(range(0,len(data),stride));ax.set_xticks(xs,[data[i][0].strftime('%m-%d %H:%M') for i in xs],rotation=25)
        kind='+1R then SL before +1.2R' if r in selected else 'Loss diagnosis (not a recovered +1R winner)'
        ax.set_title(f"{r['signal_time']} | {kind}\nPeak vs M5 high: {r['peak_distance_to_m5_R']:+.2f}R | Price crossed trigger before HL confirmed: {r['trigger_cross_before_hl_confirmation']}")
        ax.set_ylabel('USDJPY Bid OHLC / Ask entry');ax.grid(alpha=.15)
        fig.savefig(charts/f'case_{idx+1:02d}.png',dpi=140);plt.close(fig)
    (OUT/'rr_summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    print(json.dumps(summary))
    if issues or len(pairs)!=len(source):raise SystemExit(1)


if __name__=='__main__':main()
