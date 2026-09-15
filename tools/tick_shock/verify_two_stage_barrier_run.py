"""Integrity gate only; does not rank geometry or change future test inputs."""
import argparse,csv,json
from pathlib import Path

def main():
    p=argparse.ArgumentParser();p.add_argument('run',type=Path);a=p.parse_args();root=a.run
    def rows(name):
        with (root/name).open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
    trades=rows('candidate_trades.csv');summary=rows('candidate_summary.csv')[0]
    checks={k:int(summary[k])==0 for k in ('errors','remaining_positions','unreconciled_records')}
    checks['closed_reconciles']=int(summary['closed'])==len(trades)
    checks['unique_episodes']=len({t['episode_id'] for t in trades})==len(trades)
    checks['unique_positions']=len({t['position_identifier'] for t in trades})==len(trades)
    checks['protective_barriers']=all(float(t['sl'])>0 and float(t['tp'])>0 and int(t['direction'])*(float(t['entry_price'])-float(t['sl']))>0 and int(t['direction'])*(float(t['tp'])-float(t['entry_price']))>0 for t in trades)
    checks['volume_reconciles']=all(abs(float(t['filled_volume'])-float(t['closed_volume']))<1e-8 for t in trades)
    checks['causal_entry']=all(int(t['entry_msc'])>=int(t['processing_msc']) and int(t['quote_msc'])>=int(t['processing_msc']) for t in trades)
    checks['causal_exit']=all(int(t['exit_msc'])>=int(t['entry_msc']) for t in trades)
    checks['profit_reconciles']=all(abs(sum(float(t[k]) for k in ('gross_profit','commission','fee','swap'))-float(t['net_profit']))<1e-6 for t in trades)
    checks['r_reconciles']=all(float(t['risk_amount'])>0 and abs(float(t['net_profit'])/float(t['risk_amount'])-float(t['net_r']))<1e-8 for t in trades)
    times=sorted(int(t['entry_msc']) for t in trades)
    checks['global_spacing']=all(y-x>=int(summary['spacing_seconds'])*1000 for x,y in zip(times,times[1:]))
    checks['time_exit_not_early']=all(float(t['hold_seconds'])>=int(summary['hold_seconds']) for t in trades if t['exit_reason']=='TIME')
    result=dict(status='PASS' if all(checks.values()) else 'FAIL',checks=checks,trades=len(trades),summary=summary)
    (root/'integrity_qa.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result));assert result['status']=='PASS'
if __name__=='__main__':main()
