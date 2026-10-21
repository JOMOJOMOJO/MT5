"""Freeze M5 execution / M15 policies before results. Never edits production."""
import hashlib
import json
import difflib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/qa/m5_m15_context_20261007'
BASE=ROOT/'reports/qa/rc_search_20261007'

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def once(s,a,b):
    assert s.count(a)==1,(a,s.count(a))
    return s.replace(a,b,1)

def prepare():
    if OUT.exists():raise SystemExit('Frozen package already exists; refuse overwrite')
    original=(BASE/'frozen/quality12b_snapshot.mq5').read_text()
    core=(ROOT/'mql/Include/M15Environment.mqh').read_text(encoding='utf-8-sig')
    hook=(ROOT/'mql/Include/Research/RelativeM5Context.mqh').read_text()
    s=once(original,'bool PersistRiskState()',core+'\n'+hook+'\nbool PersistRiskState()')
    s=once(s,'int OnInit()\n  {','int OnInit()\n  {\n   if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;')
    s=once(s,'   RefreshOperatorMode();\n   WriteStatusSnapshot();\n   return INIT_SUCCEEDED;',
           '   if(!MCOpen()) return INIT_FAILED;\n   RefreshOperatorMode();\n   WriteStatusSnapshot();\n   return INIT_SUCCEEDED;')
    s=once(s,'   CloseTelemetryFile();','   MCClose();\n   CloseTelemetryFile();')
    s=once(s,'   if(!InpWriteFunnel) return;', '   if(signal) MCCandidate(barTime,gate);\n   if(!InpWriteFunnel) return;')
    s=once(s,'   MqlTick quote;','   if(!MCBeforeOrder(targetRMultiple)) return false;\n   MqlTick quote;')
    marker='void RegisterEntryDeal(datetime dealTime, string side, double price, double volume)\n  {'
    s=once(s,marker,marker+'\n   MCEntry(dealTime,price);')
    target=ROOT/'mql/Experts/Research/RelativeM5M15Context.mq5';assert not target.exists()
    target.write_text(s,encoding='utf-8')
    frozen=OUT/'frozen';frozen.mkdir(parents=True)
    (frozen/'quality12b_snapshot.mq5').write_text(s)
    (frozen/'M15Environment.mqh').write_text(core)
    values=json.loads((BASE/'frozen/inputs.json').read_text())
    values.update(InpSignalTimeframe='5',InpMaxSpreadAtr='0.2',InpStopLossAtr='2.2',InpTargetRMultiple='1.5',InpM15ResearchPolicy='0')
    (frozen/'inputs.json').write_text(json.dumps(values,indent=2)+'\n')
    (frozen/'quality12b_full.set').write_text('\n'.join(f'{k}={v}' for k,v in values.items())+'\n')
    policies=[('fixed_1',0,'1.0',18),('fixed_1p5',0,'1.5',18),('fixed_2',0,'2.0',18),
              ('up_only',1,'1.5',18),('non_down',2,'1.5',18),('up2_range1',3,'1.5',18),
              ('hold270_control',0,'1.5',54)]
    prior=BASE/'runs/20261007_094431_0d639534/validate_c10/report.htm'
    runs=[dict(run_id='m15_parity',stage='Control',date_from='2025.01.01',date_to='2026.10.01',timeframe='M15',
               label='OBSERVER_PARITY_CONTROL',overrides={'InpSignalTimeframe':'15'},reference_report=str(prior.relative_to(ROOT)),reference_sha256=digest(prior)),
          dict(run_id='smoke_m5',stage='Smoke',date_from='2026.09.01',date_to='2026.10.01',timeframe='M5',label='M5_ENGINEERING_SMOKE',overrides={})]
    for stage,start,end in [('Search','2023.01.01','2025.01.01'),('Validate','2025.01.01','2026.10.01')]:
        for name,policy,rr,hold in policies:
            runs.append(dict(run_id=stage.lower()+'_'+name,stage=stage,cell=name,date_from=start,date_to=end,
                             timeframe='M5',label='KNOWN_PERIOD_NOT_OOS',overrides=dict(InpM15ResearchPolicy=str(policy),InpTargetRMultiple=rr,InpMaxHoldBars=str(hold))))
    manifest=json.loads((BASE/'manifest.json').read_text())
    manifest.update(purpose='M5_M15_CONTEXT_RESEARCH',source=str(target.relative_to(ROOT)),source_sha256=digest(target),
                    input_count=len(values),timeframe='M5',runs=runs,
                    analysis_sha256=digest(ROOT/'tools/quality12b/analyze_m5_context.py'),
                    sha256={p.relative_to(OUT).as_posix():digest(p) for p in frozen.iterdir()})
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (OUT/'research_hooks.diff').write_text(''.join(difflib.unified_diff(original.splitlines(True),s.splitlines(True),fromfile='relative_v2_frozen',tofile='m5_m15_research')))
    print(f'Prepared {len(runs)} fixed runs; no MT5 launched')

if __name__=='__main__':prepare()
