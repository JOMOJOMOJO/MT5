"""Summarize native entry experiments and independently audit closed-bar geometry."""
import bisect
import csv
import json
import statistics
import sys
from collections import Counter
from datetime import datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / 'reports/qa/three_wave'
OUT = ROOT / 'entry_research'
FMT = '%Y.%m.%d %H:%M:%S'

def rows(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))

def dt(s):
    return datetime.strptime(s, FMT)

def key(s):
    return s['m5_choch_time'], s['m1_choch_time']

def realized(run):
    trades = {t['position']:t for t in rows(run/'trades.csv')}
    orders = {d['order']:d['position'] for d in rows(run/'TW_deals.csv') if d['entry']=='0'}
    return {key(s):trades[orders[s['order']]] for s in rows(run/'TW_signals.csv')
            if s['sent']=='true' and s['order'] in orders and orders[s['order']] in trades}

def main():
    holdout='--holdout' in sys.argv
    prefix='entry_holdout_' if holdout else 'entry_train_'
    bars = rows(OUT/'holdout_bars.csv' if holdout else ROOT/'recovery_rr/TW_RR_bars.csv')
    times = [dt(b['time']) for b in bars]
    runs, geometry = {}, {}
    for path in sorted(ROOT.glob(prefix+'*/audit.json')):
        name = path.parent.name.removeprefix(prefix)
        result = json.loads(path.read_text(encoding='utf-8'))
        signals = rows(path.parent/'TW_signals.csv')
        issues = []
        parent_counts = Counter(s['m5_choch_time'] for s in signals if s['sent']=='true')
        if any(n>1 for n in parent_counts.values()):
            issues.append('multiple accepted entries from same M5 structure')
        for s in signals:
            t = dt(s['signal_time'])
            end = bisect.bisect_left(times,t)
            if end == 0 or times[end-1]+timedelta(minutes=1)!=t:
                issues.append('missing closed signal bar '+s['signal_id']); continue
            close = float(bars[end-1]['close'])
            start = bisect.bisect_left(times,dt(s['m5_choch_time']))
            if any(float(b['low'])<float(s['m5_origin']) for b in bars[start:end]):
                issues.append('M5 origin broken before signal '+s['signal_id'])
            # The first closed M5-high breakout may coincide with READY, never precede it.
            start = bisect.bisect_left(times,dt(s['m5_wave1_confirmed'])-timedelta(minutes=1))
            if any(float(b['close'])>float(s['m5_wave1_high']) for b in bars[start:end-1]):
                issues.append('M5 Wave3 already started '+s['signal_id'])
            if name=='choch50':
                if close<=float(s['m1_return_high']):
                    issues.append('CHoCH close did not break return high')
            elif name=='hl':
                if float(bars[end-1]['low'])<float(s['m1_wave2_low']):
                    issues.append('HL already broken on confirmation bar')
            else:
                trigger=float(s['m1_wave2_return_high'] if s['early_break']=='true' else s['m1_wave1_high'])
                if close<=trigger:
                    issues.append('baseline close did not break trigger')
        log=(path.parent/'tester.log').read_text(encoding='utf-8-sig')
        if 'reason=UNRESOLVED_MARKET_SEND' in log:
            issues.append('unresolved market send recovery failure')
        geometry[name]={'signals':len(signals),'issues':issues}
        runs[name]=result
    baseline_path=ROOT/(prefix+'current')/'TW_signals.csv'
    comparisons={}
    if baseline_path.exists():
        baseline={key(s):s for s in rows(baseline_path)}
        for name in ('hl','choch50'):
            p=ROOT/(prefix+name)/'TW_signals.csv'
            if not p.exists(): continue
            earlier={key(s):s for s in rows(p)}
            paired=[]
            for k in sorted(baseline.keys() & earlier.keys()):
                b,e=baseline[k],earlier[k]
                paired.append(dict(m5_choch=k[0],m1_choch=k[1],baseline_time=b['signal_time'],early_time=e['signal_time'],
                    minutes_earlier=(dt(b['signal_time'])-dt(e['signal_time'])).total_seconds()/60,
                    baseline_sent=b['sent'],early_sent=e['sent'],baseline_entry=b['entry_price'],early_entry=e['entry_price'],
                    baseline_sl=b['sl'],early_sl=e['sl']))
            if paired:
                with (OUT/(('holdout_' if holdout else '')+name+'_matched.csv')).open('w',newline='',encoding='utf-8') as f:
                    w=csv.DictWriter(f,fieldnames=list(paired[0]));w.writeheader();w.writerows(paired)
            both=[p for p in paired if p['baseline_sent']=='true' and p['early_sent']=='true']
            comparisons[name]=dict(matched_setups=len(paired),only_early=len(earlier.keys()-baseline.keys()),
                only_baseline=len(baseline.keys()-earlier.keys()),
                median_minutes_earlier=statistics.median(p['minutes_earlier'] for p in paired) if paired else None,
                both_sent=len(both),mean_entry_saving_pips=statistics.mean((float(p['baseline_entry'])-float(p['early_entry']))/.01 for p in both) if both else None)
            actual=realized(p.parent)
            base_actual=realized(baseline_path.parent)
            same_sl=[x for x in both if abs(float(x['baseline_sl'])-float(x['early_sl']))<1e-8]
            common_keys=actual.keys() & base_actual.keys()
            comparisons[name]['common_realized']={
                'trades':len(common_keys),
                'early_profit':sum(float(actual[k]['profit']) for k in common_keys),
                'baseline_profit':sum(float(base_actual[k]['profit']) for k in common_keys),
                'early_net_R':sum(float(actual[k]['result_R']) for k in common_keys),
                'baseline_net_R':sum(float(base_actual[k]['result_R']) for k in common_keys),
                'same_SL_trades':len(same_sl),
                'note':'Common setups selected retrospectively; not a tradable filter. HL can change before baseline entry.'}
            added=[t for k,t in actual.items() if k not in baseline]
            comparisons[name]['additional_setups_realized']={
                'trades':len(added),'profit':sum(float(t['profit']) for t in added),
                'wins':sum(float(t['profit'])>0 for t in added),
                'net_R':sum(float(t['result_R']) for t in added)}
    summary={'runs':runs,'independent_bar_audit':geometry,'matched_candidates':comparisons}
    (OUT/('holdout_comparison.json' if holdout else 'comparison.json')).write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'metrics':{n:r['metrics'] for n,r in runs.items()},'independent_bar_audit':geometry,'matched_candidates':comparisons},ensure_ascii=True))
    if any(v['issues'] for v in geometry.values()): raise SystemExit(1)

if __name__=='__main__': main()
