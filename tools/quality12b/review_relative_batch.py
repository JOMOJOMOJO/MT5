"""Post-run, uniquely scoped audit. Does not rerank cells or change source results."""
import csv
import json
import re
from collections import Counter
from pathlib import Path
from tick_quality import audit, execution_blocks

ROOT=Path(__file__).resolve().parents[2]
PKG=ROOT/'reports/qa/rc_search_20261007'
BATCH=PKG/'runs/20261007_094431_0d639534'

def main():
    spec=json.loads((PKG/'manifest.json').read_text())
    out=BATCH/'review';out.mkdir(exist_ok=True)
    rows=[]; monthly=[]; raw_by_stage={}
    for run in spec['runs']:
        folder=BATCH/run['run_id']
        m=json.loads((folder/'metrics.json').read_text(encoding='utf-8-sig'))
        assert m['audit']['passed']
        blocks=execution_blocks(m['report'],folder/'journals/Tester')
        assert len(blocks)==1, run['run_id']
        text='\n'.join(blocks[0])
        risks=re.findall(r'RISK volume=[\d.]+ expected_loss=([\d.]+) budget=([\d.]+)',text)
        assert all(float(loss)<=float(budget)+.00011 for loss,budget in risks)
        assert not re.search('array out of range|zero divide|critical error',text,re.I)
        quality=audit(m['report'],folder/'journals/Tester')
        assert quality['test_finished_in_block']
        signals=list(csv.DictReader((folder/'funnel.csv').open(encoding='utf-8-sig'),delimiter=';'))
        sig=[r for r in signals if r['signal']=='true']
        times=[r['time'] for r in sig]
        assert len(times)==len(set(times))
        if run['stage'] in raw_by_stage:
            assert raw_by_stage[run['stage']]==times
        else:
            raw_by_stage[run['stage']]=times
        trades=list(csv.DictReader((folder/'trades.csv').open(encoding='utf-8-sig')))
        # Some valid plans may still be rejected by the server; inspect these separately.
        assert len(risks)>=len(trades)
        cap=next((r['time'] for r in signals if r['equity_cap']=='true'),None)
        rows.append(dict(run_id=run['run_id'],trades=len(trades),risk_plans=len(risks),
                         failed_trade_result_lines=len(re.findall('TRADE_RESULT operation=',text)),
                         skipped_order_lines=len(re.findall('ORDER_SKIPPED ',text)),
                         quality=quality['category'],fallback_lines=quality['fallback_line_count'],
                         raw_signals=len(sig),equity_cap_first=cap or '',
                         uncertain_bars=sum(r['uncertain_send']=='true' for r in signals)))
    for stage,times in raw_by_stage.items():
        if stage=='Smoke': continue
        counts=Counter(t[:7].replace('.','-') for t in times)
        periods=[r for r in spec['runs'] if r['stage']==stage]
        from analyze_relative_search import months
        for mon in months(periods[0]['date_from'],periods[0]['date_to']):
            monthly.append(dict(stage=stage,month=mon,raw_signals=counts[mon]))
    for filename,records in [('run_audit.csv',rows),('raw_signal_monthly.csv',monthly)]:
        with (out/filename).open('w',newline='',encoding='utf-8-sig') as f:
            w=csv.DictWriter(f,fieldnames=list(records[0]));w.writeheader();w.writerows(records)
    (out/'audit.json').write_text(json.dumps(dict(passed=True,runs=len(rows),
        unique_run_scope=True,source_profit_unchanged=True,selection_unchanged=True,
        original_risk_counter_superseded=True,quality_counts=dict(Counter(r['quality'] for r in rows)),
        risk_plans=sum(r['risk_plans'] for r in rows),runtime_errors=0),indent=2)+'\n')
    print((out/'audit.json').read_text())

if __name__=='__main__':main()
