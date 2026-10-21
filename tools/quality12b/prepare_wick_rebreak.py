"""Freeze the agreed two-arm entry study. Never changes the parent package."""
import argparse,difflib,json
from pathlib import Path
from prepare_portable_audit import ROOT,verify,save,sha,once

PARENT=ROOT/'reports/qa/portable_risk_adjustment_20261012'
DEFAULT=ROOT/'reports/qa/wick_rebreak_20261013'


def adapt(s,body):
    s=once(s,'int BaseOnInit()' if 'int BaseOnInit()' in s else 'int OnInit()',
           body+'\n'+('int BaseOnInit()' if 'int BaseOnInit()' in s else 'int OnInit()'))
    s=once(s,'   RefreshOperatorMode();\n   WriteStatusSnapshot();\n   return INIT_SUCCEEDED;',
           '   if(!RBOpen()) return INIT_FAILED;\n   RefreshOperatorMode();\n   WriteStatusSnapshot();\n   return INIT_SUCCEEDED;')
    s=once(s,'   PFAClose();PFClose();PCClose();','   RBClose();\n   PFAClose();PFClose();PCClose();')
    s=once(s,'   DCUpdate(newMainBar);','   DCUpdate(newMainBar);\n   RBTick(newMainBar);')
    s=once(s,'         RecordFunnel(barTime,roundSignal,executionGate);',
        '''         RecordFunnel(barTime,roundSignal,executionGate);
         RBNewBar(rates,barTime);
         if(roundSignal) RBAdd(rates,barTime);
         if(InpRebreakMode==1){RBExecuteB(barTime);return;}
         if(roundSignal && !executionGate) RBExecLog(RBId(barTime),"A","SKIPPED",DetermineEntryState());''')
    s=once(s,'''            if(!CanOpenBucketTrade(bucket, baseOpenCount, pendingOpenCount))
               continue;
            if(OpenPosition(bucket))
               pendingOpenCount++;''',
        '''            if(!CanOpenBucketTrade(bucket, baseOpenCount, pendingOpenCount))
              {RBExecLog(RBId(barTime),"A","SKIPPED","BUCKET_GATE");continue;}
            bool rbOpened=OpenPosition(bucket);
            RBLogA(barTime,rbOpened);
            if(rbOpened) pendingOpenCount++;''')
    return s


