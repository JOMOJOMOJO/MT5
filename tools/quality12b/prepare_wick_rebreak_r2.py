"""Repair the history observer in a new immutable package, without strategy edits."""
import argparse
import difflib
import json
from pathlib import Path
from prepare_portable_audit import ROOT, once, save, sha, verify

PARENT = ROOT / 'reports/qa/wick_rebreak_20261013'
DEFAULT = ROOT / 'reports/qa/wick_rebreak_20261013_r2'
PREVIOUS_BATCH = PARENT / 'runs/20261013_190231_9763418e'


def revised_observer(old):
    new = once(old, 'datetime qeMinute=0;', 'datetime qeMinute=0,qeTestStart=0;')
    new = once(new, 'qeHaveBaseline=false;qeFinished=false;qeChanges=0;qeMinute=0;',
               'qeHaveBaseline=false;qeFinished=false;qeChanges=0;qeMinute=0;qeTestStart=TimeCurrent();')
    new = once(new, '"fingerprint","algorithm");',
               '"fingerprint","algorithm","test_start","test_end","test_count","test_first","test_last","test_months");')
    new = once(new, "datetime begin=D'2021.01.01 00:00:00',end=D'2023.03.31 23:59:59';", '''// The previous calendar year covers the preloaded warm-up. Nothing is read
   // for this fingerprint until OnTester, after all trading has finished.
   MqlDateTime start;TimeToStruct(qeTestStart,start);
   start.year--;start.mon=1;start.day=1;start.hour=0;start.min=0;start.sec=0;
   datetime begin=StructToTime(start),end=TimeCurrent();
   if(qeTestStart<=0 || end<qeTestStart){Print("QE_FATAL_HISTORY_CLOCK");return;}''')
    new = once(new, 'MqlRates rates[];int n=CopyRates(qeSymbols[i],tfs[t],begin,end,rates);',
               'MqlRates rates[];ArraySetAsSeries(rates,false);ResetLastError();\n        int n=CopyRates(qeSymbols[i],tfs[t],begin,end,rates);int error=GetLastError();')
    new = once(new, 'if(n<=0 || point<=0){Print("QE_FATAL_HISTORY ",qeSymbols[i]," ",EnumToString(tfs[t]));continue;}',
               '''if(n<=0 || point<=0){Print("QE_FATAL_HISTORY ",qeSymbols[i]," ",EnumToString(tfs[t]),
           " from=",TimeToString(begin)," to=",TimeToString(end)," count=",n," error=",error);continue;}
        int testCount=0,lastMonth=0;datetime testFirst=0,testLast=0;string months="";''')
    new = once(new, 'QEHash(hash,rates[j].tick_volume);QEHash(hash,rates[j].real_volume);QEHash(hash,rates[j].spread);',
               '''QEHash(hash,rates[j].tick_volume);QEHash(hash,rates[j].real_volume);QEHash(hash,rates[j].spread);
           if(rates[j].time>=qeTestStart && rates[j].time<=end)
             {
              if(testCount==0)testFirst=rates[j].time;
              testCount++;testLast=rates[j].time;
              MqlDateTime stamp;TimeToStruct(rates[j].time,stamp);int month=stamp.year*100+stamp.mon;
              if(month!=lastMonth){if(months!="")months+=",";months+=(string)month;lastMonth=month;}
             }''')
    new = once(new, 'StringFormat("%I64u",hash),"FNV64_INTEGER_WORDS_POINT_SCALED_OHLC_VOLUME_SPREAD");',
               '''StringFormat("%I64u",hash),"FNV64_INTEGER_WORDS_POINT_SCALED_OHLC_VOLUME_SPREAD",
                  (long)qeTestStart,(long)end,testCount,(long)testFirst,(long)testLast,months);''')
    return new


