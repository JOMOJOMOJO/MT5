"""Fresh reference controls and identical read-only environment instrumentation."""
import argparse,difflib,json,shutil
from pathlib import Path
from prepare_portable_audit import ROOT,verify,once,save,sha

DEFAULT=ROOT/'reports/qa/portable_audit_20261009_r3'
PARENT=ROOT/'reports/qa/portable_audit_20261009_r2'

def instrument(source,environment,symbols,filename):
    original=source
    for typ,name in [('int','OnInit'),('void','OnTick'),('void','OnDeinit'),('double','OnTester')]:
        source=once(source,typ+' '+name+'(',typ+' QABase'+name+'(')
    source=once(source,'   int size=ArraySize(dqSeen);','   QEDeal(ticket);\n   int size=ArraySize(dqSeen);')
    source=environment+'\n'+source+f'''
int OnInit()
  {{int rc=QABaseOnInit();if(rc==INIT_SUCCEEDED && !QEStart({symbols},{filename}))return INIT_FAILED;return rc;}}
void OnTick(){{QEObserve();QABaseOnTick();}}
double OnTester(){{double result=QABaseOnTester();QEEnd();return result;}}
void OnDeinit(const int reason){{QABaseOnDeinit(reason);QEClose();}}
'''
    return source,original

def prepare(out):
    if (out/'manifest.json').exists():return verify(out)
    parent=verify(PARENT)
    frozen=out/'frozen';frozen.mkdir(parents=True,exist_ok=True)
    env_path=ROOT/'mql/Include/Research/PortableEnvironmentAudit.mqh';env=env_path.read_text(encoding='utf-8')
    observer=(ROOT/'mql/Include/Research/PortableDealQuoteAudit.mqh').read_text(encoding='utf-8')
    old_daily_path=ROOT/'mql/Experts/Research/DailyChannelPortfolio.mq5'
    old_daily=old_daily_path.read_text(encoding='utf-8')
    old_daily=once(old_daily,'#include "../../Include/Research/DealQuoteAudit.mqh"',observer)
    old_daily=once(old_daily,'double OnTester(){DQDrain();','double OnTester(){DQDrain(true);')
    inputs={name:(ROOT/path).read_text(encoding='utf-8') for name,path in parent['sources'].items()}
    inputs['daily_reference']=old_daily
    sources={}
    for name,source in inputs.items():
        if name!='portable_harness':
            daily=name.startswith('daily_')
            source,original=instrument(source,env,'InpSymbols' if daily else 'runtimeSymbol','InpTelemetryFileName' if daily else 'runtimeTelemetryFileName')
            (out/(name+'.diff')).write_text(''.join(difflib.unified_diff(original.splitlines(True),source.splitlines(True),fromfile=name+'_parent',tofile=name+'_r3')),encoding='utf-8')
        dest=frozen/(name+'.mq5');dest.write_text(source,encoding='utf-8');sources[name]=str(dest.relative_to(ROOT))
    for p in (PARENT/'frozen').glob('*.json'):shutil.copyfile(p,frozen/p.name)
    values=json.loads((frozen/'daily_legacy_clock.json').read_text(encoding='utf-8'))
    values.pop('InpIndependentClock');values.pop('InpDeviationATR');save(frozen/'daily_reference.json',values)
    runs=[dict(r) for r in parent['runs']]
    legacy=next(r for r in runs if r['run_id']=='daily_legacy_clock')
    historical=legacy['reference'];legacy['reference']='';legacy['paired_reference']='daily_reference';legacy['historical_reference']=historical
    fresh=dict(legacy,run_id='daily_reference',expert='daily_reference',inputs='daily_reference.json',paired_reference='',historical_reference=historical)
    runs.insert(1,fresh)
    for r in runs:
        if r['expert']=='m5_portable':r['paired_reference']=f"m5_{r['symbol']}_reference"
    files=[env_path,old_daily_path,ROOT/'tools/quality12b/prepare_portable_audit_r3.py',ROOT/'tools/quality12b/analyze_portable_audit_r3.py',
           ROOT/'tools/quality12b/portable_pair_audit.py',ROOT/'tools/quality12b/test_portable_audit_r3.py',ROOT/'scripts/run-portable-audit-r3.ps1',
           ROOT/'tools/quality12b/analyze_cost_channel.py',ROOT/'tools/quality12b/analyze_reports.py',ROOT/'tools/quality12b/tick_quality.py',ROOT/'tools/quality12b/compare_reproduction.py']
    hashes=dict(parent['hashes']);hashes.update({str(p.relative_to(ROOT)):sha(p) for p in files+list(frozen.iterdir())})
    save(out/'manifest.json',dict(parent,revision=3,sources=sources,runs=runs,hashes=hashes,
        parent_manifest=str((PARENT/'manifest.json').relative_to(ROOT)),parent_manifest_sha256=sha(PARENT/'manifest.json'),
        change='Fresh daily control plus identical environment/history/conversion observers; trading inputs and code preserved'))
    return verify(out)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,default=DEFAULT);p.add_argument('--check',action='store_true');a=p.parse_args()
    m=verify(a.out.resolve()) if a.check else prepare(a.out.resolve());print(json.dumps(dict(verified=True,revision=3,runs=len(m['runs']))))
