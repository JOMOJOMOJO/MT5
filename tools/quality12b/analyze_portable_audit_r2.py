"""Keep the original hard gates; add explicit missing-deal and final-clock evidence."""
import argparse, json, re
from collections import Counter
from pathlib import Path
from analyze_portable_audit import check, aggregate
from analyze_cost_channel import native, read, save
from tick_quality import execution_blocks

def deal_coverage(native_rows, csv_rows):
    counts=Counter(r['deal'] for r in csv_rows)
    expected={r['deal'] for r in native_rows}
    missing=sorted(expected-set(counts),key=int)
    extra=sorted(set(counts)-expected,key=int)
    duplicates=sorted([k for k,v in counts.items() if v!=1],key=int)
    return dict(passed=not (missing or extra or duplicates), native_deals=len(native_rows),
                csv_deals=len(csv_rows),missing_deals=missing,extra_deals=extra,duplicate_deals=duplicates)

def check_r2(run,spec,package):
    if spec['kind']!='harness':
        _,meta,nd=native(run/'report.htm')
        coverage=deal_coverage(nd,read(run/'cost.csv',';')); save(run/'deal_coverage.json',coverage)
        assert coverage['passed'],coverage
        block='\n'.join(execution_blocks(meta,run/'journals')[0])
        matches=re.findall(r'DQ_FINAL quote_clock=(\d+) server_clock=(\d+) narrow=(\d+) all=(\d+) latest_msc=(\d+) captured=(\d+)',block)
        assert matches,'No final deal-history diagnostic'
        clocks=[dict(zip(['quote_clock','server_clock','narrow','all','latest_msc','captured'],map(int,m))) for m in matches]
        save(run/'final_history_clocks.json',clocks)
        assert clocks[-1]['captured']==len(nd)
    check(run,spec,package)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--package',type=Path,required=True);p.add_argument('--run',type=Path);p.add_argument('--run-id');p.add_argument('--batch',type=Path);a=p.parse_args()
    if a.run:
        m=json.loads((a.package/'manifest.json').read_text(encoding='utf-8'))
        check_r2(a.run,next(r for r in m['runs'] if r['run_id']==a.run_id),a.package)
    else:aggregate(a.batch,a.package)
