"""Freeze an observational M5 study; existing source and inputs stay unchanged."""
import difflib
import hashlib
import json
from pathlib import Path
from prepare_m5_context import once

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/qa/m5_multitf_diagnostics_20261007'
BASE=ROOT/'reports/qa/rc_search_20261007'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def prepare():
    if OUT.exists():raise SystemExit('Refuse overwrite of frozen package')
    original=(BASE/'frozen/quality12b_snapshot.mq5').read_text()
    core=(ROOT/'mql/Include/M15Environment.mqh').read_text(encoding='utf-8-sig')
    generic=core.replace('M15_ENVIRONMENT_CORE','HTF_RESEARCH_ENVIRONMENT_CORE').replace('M15EnvPivot','HTFResearchPivot').replace('M15EnvSnapshot','HTFResearchSnapshot').replace('CM15Environment','CHTFResearchEnvironment')
    generic=generic.replace('const int i)','const int i,const int seconds)').replace('r[i].time+900','r[i].time+seconds')
    prior=(ROOT/'reports/qa/quality12b_context_exit_20261006/frozen/HTFResearchEnvironment.mqh').read_text()
    assert generic==prior,'Generic core must preserve prior research definition exactly'
    hook=(ROOT/'mql/Include/Research/RelativeMultiTFDiagnostics.mqh').read_text()
    s=once(original,'bool PersistRiskState()',core+'\n'+generic+'\n'+hook+'\nbool PersistRiskState()')
    s=once(s,'int OnInit()\n  {','int OnInit()\n  {\n   if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;')
    s=once(s,'   RefreshOperatorMode();\n   WriteStatusSnapshot();\n   return INIT_SUCCEEDED;',
       '   if(!DCOpen()) return INIT_FAILED;\n   RefreshOperatorMode();\n   WriteStatusSnapshot();\n   return INIT_SUCCEEDED;')
    s=once(s,'   CloseTelemetryFile();','   DCClose();\n   CloseTelemetryFile();')
    s=once(s,'   if(!InpWriteFunnel) return;','   if(signal) DCCandidate(barTime,gate);\n   if(!InpWriteFunnel) return;')
    marker='void RegisterEntryDeal(datetime dealTime, string side, double price, double volume)\n  {'
    s=once(s,marker,marker+'\n   DCEntry(dealTime,price);')
    s=once(s,'   bool newMainBar = IsNewBar(barTime);','   bool newMainBar = IsNewBar(barTime);\n   DCUpdate(newMainBar);')
    target=ROOT/'mql/Experts/Research/RelativeM5MultiTFDiagnostics.mq5';assert not target.exists()
    target.write_text(s,encoding='utf-8')
    frozen=OUT/'frozen';frozen.mkdir(parents=True)
    (frozen/'quality12b_snapshot.mq5').write_text(s,encoding='utf-8')
    (frozen/'M15Environment.mqh').write_text(core,encoding='utf-8')
    (frozen/'HTFResearchEnvironment.mqh').write_text(generic,encoding='utf-8')
    values=json.loads((BASE/'frozen/inputs.json').read_text())
    values.update(InpSignalTimeframe='5',InpMaxSpreadAtr='0.2',InpStopLossAtr='2.2',InpTargetRMultiple='1.5')
    assert values['InpRiskPercent']=='0.65' and values['InpMaxHoldBars']=='18'
    (frozen/'inputs.json').write_text(json.dumps(values,indent=2)+'\n')
    (frozen/'quality12b_full.set').write_text('\n'.join(f'{k}={v}' for k,v in values.items())+'\n')
    old=ROOT/'reports/qa/m5_m15_context_20261007/runs/20261007_133107_b26b2e57'
    def run(ident,stage,start,end,tf='M5',reference=None):
        r=dict(run_id=ident,stage=stage,date_from=start,date_to=end,timeframe=tf,label='KNOWN_PERIOD_DIAGNOSTIC_NOT_OOS',
               overrides={'InpSignalTimeframe':'15'} if tf=='M15' else {})
        if reference:r.update(reference_report=str(reference.relative_to(ROOT)),reference_sha256=digest(reference))
        return r
    runs=[run('m15_parity','Control','2025.01.01','2026.10.01','M15',BASE/'runs/20261007_094431_0d639534/validate_c10/report.htm'),
          run('m5_smoke_parity','Control','2026.09.01','2026.10.01',reference=old/'smoke_m5/report.htm'),
          run('known_2023_2024','Observe','2023.01.01','2025.01.01',reference=old/'search_fixed_1p5/report.htm'),
          run('known_2025_2026','Observe','2025.01.01','2026.10.01')]
    manifest=json.loads((BASE/'manifest.json').read_text())
    manifest.update(purpose='M5_MULTITF_DIAGNOSTICS',source=str(target.relative_to(ROOT)),source_sha256=digest(target),
        input_count=len(values),timeframe='M5',runs=runs,analysis_sha256=digest(ROOT/'tools/quality12b/analyze_multitf_diagnostics.py'),
        sha256={p.relative_to(OUT).as_posix():digest(p) for p in frozen.iterdir()})
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (OUT/'research_hooks.diff').write_text(''.join(difflib.unified_diff(original.splitlines(True),s.splitlines(True),fromfile='relative_v2_frozen',tofile='multitf_observer')))
    print('Frozen 4 runs, including 3 execution parity comparisons. No MT5 launched.')

if __name__=='__main__':prepare()
