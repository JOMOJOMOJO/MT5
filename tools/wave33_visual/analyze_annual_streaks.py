"""Fixed descriptive annual streak diagnosis; no EA changes or parameter search."""
from __future__ import annotations

import argparse
from bisect import bisect_right
from collections import Counter, defaultdict
import csv
from datetime import datetime
import hashlib
import json
from pathlib import Path

import numpy as np


def stamp(s):
    return datetime.fromisoformat(s[:10].replace('.', '-') + s[10:])


def read(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        yield from csv.DictReader(f, delimiter=';')


def number(row, key):
    return float(row.get(key) or 0)


def write_csv(path, rows):
    if not rows:
        return
    with path.open('w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)


def metrics(trades):
    r = [t['net_r'] for t in trades]
    cash = [t['net_cash'] for t in trades]
    win = sum(x > 0 for x in r)
    loss = sum(x < 0 for x in r)
    mean_win=sum(x for x in r if x>0)/win if win else None
    mean_loss=sum(x for x in r if x<0)/loss if loss else None
    return dict(n=len(r), wins=win, losses=loss, flats=len(r)-win-loss,
                win_rate=win/len(r) if r else None,
                sum_r=sum(r), mean_r=float(np.mean(r)) if r else None,
                median_r=float(np.median(r)) if r else None,
                mean_win_r=mean_win, mean_loss_r=mean_loss,
                observed_payoff_breakeven_winrate=-mean_loss/(mean_win-mean_loss) if win and loss else None,
                pf_r=sum(x for x in r if x > 0)/-sum(x for x in r if x < 0) if loss else None,
                net_cash=sum(cash),
                pf_cash=sum(x for x in cash if x > 0)/-sum(x for x in cash if x < 0) if loss else None)


def runs(signs):
    out = []
    for i, sign in enumerate(signs):
        if not out or sign != out[-1]['sign'] or sign == 0:
            out.append(dict(sign=int(sign), first=i, last=i, length=1))
        else:
            out[-1]['last'] = i
            out[-1]['length'] += 1
    return out


def run_stats(signs):
    r = runs(signs)
    return [max([x['length'] for x in r if x['sign'] == 1] or [0]),
            max([x['length'] for x in r if x['sign'] == -1] or [0]), len(r)]


def bars_context(path):
    bars = list(read(path))
    times = [stamp(b['known_at']) for b in bars]
    closes = np.array([float(b['close']) for b in bars])
    high = np.array([float(b['high']) for b in bars])
    low = np.array([float(b['low']) for b in bars])
    previous = np.r_[closes[0], closes[:-1]]
    tr = np.maximum(high-low, np.maximum(abs(high-previous), abs(low-previous)))
    # Simple mean of the most recent 14 closed TRs: explicitly not Wilder ATR.
    atr = np.convolve(tr, np.ones(14)/14, mode='full')[:len(tr)]
    atr[:13] = np.nan

    def at(t, direction):
        i = bisect_right(times, t)-1
        if i < 113:
            return {}
        volatility = atr[i]/float(np.mean(atr[i-100:i]))
        path = float(np.sum(abs(np.diff(closes[i-12:i+1]))))
        change = closes[i]-closes[i-12]
        efficiency = abs(change)/path if path else 0
        return dict(upper_bar_known_at=times[i].isoformat(' '),
                    upper_tr_mean14=float(atr[i]), volatility_ratio=float(volatility),
                    volatility_regime='EXPANDING' if volatility >= 1 else 'CONTRACTING',
                    efficiency12=float(efficiency),
                    efficiency_band='LOW_LT_0.3' if efficiency < .3 else ('MID_0.3_0.6' if efficiency < .6 else 'HIGH_GE_0.6'),
                    aligned_efficiency12=float(direction*change/path) if path else 0)
    return at


def analyze(run, arm, rng, permutations):
    fills, exits = defaultdict(list), defaultdict(list)
    for sequence, row in enumerate(read(run/'events.csv')):
        if row['event_type'] not in {'FILL', 'EXIT', 'PARTIAL_EXIT'}:
            continue
        row['_sequence'] = sequence
        (fills if row['event_type'] == 'FILL' else exits)[row['setup_id']].append(row)
    context = bars_context(run/'upper_bars.csv')
    trades, unclosed = [], []
    for setup, entry in fills.items():
        final = [x for x in exits[setup] if x['event_type'] == 'EXIT']
        if not final:
            unclosed.append(setup)
            continue
        assert len(entry) == len(final) == 1, 'Partial entries require explicit aggregation'
        fill, close = entry[0], final[0]
        entry_time, exit_time = stamp(fill['fill_at']), stamp(close['exit_at'])
        direction = 1 if fill['direction'] == 'LONG' else -1
        room = number(fill, 'wave1_room_r')
        obstacle = number(fill, 'obstacle_distance_r')
        wick = number(fill, 'retracement_ratio')
        risk = number(close, 'execution_initial_risk_money')
        net = number(close, 'execution_net_cash')
        assert risk > 0
        assert abs(number(close, 'realized_r')-net/risk) < 1e-6
        t = dict(arm=arm, setup_id=setup, entry_at=entry_time.isoformat(' '),
                 exit_at=exit_time.isoformat(' '), entry_sequence=fill['_sequence'], exit_sequence=close['_sequence'],
                 month=entry_time.strftime('%Y-%m'), direction=fill['direction'],
                 net_r=net/risk, net_cash=net, risk_cash=risk,
                 holding_minutes=(exit_time-entry_time).total_seconds()/60,
                 lower_recognition=fill['lower_recognition'], h1_direction=fill['h1_direction'],
                 extension='EXTENDED' if number(fill,'wave1_revision') > 0 else 'ORIGINAL',
                 wave1_revision=number(fill,'wave1_revision'),
                 retracement=wick, wick_band='GT_61.8' if wick > .618+1e-10 else 'LE_61.8',
                 wave1_room_r=room, room_band='0.25_TO_0.5' if room < .5 else ('0.5_TO_1' if room < 1 else 'GE_1'),
                 obstacle_distance_r=obstacle,
                 obstacle_band=('LT_1R' if obstacle < 1 else 'GE_1R') if number(fill,'nearest_obstacle_price') > 0 else 'UNAVAILABLE',
                 entry_price=number(fill,'entry_price'), sl_price=number(fill,'sl_price'), tp_price=number(fill,'tp_price'),
                 risk_points=number(fill,'risk_points'), spread_points=number(fill,'spread_points'),
                 spread_r=number(fill,'spread_points')/number(fill,'risk_points'),
                 body_atr=number(fill,'candle_body_atr'), exit_reason=close['exit_reason'])
        t.update(context(entry_time, direction))
        trades.append(t)
    trades.sort(key=lambda t:(t['exit_at'],t['exit_sequence']))
    signs = [int(np.sign(t['net_r'])) for t in trades]
    episodes = runs(signs)
    for i,t in enumerate(trades):
        t['outcome'] = 'WIN' if signs[i]>0 else ('LOSS' if signs[i]<0 else 'FLAT')
        t['cluster'] = 'OTHER'
        known = [x for x in trades if x['exit_at'] < t['entry_at'] or
                 (x['exit_at'] == t['entry_at'] and x['exit_sequence'] < t['entry_sequence'])]
        last = [int(np.sign(x['net_r'])) for x in known[-2:]]
        t['prior_two_known'] = 'AFTER_TWO_WINS' if last == [1,1] else ('AFTER_TWO_LOSSES' if last == [-1,-1] else 'OTHER')
    for ep in episodes:
        selected = trades[ep['first']:ep['last']+1]
        ep.update(arm=arm, kind='WIN' if ep['sign']>0 else ('LOSS' if ep['sign']<0 else 'FLAT'),
                  first_entry=selected[0]['entry_at'], first_exit=selected[0]['exit_at'],
                  last_exit=selected[-1]['exit_at'], sum_r=sum(x['net_r'] for x in selected),
                  setup_ids='|'.join(x['setup_id'] for x in selected))
        if ep['length'] >= 3 and ep['sign'] != 0:
            for t in selected:t['cluster'] = 'WIN_STREAK_GE3' if ep['sign']>0 else 'LOSS_STREAK_GE3'
    observed = run_stats(signs)
    simulation = np.array([run_stats(rng.permutation(signs)) for _ in range(permutations)])
    null = {}
    for j,key in enumerate(['max_win_streak','max_loss_streak','outcome_runs']):
        null[key]=dict(observed=observed[j], permutation_p05_p95=np.quantile(simulation[:,j],[.05,.95]).tolist(),
                       one_sided_p=(1+int(np.sum(simulation[:,j] <= observed[j] if j==2 else simulation[:,j] >= observed[j])))/(permutations+1))
    groups = []
    for feature in ['month','direction','lower_recognition','h1_direction','extension','wick_band','room_band','obstacle_band','volatility_regime','efficiency_band','prior_two_known','exit_reason']:
        buckets = defaultdict(list)
        for t in trades:buckets[t.get(feature,'UNAVAILABLE')].append(t)
        for value, selected in sorted(buckets.items()):groups.append(dict(arm=arm,feature=feature,value=value,**metrics(selected)))
    cluster_features=[]
    for label in ['WIN_STREAK_GE3','LOSS_STREAK_GE3','OTHER']:
        selected=[t for t in trades if t['cluster']==label]
        cluster_features.append(dict(arm=arm,cluster=label,**metrics(selected),
            **{f'median_{key}':float(np.median([t[key] for t in selected if key in t])) if selected else None
               for key in ['retracement','wave1_room_r','spread_r','upper_tr_mean14','volatility_ratio','efficiency12','aligned_efficiency12','wave1_revision']}))
    curve=np.r_[0,np.cumsum([t['net_r'] for t in trades])]
    overview=dict(arm=arm,**metrics(trades),max_win_streak=observed[0],max_loss_streak=observed[1],
                  closed_r_drawdown=float(np.max(np.maximum.accumulate(curve)-curve)),
                  unclosed_filled_setups=unclosed,
                  streaks_ge3=Counter(ep['kind'] for ep in episodes if ep['length']>=3),
                  overlapping_positions=sum(any(x['entry_at']<t['entry_at']<x['exit_at'] for x in trades) for t in trades))
    return dict(summary=overview, permutation=null, trades=trades, episodes=episodes, groups=groups, cluster_features=cluster_features)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--batch',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
    p.add_argument('--a-run',default='a_extension_on');p.add_argument('--b-run',default='b_extension_on')
    p.add_argument('--ea-version',default='1.70')
    args=p.parse_args();args.out.mkdir(parents=True,exist_ok=True)
    result={}
    run_names=[('A',args.a_run),('B',args.b_run)]
    for i,(arm,name) in enumerate(run_names):
        result[arm]=analyze(args.batch/name,arm,np.random.default_rng(20261022+i),9999)
    family=sorted((stat['one_sided_p'],arm,key) for arm,data in result.items() for key,stat in data['permutation'].items())
    adjusted=0
    for rank,(pvalue,arm,key) in enumerate(family):
        adjusted=max(adjusted,min(1,pvalue*(len(family)-rank)))
        result[arm]['permutation'][key]['holm_adjusted_p_family6']=adjusted
    for key in ['trades','episodes','groups','cluster_features']:
        rows=[r for arm in result.values() for r in arm[key]]
        # Context columns may be unavailable during the initial warmup.
        keys=list(dict.fromkeys(k for row in rows for k in row))
        write_csv(args.out/(key+'.csv'),[{k:row.get(k,'') for k in keys} for row in rows])
    proof=dict(batch=str(args.batch.resolve()),ea_version=args.ea_version,run_names=dict(run_names),seed=20261022,permutations=9999,
               definition='Completed positions ordered by actual EXIT then event order; net after booked costs; zero breaks streak; clusters>=3 are retrospective only',
               contextual_features='Frozen FILL snapshot plus only upper bars known by entry. TR mean14, prior100 TR mean14, path efficiency12. No future MFE/MAE.',
               prior_two_known='Only EXIT events available before FILL, including row order for equal timestamps',
               inference='Single-year descriptive study; shuffle preserves overall win/loss counts but assumes exchangeability; overlapping regimes/feature groups are not independent confirmations',
               multiplicity='Holm correction across both arms and all three streak/run statistics (six tests); feature groups are descriptive, no hypothesis-test screen',
               source_sha256={str(path.relative_to(args.batch)):hashlib.sha256(path.read_bytes()).hexdigest()
                              for _,name in run_names for path in [args.batch/name/'events.csv',args.batch/name/'upper_bars.csv']},
               results={arm:{k:v for k,v in data.items() if k not in ['trades','episodes','groups','cluster_features']} for arm,data in result.items()})
    (args.out/'streak_summary.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    fig,axes=plt.subplots(2,2,figsize=(13,7),layout='constrained')
    for j,(arm,data) in enumerate(result.items()):
        trades=data['trades'];x=[stamp(t['exit_at'].replace('-','.')) for t in trades]
        y=np.cumsum([t['net_r'] for t in trades]);colors=['#16864b' if t['net_r']>0 else '#cf3f41' for t in trades]
        axes[0,j].plot(x,y,color='#555555',lw=1);axes[0,j].scatter(x,y,c=colors,s=12)
        axes[0,j].axhline(0,color='#888888',lw=.6);axes[0,j].set_title(arm+(' M15/M5' if arm=='A' else ' M5/M1'))
        axes[0,j].set_ylabel('Cumulative net R (closed positions)');axes[0,j].tick_params(axis='x',labelrotation=35)
        monthly=[g for g in data['groups'] if g['feature']=='month']
        axes[1,j].bar([g['value'][5:] for g in monthly],[g['sum_r'] for g in monthly],color=['#16864b' if g['sum_r']>=0 else '#cf3f41' for g in monthly])
        axes[1,j].axhline(0,color='#888888',lw=.6);axes[1,j].set_xlabel('2020 entry month');axes[1,j].set_ylabel('Monthly net R')
    fig.suptitle('Wave33 v'+args.ea_version+' | generated ticks | base RR=1 | no optimization')
    fig.savefig(args.out/'annual_streaks.png',dpi=150);plt.close(fig)
    print(json.dumps(proof['results'],ensure_ascii=False))


if __name__=='__main__':main()
