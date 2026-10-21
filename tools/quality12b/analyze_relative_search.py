"""Predeclared train-only ranking. Known validation years never select parameters."""
import argparse
import csv
import json
import re
from collections import Counter
from pathlib import Path
from statistics import mean

def read_csv(path, delimiter=','):
    with path.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f, delimiter=delimiter))

def write_csv(path, rows):
    if not rows:
        return
    with path.open('w', encoding='utf-8-sig', newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)

def months(start, end):
    y,m=map(int,start[:7].split('.')); ey,em=map(int,end[:7].split('.'))
    result=[]
    while (y,m)<(ey,em):
        result.append(f'{y:04}-{m:02}')
        y,m=(y+1,1) if m==12 else (y,m+1)
    return result

def stats(trades):
    nets=[float(t['net']) for t in trades]
    rs=[float(t['implied_initial_r_price']) for t in trades if t['implied_initial_r_price']]
    loss=-sum(x for x in nets if x<0)
    return dict(n=len(nets), net=sum(nets), pf=sum(x for x in nets if x>0)/loss if loss else None,
                win_rate=mean(x>0 for x in nets) if nets else None,
                mean_price_r=mean(rs) if rs else None)

def summarize(run, folder):
    metrics=json.loads((folder/'metrics.json').read_text(encoding='utf-8-sig'))
    if not metrics['audit']['passed']:
        raise ValueError('Failed report audit: '+str(folder))
    trades=read_csv(folder/'trades.csv')
    mon=Counter(t['entry_time'][:7] for t in trades)
    allmonths=months(run['date_from'],run['date_to'])
    monthly=[dict(run_id=run['run_id'],cell=run.get('cell','smoke'),stage=run['stage'],month=m,n=mon[m]) for m in allmonths]
    years=sorted({m[:4] for m in allmonths})
    annual=[dict(year=y,**stats([t for t in trades if t['entry_time'][:4]==y])) for y in years]
    row=dict(run_id=run['run_id'],cell=run.get('cell','smoke'),stage=run['stage'],**stats(trades),
             min_monthly=min((r['n'] for r in monthly),default=0),
             mean_monthly=mean(r['n'] for r in monthly) if monthly else 0,
             worst_annual_mean_price_r=min((r['mean_price_r'] if r['mean_price_r'] is not None else -999 for r in annual),default=-999),
             train_eligible=bool(annual) and all(r['n']>=36 and r['net']>0 and r['pf'] is not None and r['pf']>=1.1 for r in annual),
             report_quality=metrics['report'].get('model_quality',''))
    funnel=read_csv(folder/'funnel.csv',';')
    istrue=lambda v:v.lower() in ('1','true')
    signals=[r for r in funnel if istrue(r['signal'])]
    row.update(signal_bars=len(funnel),raw_signals=len(signals),
               signals_spread_blocked=sum(not istrue(r['spread_allowed']) for r in signals),
               signals_any_gate_blocked=sum(not istrue(r['entry_gate']) for r in signals))
    row['signals_spread_blocked_other_recorded_gates_clear']=sum(
        not istrue(r['spread_allowed']) and int(r['positions'])==0 and int(r['daily_entries'])<2 and
        not any(istrue(r[k]) for k in ('daily_cap','equity_cap','uncertain_send')) for r in signals)
    risk_checks=0
    for path in (folder/'journals/Tester').rglob('*.log'):
        text=path.read_text(encoding='utf-8-sig',errors='replace')
        for loss,budget in re.findall(r'RISK volume=[\d.]+ expected_loss=([\d.]+) budget=([\d.]+)',text):
            risk_checks+=1
            if float(loss)>float(budget)+.00011:
                raise ValueError('Planned risk exceeds budget in '+str(path))
        if re.search(r'array out of range|zero divide|critical error',text,re.I):
            raise ValueError('Runtime error in '+str(path))
    row['planned_risk_log_checks']=risk_checks
    reason=Counter(r['signal_reason'] for r in funnel)
    return row,monthly,[dict(run_id=run['run_id'],**r) for r in annual],reason

def rank_training(rows):
    training=[r for r in rows if r['stage']=='Search']
    # Eligibility first, then worst-year price R, then total net. Deterministic cell tie-break.
    return sorted(training,key=lambda r:(-int(r['train_eligible']),-r['worst_annual_mean_price_r'],-r['net'],r['cell']))[:3]

def main(batch,package):
    manifest=json.loads((package/'manifest.json').read_text())
    rows=[]; monthly=[]; annual=[]; reasons=[]
    for run in manifest['runs']:
        row,mon,years,counts=summarize(run,batch/run['run_id'])
        rows.append(row); monthly+=mon; annual+=years
        reasons.extend(dict(run_id=run['run_id'],reason=k,n=v) for k,v in counts.items())
    chosen=rank_training(rows)  # Does not read validation rows in its decision.
    chosen_cells={r['cell'] for r in chosen}
    validation=[r for r in rows if r['stage']=='Validate' and r['cell'] in chosen_cells]
    write_csv(batch/'search_statistics.csv',rows)
    write_csv(batch/'monthly_counts.csv',monthly)
    write_csv(batch/'annual_statistics.csv',annual)
    write_csv(batch/'signal_funnel.csv',reasons)
    write_csv(batch/'selected_validation.csv',validation)
    (batch/'selection.json').write_text(json.dumps(dict(selected=chosen,selection_uses_validation=False,adoption=False),indent=2))
    lines=['# Relative continuation: fixed 18-cell study','',
           'Training: 2023–2024. Validation: 2025–September 2026. All periods are known; none is labelled OOS.',
           'Trade net/PF includes broker report costs. Price R excludes commission/swap. Generated/mixed history remains quality-labelled.',
           'Rank: eligible annual n>=36, annual net>0 and PF>=1.1 first; then worst annual mean price R, total net, cell ID. No validation-based selection.',
           'Eligibility is not promotion. Minimum 20 executed trades in every full month remains a separate frequency goal.', '',
           '| Cell | Train net | Worst-year price R | Eligible | Validation net | Validation PF | Validation min/mean monthly |',
           '|---|---:|---:|---|---:|---:|---|']
    for r in chosen:
        v=next(x for x in validation if x['cell']==r['cell'])
        lines.append(f"| {r['cell']} | {r['net']:.2f} | {r['worst_annual_mean_price_r']:.3f} | {r['train_eligible']} | {v['net']:.2f} | {v['pf']} | {v['min_monthly']} / {v['mean_monthly']:.2f} |")
    lines+=['','No preset is automatically adopted. Review yearly concentration, zero months, cap stops, signal/spread funnel and history quality before another experiment.',
            'An ATR-based zero-origin grid is not the former psychological 50-pip grid. This is a successor strategy, not an equivalent-unit reproduction.']
    (batch/'summary.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--batch',type=Path,required=True);ap.add_argument('--package',type=Path,required=True)
    a=ap.parse_args();main(a.batch,a.package)
