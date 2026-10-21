"""r4 adds an actual MQL observer lifecycle fixture; previous gates are preserved."""
import argparse,json,re
from pathlib import Path
from analyze_portable_audit_r3 import check_r3
from analyze_portable_audit import aggregate
from analyze_cost_channel import read,native,save
from tick_quality import audit,execution_blocks

def initial_snapshot_errors(rows):
    started=set();errors=set()
    for r in rows:
        if r['phase']=='START':started.add(r['symbol'])
        elif r['symbol'] not in started:errors.add(r['symbol'])
    return sorted(errors)

def check_r4(run,spec,package):
    if spec['kind']!='harness':
        assert not initial_snapshot_errors(read(run/'environment.csv',';')),'Observer reported changes before baseline'
        return check_r3(run,spec,package)
    h,meta,nd=native(run/'report.htm')
    assert h['broker']=='Vantage Trading Ltd' and h['currency']=='USD'
    assert meta['from_date']==spec['date_from'] and meta['to_date']==spec['date_to']
    expected=dict(line.split('=',1) for line in (run/'inputs.set').read_text().splitlines() if '=' in line)
    assert meta['inputs']==expected
    quality=audit(meta,run/'journals')
    assert quality['matching_execution_blocks']==1 and quality['test_finished_in_block']
    block='\n'.join(execution_blocks(meta,run/'journals')[0])
    assert not re.search(r'array out of range|zero divide|QE_FATAL|DQ_FATAL',block,re.I)
    rows=read(run/'telemetry.csv',';')
    assert len(rows)==21 and len({r['test'] for r in rows})==21 and all(r['passed']=='1' for r in rows)
    assert not nd and 'PF_QA_FINISH tests=21 errors=0' in block
    assert not initial_snapshot_errors(read(run/'environment.csv',';'))
    save(run/'audit.json',dict(passed=True,tests=21,quality=quality,
         observer_fixture='First sample is baseline; unchanged stays unchanged; injected later difference is detected'))
    print(json.dumps(dict(run=spec['run_id'],passed=True,tests=21)))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--package',type=Path,required=True);p.add_argument('--run',type=Path);p.add_argument('--run-id');p.add_argument('--batch',type=Path);a=p.parse_args()
    m=json.loads((a.package/'manifest.json').read_text(encoding='utf-8'))
    if a.run:check_r4(a.run,next(r for r in m['runs'] if r['run_id']==a.run_id),a.package)
    else:
        aggregate(a.batch,a.package)
        with (a.batch/'summary.md').open('a',encoding='utf-8') as f:
            f.write('\n## r4監査\n\nハーネス21項目。初回環境snapshotを変更と判定しないことと、後続の差を検出することをMQL上で確認。新旧の対照では売買・費用・候補・環境・履歴fingerprintが一致することを要求。\n')
            f.write('全tick列の暗号学的一致や、観測間隔内で発生して復帰した仕様変更まで証明するものではない。利益改善の採用判定は含まない。\n')
