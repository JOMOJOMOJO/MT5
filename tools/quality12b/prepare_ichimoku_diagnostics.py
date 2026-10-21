"""Freeze only observational Ichimoku additions to the completed M5 study."""
import difflib,hashlib,json
from pathlib import Path
from prepare_m5_context import once

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'reports/qa/m5_multitf_diagnostics_20261007'
OUT=ROOT/'reports/qa/m5_ichimoku_diagnostics_20261007'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def prepare():
    if OUT.exists():raise SystemExit('Frozen package exists; refuse overwrite')
    old=(BASE/'frozen/quality12b_snapshot.mq5').read_text()
    hook=(ROOT/'mql/Include/Research/RelativeIchimokuDiagnostics.mqh').read_text()
    changes=[('bool DCOpen()',hook+'\nbool DCOpen()'),
        ('   return true;\n  }\n\nvoid DCLoad','   return ICOpen();\n  }\n\nvoid DCLoad'),
        ('      env.Snapshot(when,price,dcPlan[t]);','      ICLoad(r,dcCounts[t],t,when);\n      env.Snapshot(when,price,dcPlan[t]);'),
        ('void DCWrite(const string stage,const datetime when,const double price,const bool gate)\n  {',
         'void DCWrite(const string stage,const datetime when,const double price,const bool gate)\n  {\n   ICWrite(stage,when,price);'),
        ('void DCClose()\n  {','void DCClose()\n  {\n   ICClose();')]
    source=old
    for a,b in changes:source=once(source,a,b)
    restored=source
    for a,b in reversed(changes):restored=once(restored,b,a)
    assert restored==old
    target=ROOT/'mql/Experts/Research/RelativeM5IchimokuDiagnostics.mq5';assert not target.exists()
    target.write_text(source,encoding='utf-8')
    frozen=OUT/'frozen';frozen.mkdir(parents=True)
    for name in ('inputs.json','quality12b_full.set','M15Environment.mqh','HTFResearchEnvironment.mqh'):
        (frozen/name).write_bytes((BASE/'frozen'/name).read_bytes())
    (frozen/'quality12b_snapshot.mq5').write_text(source,encoding='utf-8')
    prior=BASE/'runs/20261007_134859_995aab81'
    manifest=json.loads((BASE/'manifest.json').read_text());runs=[]
    for run in manifest['runs']:
        if run['run_id']=='m15_parity':continue
        run.update(reference_report=str((prior/run['run_id']/'report.htm').relative_to(ROOT)),
                   reference_sha256=digest(prior/run['run_id']/'report.htm'))
        runs.append(run)
    manifest.update(purpose='M5_ICHIMOKU_DIAGNOSTICS',source=str(target.relative_to(ROOT)),source_sha256=digest(target),runs=runs,
        analysis_sha256=digest(ROOT/'tools/quality12b/analyze_ichimoku_diagnostics.py'),
        sha256={p.relative_to(OUT).as_posix():digest(p) for p in frozen.iterdir()})
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (OUT/'research_hooks.diff').write_text(''.join(difflib.unified_diff(old.splitlines(True),source.splitlines(True),fromfile='previous_observer',tofile='ichimoku_observer')))
    (OUT/'source_parity.json').write_text(json.dumps(dict(removing_new_observer_recovers_exact_previous_source=True,inputs_unchanged=True)))
    print('Prepared 3 runs. Ichimoku observation only. No MT5 launched.')

if __name__=='__main__':prepare()