def prepare(out, draft=False):
    if (out/'manifest.json').exists() and not draft:
        return verify(out)
    assert not (out/'runs').exists(), 'Cannot rewrite a launched experiment'
    parent = verify(PARENT)
    old_path = ROOT/'mql/Include/Research/PortableEnvironmentAuditV2.mqh'
    old = old_path.read_text(encoding='utf-8')
    new = revised_observer(old)
    observer = ROOT/'mql/Include/Research/PortableEnvironmentAuditV3.mqh'
    observer.write_text(new, encoding='utf-8')
    frozen = out/'frozen'; frozen.mkdir(parents=True, exist_ok=True)
    sources = {}
    for key, source in parent['sources'].items():
        text = (ROOT/source).read_text(encoding='utf-8')
        revised = text if key == 'harness' else once(text, old, new)
        target = frozen/(key+'.mq5'); target.write_text(revised, encoding='utf-8')
        sources[key] = str(target.relative_to(ROOT))
        (out/(key+'_observer.diff')).write_text(''.join(difflib.unified_diff(
            text.splitlines(True), revised.splitlines(True), fromfile='r1/'+key, tofile='r2/'+key)), encoding='utf-8')
    for source in (PARENT/'frozen').glob('*.json'):
        (frozen/source.name).write_bytes(source.read_bytes())
    # Same 34 runs; move the formerly failing case first to expose the repair early.
    runs = list(parent['runs'])
    failure = next(r for r in runs if r['run_id'] == 'y2025_USDJPY_A')
    runs.remove(failure); runs.insert(1, failure)
    runner = (ROOT/'scripts/run-wick-rebreak.ps1').read_text(encoding='utf-8')
    for a,b in [('wick_rebreak_20261013','wick_rebreak_20261013_r2'),
                ('prepare_wick_rebreak.py','prepare_wick_rebreak_r2.py'),
                ('analyze_wick_rebreak.py','analyze_wick_rebreak_r2.py'),
                ('WICK_REBREAK_ENTRY_STUDY','WICK_REBREAK_ENTRY_STUDY_R2'),
                ('CodexMT5WickRebreak','CodexMT5WickRebreakR2'),('Port=39071','Port=39081')]:
        runner = runner.replace(a,b)
    runner_path = ROOT/'scripts/run-wick-rebreak-r2.ps1'
    runner_path.write_text(runner, encoding='utf-8')
    files = [observer, runner_path, *frozen.iterdir()]
    files += [ROOT/'tools/quality12b'/name for name in [
        'prepare_wick_rebreak_r2.py','analyze_wick_rebreak_r2.py','test_wick_rebreak_r2.py']]
    hashes = dict(parent['hashes']); hashes.update({str(p.relative_to(ROOT)):sha(p) for p in files})
    old_artifacts = {}
    for spec in parent['runs']:
        folder = PREVIOUS_BATCH/spec['run_id']
        if not (folder/'report.htm').exists():
            continue
        for name in ['report.htm','runtime_before.json','runtime_after.json','cost.csv','environment.csv',
                     'risk.csv','adjustment.csv','funnel.csv','rb_candidates.csv','rb_events.csv','rb_entries.csv',
                     'rb_outcomes.csv','rb_context.csv','rb_execution.csv','rb_bars.csv']:
            path = folder/name
            if path.exists(): old_artifacts[str(path.relative_to(ROOT))] = sha(path)
    hashes.update(old_artifacts)
    manifest = dict(parent, purpose='WICK_REBREAK_ENTRY_STUDY_R2', sources=sources, runs=runs,
                    hashes=hashes, parent_sha256=sha(PARENT/'manifest.json'),
                    status='DRAFT_PREFLIGHT' if draft else 'LOCKED',
                    previous_batch=str(PREVIOUS_BATCH.relative_to(ROOT)),
                    observer_change='History range: prior calendar year through final observed test time; strict test-month coverage. Trading source unchanged.',
                    reuse_completed_runs=False)
    save(out/'manifest.json', manifest)
    return verify(out)


if __name__ == '__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,default=DEFAULT)
    p.add_argument('--check',action='store_true');p.add_argument('--draft',action='store_true');p.add_argument('--lock',action='store_true')
    a=p.parse_args();out=a.out.resolve()
    m=verify(out) if a.check or a.lock else prepare(out,a.draft)
    if a.lock:
        assert not (out/'runs').exists()
        m['status']='LOCKED';save(out/'manifest.json',m)
    print(json.dumps(dict(verified=True,runs=len(m['runs']),status=m['status'])))
