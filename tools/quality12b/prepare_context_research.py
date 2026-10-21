"""Freeze causal context observer and fixed exit comparisons. No live EA edits."""
import difflib
import json
from pathlib import Path
from prepare_revalidation import ROOT,digest,verify
from prepare_spread_diagnosis import once

BASE=ROOT/'reports/qa/quality12b_revalidation_20261005'
OUT=ROOT/'reports/qa/quality12b_context_exit_20261006'
PRIOR=BASE/'runs/20261005_120836_15208538'


def prepare():
    if (OUT/'manifest.json').exists():return verify(OUT)
    original=(BASE/'frozen/quality12b_snapshot.mq5').read_text(encoding='utf-8-sig')
    core=(ROOT/'mql/Include/M15Environment.mqh').read_text(encoding='utf-8-sig')
    generic=core.replace('M15_ENVIRONMENT_CORE','HTF_RESEARCH_ENVIRONMENT_CORE').replace('M15EnvPivot','HTFResearchPivot').replace('M15EnvSnapshot','HTFResearchSnapshot').replace('CM15Environment','CHTFResearchEnvironment')
    generic=once(generic,'const int i)','const int i,const int seconds)')
    generic=once(generic,'r[i].time+900','r[i].time+seconds')
    collector=(ROOT/'mql/Include/Research/Quality12bContextCollector.mqh').read_text(encoding='utf-8-sig')
    source=once(original,'double GetCurrentSpreadPips()',core+'\n'+generic+'\n'+collector+'\ndouble GetCurrentSpreadPips()')
    source=once(source,'int OnInit()\n  {','int OnInit()\n  {\n   if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;')
    source=once(source,'   CloseTelemetryFile();','   CloseTelemetryFile();\n   QCClose();')
    source=once(source,'   bool newMainBar = IsNewBar(barTime);','   bool newMainBar = IsNewBar(barTime);\n   QCUpdate(newMainBar);')
    marker='void RegisterEntryDeal(datetime dealTime, string side, double price, double volume)\n  {'
    source=once(source,marker,marker+'\n   QCStart(dealTime,price);')
    target=ROOT/'mql/Experts/Research/Quality12bContextResearch.mq5'
    assert not target.exists()
    target.write_text(source,encoding='utf-8')
    (OUT/'frozen').mkdir(parents=True)
    (OUT/'frozen/quality12b_snapshot.mq5').write_bytes(target.read_bytes())
    (OUT/'frozen/M15Environment.mqh').write_text(core,encoding='utf-8')
    (OUT/'frozen/HTFResearchEnvironment.mqh').write_text(generic,encoding='utf-8')
    for name in ('inputs.json','quality12b_full.set'):(OUT/'frozen'/name).write_bytes((BASE/'frozen'/name).read_bytes())
    (OUT/'instrumentation.diff').write_text(''.join(difflib.unified_diff(original.splitlines(True),source.splitlines(True),fromfile='baseline',tofile='context_observer')),encoding='utf-8')
    manifest=json.loads((BASE/'manifest.json').read_text(encoding='utf-8'))
    runs=[]
    for spec in manifest['runs']:
        if spec['run_id']=='reproduce_train':continue
        r=dict(spec);r['stage']='Extend';r['label']='KNOWN_DATA_CONTEXT_RESEARCH_NOT_OOS'
        r['reference_report']=str((PRIOR/r['run_id']/'report.htm').relative_to(ROOT))
        r['reference_sha256']=digest(ROOT/r['reference_report']);runs.append(r)
    manifest.update(created='2026-10-06',purpose='CONTEXT_EXIT_RESEARCH',source=str(target.relative_to(ROOT)),
                    source_sha256=digest(target),baseline_source_sha256=digest(BASE/'frozen/quality12b_snapshot.mq5'),
                    source_identity_note='Observer only; baseline entries and exits unchanged; shared core frozen not edited.',
                    reference_reports=[],runs=runs,sha256={},
                    context_analysis_sha256=digest(ROOT/'tools/quality12b/analyze_context_research.py'))
    for p in list((OUT/'frozen').iterdir())+[OUT/'instrumentation.diff']:
        manifest['sha256'][p.relative_to(OUT).as_posix()]=digest(p)
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print('Prepared',len(runs),'runs:',OUT)


if __name__=='__main__':prepare()
