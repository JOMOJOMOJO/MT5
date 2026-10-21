"""Resume with unchanged MQL; retain closed matched QA groups, rerun unfinished pairs."""
import argparse
import json
from pathlib import Path
from prepare_portable_audit import ROOT, once, save, sha, verify

PARENT=ROOT/'reports/qa/wick_rebreak_20261013_r2'
DEFAULT=ROOT/'reports/qa/wick_rebreak_20261014_r3'
REUSE_BATCH=PARENT/'runs/20261013_200139_1849fb06'
REUSE_IDS=['harness','qa_USDJPY_reference','qa_USDJPY_A','qa_USDJPY_B']


def prepare(out,draft=False):
    if (out/'manifest.json').exists() and not draft:return verify(out)
    assert not (out/'runs').exists(),'Cannot rewrite a launched experiment'
    parent=verify(PARENT);frozen=out/'frozen';frozen.mkdir(parents=True,exist_ok=True)
    sources={}
    for key,source in parent['sources'].items():
        target=frozen/(key+'.mq5');target.write_bytes((ROOT/source).read_bytes())
        assert sha(target)==sha(ROOT/source)
        sources[key]=str(target.relative_to(ROOT))
    for p in (PARENT/'frozen').glob('*.json'):(frozen/p.name).write_bytes(p.read_bytes())
    # Original chronological run order; do not reuse an A arm whose B has not run.
    original=json.loads((ROOT/'reports/qa/wick_rebreak_20261013/manifest.json').read_text())
    runs=original['runs'];assert {r['run_id'] for r in runs}=={r['run_id'] for r in parent['runs']}
    reuse={};hashes=dict(parent['hashes'])
    for id in REUSE_IDS:
        folder=REUSE_BATCH/id
        assert json.loads((folder/'audit.json').read_text())['passed']
        reuse[id]=str(folder.relative_to(ROOT))
        for p in folder.rglob('*'):
            if p.is_file():hashes[str(p.relative_to(ROOT))]=sha(p)
    runner=(ROOT/'scripts/run-wick-rebreak-r2.ps1').read_text(encoding='utf-8')
    for a,b in [('wick_rebreak_20261013_r2','wick_rebreak_20261014_r3'),
                ('prepare_wick_rebreak_r2.py','prepare_wick_rebreak_r3.py'),
                ('analyze_wick_rebreak_r2.py','analyze_wick_rebreak_r3.py'),
                ('WICK_REBREAK_ENTRY_STUDY_R2','WICK_REBREAK_ENTRY_STUDY_R3'),
                ('CodexMT5WickRebreakR2','CodexMT5WickRebreakR3'),('Port=39081','Port=39091')]:runner=runner.replace(a,b)
    runner=once(runner,"  New-Item -ItemType Directory -Path $runOut -Force|Out-Null\n  $tag=",'''  New-Item -ItemType Directory -Path $runOut -Force|Out-Null
  $reuseProperty=$manifest.reuse_runs.PSObject.Properties[$runId]
  if($null -ne $reuseProperty){
   $reuseSource=Join-Path $repo $reuseProperty.Value
   foreach($reuseFile in Get-ChildItem -LiteralPath $reuseSource -Recurse -File){
    $reuseRelative=$reuseFile.FullName.Substring($reuseSource.Length+1)
    $reuseTarget=Join-Path $runOut $reuseRelative
    New-Item -ItemType Directory -Path (Split-Path -Parent $reuseTarget) -Force|Out-Null
    [IO.File]::Copy(('\\\\?\\'+$reuseFile.FullName),('\\\\?\\'+[IO.Path]::GetFullPath($reuseTarget)),$false)
   }
   SaveJson @{status='REAUDITING_REUSED';run_id=$runId;output=$output} (Join-Path $output 'status.json')
   & $python (Join-Path $repo 'tools\\quality12b\\analyze_wick_rebreak_r3.py') --run $runOut --run-id $runId --package $package
   if($LASTEXITCODE -ne 0){throw 'Reused run audit failed'}
   SaveJson @{source=$reuseProperty.Value;source_locked_in_manifest=$true;new_mt5_run=$false} (Join-Path $runOut 'reuse_provenance.json')
   Log "Re-audited reused run $runId"
   continue
  }
  $tag=''')
    runner=once(runner,"completed_runs=$manifest.runs.Count;output=$output;promotion='NOT_ASSESSED'",
                "completed_runs=$manifest.runs.Count;reused_runs=4;new_runs=30;output=$output;promotion='NOT_ASSESSED'")
    runner_path=ROOT/'scripts/run-wick-rebreak-r3.ps1';runner_path.write_text(runner,encoding='utf-8')
    files=[runner_path,*frozen.iterdir()]
    files += [ROOT/'tools/quality12b'/n for n in ['prepare_wick_rebreak_r3.py','analyze_wick_rebreak_r3.py','test_wick_rebreak_r3.py']]
    hashes.update({str(p.relative_to(ROOT)):sha(p) for p in files})
    m=dict(parent,purpose='WICK_REBREAK_ENTRY_STUDY_R3',sources=sources,runs=runs,hashes=hashes,
           parent_sha256=sha(PARENT/'manifest.json'),status='DRAFT_PREFLIGHT' if draft else 'LOCKED',reuse_runs=reuse,
           reuse_completed_runs=True,audit_change='Historical swap drift separated from current paired environment equivalence; exact outputs required; no MQL changes')
    save(out/'manifest.json',m);return verify(out)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,default=DEFAULT)
    p.add_argument('--check',action='store_true');p.add_argument('--draft',action='store_true');p.add_argument('--lock',action='store_true')
    a=p.parse_args();out=a.out.resolve();m=verify(out) if a.check or a.lock else prepare(out,a.draft)
    if a.lock:
        assert not (out/'runs').exists();m['status']='LOCKED';save(out/'manifest.json',m)
    print(json.dumps(dict(verified=True,runs=len(m['runs']),reused=4,new=30,status=m['status'])))