def prepare(out,draft=False):
    if (out/'manifest.json').exists() and not draft:return verify(out)
    assert not (out/'runs').exists(),'Do not rewrite a launched experiment'
    parent=verify(PARENT);frozen=out/'frozen';frozen.mkdir(parents=True,exist_ok=True)
    core_path=ROOT/'mql/Include/Research/WickRebreakCore.mqh'
    study_path=ROOT/'mql/Include/Research/WickRebreakStudy.mqh'
    core=core_path.read_text(encoding='utf-8')
    body=once(study_path.read_text(encoding='utf-8'),'#include "WickRebreakCore.mqh"',core)
    original=(ROOT/parent['sources']['m5_adjusted']).read_text(encoding='utf-8')
    updated=adapt(original,body)
    local_base=(ROOT/'mql/Experts/Research/RelativeM5VolumeAdjustmentDiagnostics.mq5').read_text(encoding='utf-8')
    local_path=ROOT/'mql/Experts/Research/RelativeM5WickRebreakStudy.mq5'
    local_path.write_text(adapt(local_base,'#include "../../Include/Research/WickRebreakStudy.mqh"'),encoding='utf-8')
    harness_path=ROOT/'mql/Experts/tests/WickRebreakHarness.mq5'
    harness=once(harness_path.read_text(encoding='utf-8'),'#include "../../Include/Research/WickRebreakCore.mqh"',core)
    sources={}
    for key,value in [('reference',original),('wick_rebreak',updated),('harness',harness)]:
        p=frozen/(key+'.mq5');p.write_text(value,encoding='utf-8');sources[key]=str(p.relative_to(ROOT))
    (out/'study_changes.diff').write_text(''.join(difflib.unified_diff(original.splitlines(True),updated.splitlines(True),fromfile='risk_adjustment_on',tofile='wick_rebreak')),encoding='utf-8')
    symbols=['USDJPY','EURUSD','XAUUSD'];runs=[]
    save(frozen/'harness.json',dict(InpTelemetryFileName='rebreak_harness.csv'))
    runs.append(dict(run_id='harness',expert='harness',kind='harness',symbol='USDJPY',inputs='harness.json',timeframe='M5',date_from='2023.01.02',date_to='2023.01.04'))
    for symbol in symbols:
        old=json.loads((PARENT/'frozen'/f'{symbol}_on.json').read_text())
        for arm in ['reference','A','B']:
            vals=dict(old)
            if arm!='reference':vals.update(InpRebreakMode='0' if arm=='A' else '1',InpRebreakWaitBars='18')
            save(frozen/f'{symbol}_{arm}.json',vals)
            runs.append(dict(run_id=f'qa_{symbol}_{arm}',expert='reference' if arm=='reference' else 'wick_rebreak',kind='m5',phase='qa',arm=arm,symbol=symbol,inputs=f'{symbol}_{arm}.json',timeframe='M5',date_from='2023.01.01',date_to='2023.04.01'))
    for year in [2023,2024,2025,2026]:
        for symbol in symbols:
            for arm in ['A','B']:
                runs.append(dict(run_id=f'y{year}_{symbol}_{arm}',expert='wick_rebreak',kind='m5',phase='known_validation',arm=arm,symbol=symbol,inputs=f'{symbol}_{arm}.json',timeframe='M5',date_from=f'{year}.01.01',date_to=f'{year+1}.01.01' if year<2026 else '2026.10.01'))
    runner=(ROOT/'scripts/run-risk-adjustment.ps1').read_text(encoding='utf-8')
    for a,b in [('portable_risk_adjustment_20261012','wick_rebreak_20261013'),('prepare_risk_adjustment.py','prepare_wick_rebreak.py'),('analyze_risk_adjustment.py','analyze_wick_rebreak.py'),('PORTABLE_RISK_ADJUSTMENT_QA','WICK_REBREAK_ENTRY_STUDY'),('CodexMT5RiskAdjustment','CodexMT5WickRebreak'),('Port=39061','Port=39071')]:runner=runner.replace(a,b)
    runner=once(runner,"@('.adjustment.csv'","@('.rb_candidates.csv','.rb_events.csv','.rb_entries.csv','.rb_outcomes.csv','.rb_context.csv','.rb_execution.csv','.rb_bars.csv','.path.csv','.adjustment.csv'")
    runner=once(runner,"Model=4","Model=0") # Explicit generated-tick experiment; actual quality still audited.
    runner=once(runner,"if(!$Execute -and !$CompileOnly)","if($Execute -and $manifest.status -ne 'LOCKED'){throw 'Study is not locked'}\nif(!$Execute -and !$CompileOnly)")
    runner_path=ROOT/'scripts/run-wick-rebreak.ps1';runner_path.write_text(runner,encoding='utf-8')
    files=[core_path,study_path,harness_path,local_path,runner_path]+list(frozen.iterdir())
    files += [ROOT/'tools/quality12b'/name for name in ['prepare_wick_rebreak.py','analyze_wick_rebreak.py','test_wick_rebreak.py']]
    hashes=dict(parent['hashes']);hashes.update({str(p.relative_to(ROOT)):sha(p) for p in files})
    m=dict(purpose='WICK_REBREAK_ENTRY_STUDY',sources=sources,runs=runs,hashes=hashes,preserved=parent['preserved'],symbols=symbols,
           expected_server=parent['expected_server'],expected_broker=parent['expected_broker'],parent_sha256=sha(PARENT/'manifest.json'),
           status='DRAFT_PREFLIGHT' if draft else 'LOCKED',known_periods=True,
           rule='A immediate; B strict later M5 close above fixed signal high within 18 bars; invalidate on Bid below frozen confirmed M5 low; no retries; same entry-time ATR exit/risk rules; all candidates shadow')
    save(out/'manifest.json',m);return verify(out)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,default=DEFAULT);p.add_argument('--check',action='store_true');p.add_argument('--draft',action='store_true');p.add_argument('--lock',action='store_true');a=p.parse_args()
    m=verify(a.out.resolve()) if a.check or a.lock else prepare(a.out.resolve(),a.draft)
    if a.lock:
        assert not (a.out/'runs').exists(),'Cannot relock a launched study'
        m['status']='LOCKED';save(a.out/'manifest.json',m)
    print(json.dumps(dict(verified=True,runs=len(m['runs']),status=m['status'])))
