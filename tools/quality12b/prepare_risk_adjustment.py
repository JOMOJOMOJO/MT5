"""Freeze a single-axis risk-rounding experiment, preserving all prior packages."""
import argparse,difflib,json
from pathlib import Path
from prepare_portable_audit import ROOT,verify,save,sha,once

PARENT=ROOT/'reports/qa/portable_audit_20261012_r5'
DEFAULT=ROOT/'reports/qa/portable_risk_adjustment_20261012'


def adapt(s):
    s=once(s,'PFPlan p;bool ok=PFMakePlan(runtimeSymbol,side,entryPrice,stopPrice,InpRiskPercent,GetDistanceUnit(),p);',
           'PFPlan p;PFAudit a;bool ok=PFMakeAdjustedPlan(runtimeSymbol,side,entryPrice,stopPrice,InpRiskPercent,GetDistanceUnit(),InpAdjustRoundedVolume,p,a);')
    s=once(s,'   PFWrite(runtimeSymbol,side,entryPrice,stopPrice,p);',
           '   PFWrite(runtimeSymbol,side,entryPrice,stopPrice,p);\n   PFAWrite(runtimeSymbol,side,InpAdjustRoundedVolume,entryPrice,stopPrice,p,a);')
    s=once(s,'!PFOpen(runtimeTelemetryFileName+".risk.csv")',
           '!PFOpen(runtimeTelemetryFileName+".risk.csv") || !PFAOpen(runtimeTelemetryFileName+".adjustment.csv")')
    return once(s,'   PFClose();PCClose();','   PFAClose();PFClose();PCClose();')


def prepare(out,draft=False):
    if (out/'manifest.json').exists():return verify(out)
    parent=verify(PARENT);frozen=out/'frozen';frozen.mkdir(parents=True,exist_ok=True)
    include=ROOT/'mql/Include/Research/PortableRiskAdjustment.mqh'
    adjustment=include.read_text(encoding='utf-8').replace('#include "PortableTrading.mqh"','')
    original=(ROOT/parent['sources']['m5_portable']).read_text(encoding='utf-8')
    old_core=(ROOT/'mql/Include/Research/PortableTrading.mqh').read_text(encoding='utf-8')
    updated=adapt(once(original,old_core,old_core+'\n'+adjustment+'\ninput bool InpAdjustRoundedVolume=false;\n'))
    (out/'m5_changes.diff').write_text(''.join(difflib.unified_diff(original.splitlines(True),updated.splitlines(True),fromfile='r5_m5_portable',tofile='risk_adjustment')),encoding='utf-8')
    base=(ROOT/'mql/Experts/Research/RelativeM5PortableDiagnostics.mq5').read_text(encoding='utf-8')
    local=adapt(once(base,'#include "../../Include/Research/PortableTrading.mqh"',
             '#include "../../Include/Research/PortableRiskAdjustment.mqh"\ninput bool InpAdjustRoundedVolume=false;'))
    local_path=ROOT/'mql/Experts/Research/RelativeM5VolumeAdjustmentDiagnostics.mq5'
    local_path.write_text(local,encoding='utf-8')
    sources={}
    harness=ROOT/'mql/Experts/tests/PortableRiskAdjustmentHarness.mq5'
    test=once(harness.read_text(encoding='utf-8'),'#include "../../Include/Research/PortableRiskAdjustment.mqh"',old_core+'\n'+adjustment)
    for name,s in [('m5_legacy',original),('m5_adjusted',updated),('risk_harness',test)]:
        f=frozen/(name+'.mq5');f.write_text(s,encoding='utf-8');sources[name]=str(f.relative_to(ROOT))
    runs=[]
    save(frozen/'harness.json',dict(InpTelemetryFileName='risk_harness.csv'))
    for symbol in ['USDJPY','EURUSD','XAUUSD']:
        runs.append(dict(run_id='harness_'+symbol,expert='risk_harness',kind='harness',symbol=symbol,
                         inputs='harness.json',timeframe='M5',date_from='2023.01.02',date_to='2023.01.04'))
    for symbol in ['USDJPY','EURUSD','XAUUSD']:
        vals=json.loads((PARENT/'frozen'/f'{symbol}.json').read_text(encoding='utf-8'))
        for mode in ['legacy','off','on']:
            v=dict(vals)
            if mode!='legacy':v['InpAdjustRoundedVolume']='true' if mode=='on' else 'false'
            filename=f'{symbol}_{mode}.json';save(frozen/filename,v)
            runs.append(dict(run_id=f'{symbol}_{mode}',expert='m5_legacy' if mode=='legacy' else 'm5_adjusted',
                             kind='m5',symbol=symbol,mode=mode,inputs=filename,timeframe='M5',
                             date_from='2023.01.01',date_to='2023.04.01'))
    files=[include,harness,local_path]+list(frozen.iterdir())
    scripts=['prepare_risk_adjustment.py','analyze_risk_adjustment.py','test_risk_adjustment.py']
    files += [ROOT/'tools/quality12b'/name for name in scripts]
    files += [ROOT/'scripts/run-risk-adjustment.ps1']
    if draft:return dict(sources=sources,runs=runs,draft=True)
    hashes=dict(parent['hashes']);hashes.update({str(p.relative_to(ROOT)):sha(p) for p in files})
    m=dict(purpose='PORTABLE_RISK_ADJUSTMENT_QA',sources=sources,runs=runs,hashes=hashes,preserved=parent['preserved'],
           symbols=['USDJPY','EURUSD','XAUUSD'],expected_server=parent['expected_server'],expected_broker=parent['expected_broker'],
           parent_manifest=str((PARENT/'manifest.json').relative_to(ROOT)),parent_sha256=sha(PARENT/'manifest.json'),
           permitted_change='InpAdjustRoundedVolume only; all other inputs fixed; no trading deployment; no profit selection')
    save(out/'manifest.json',m);return verify(out)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,default=DEFAULT);p.add_argument('--check',action='store_true');p.add_argument('--draft',action='store_true');a=p.parse_args()
    m=verify(a.out.resolve()) if a.check else prepare(a.out.resolve(),a.draft)
    print(json.dumps(dict(verified=not m.get('draft',False),runs=len(m['runs']))))
