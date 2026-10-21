"""Fix first-snapshot initialization without mutating any previously frozen source."""
import argparse,difflib,json,shutil
from pathlib import Path
from prepare_portable_audit import ROOT,verify,once,save,sha

DEFAULT=ROOT/'reports/qa/portable_audit_20261009_r4'
PARENT=ROOT/'reports/qa/portable_audit_20261009_r3'

def prepare(out):
    if (out/'manifest.json').exists():return verify(out)
    parent=verify(PARENT);frozen=out/'frozen';frozen.mkdir(parents=True,exist_ok=True)
    original=(ROOT/'mql/Include/Research/PortableEnvironmentAudit.mqh').read_text(encoding='utf-8')
    env=once(original,'bool qeFinished=false;','bool qeFinished=false,qeHaveBaseline=false;\nint qeChanges=0;')
    env=once(env,'bool changed=qePrevious[i]!="" && qePrevious[i]!=value;','bool changed=qeHaveBaseline && qePrevious[i]!=value;')
    env=once(env,'if(changed){QEWriteSpec','if(changed){qeChanges++;QEWriteSpec')
    env=once(env,'      qePrevious[i]=value;\n     }\n  }','      qePrevious[i]=value;\n     }\n   qeHaveBaseline=true;\n  }')
    env=once(env,'   ArrayResize(qePrevious,n);','   ArrayResize(qePrevious,n);\n   for(int i=0;i<n;i++)qePrevious[i]="";\n   qeHaveBaseline=false;qeFinished=false;qeChanges=0;qeMinute=0;')
    inc=ROOT/'mql/Include/Research/PortableEnvironmentAuditV2.mqh';inc.write_text(env,encoding='utf-8')
    (out/'observer_initialization.diff').write_text(''.join(difflib.unified_diff(original.splitlines(True),env.splitlines(True),fromfile='environment_r3',tofile='environment_r4')),encoding='utf-8')
    sources={}
    for name,rel in parent['sources'].items():
        s=(ROOT/rel).read_text(encoding='utf-8')
        if name=='portable_harness':
            s=env+'\n'+s
            s=once(s,'   QAContext();','''   QAContext();
   bool opened=QEStart(_Symbol,InpTelemetryFileName);
   QACheck("ENV_INITIAL_IS_BASELINE",opened && qeHaveBaseline && qeChanges==0);
   QEObserve("VERIFY_UNCHANGED");
   QACheck("ENV_UNCHANGED_IS_NOT_CHANGE",opened && qeChanges==0);
   string initial=qePrevious[0];qePrevious[0]="INJECTED_DIFFERENCE_FOR_FIXTURE";
   QEObserve("VERIFY_CHANGE");
   QACheck("ENV_REAL_DIFFERENCE_DETECTED",opened && qeChanges==1 && qePrevious[0]==initial);
   QEClose();''')
        else:s=once(s,original,env)
        dest=frozen/(name+'.mq5');dest.write_text(s,encoding='utf-8');sources[name]=str(dest.relative_to(ROOT))
    for p in (PARENT/'frozen').glob('*.json'):shutil.copyfile(p,frozen/p.name)
    files=[inc,ROOT/'tools/quality12b/prepare_portable_audit_r4.py',ROOT/'tools/quality12b/analyze_portable_audit_r4.py',
           ROOT/'tools/quality12b/test_portable_audit_r4.py',ROOT/'scripts/run-portable-audit-r4.ps1']
    hashes=dict(parent['hashes']);hashes.update({str(p.relative_to(ROOT)):sha(p) for p in files+list(frozen.iterdir())})
    save(out/'manifest.json',dict(parent,revision=4,sources=sources,hashes=hashes,
         parent_manifest=str((PARENT/'manifest.json').relative_to(ROOT)),parent_manifest_sha256=sha(PARENT/'manifest.json'),
         change='Explicit observer baseline lifecycle; 3 MQL lifecycle regression tests; trading code and all run settings unchanged'))
    return verify(out)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,default=DEFAULT);p.add_argument('--check',action='store_true');a=p.parse_args()
    m=verify(a.out.resolve()) if a.check else prepare(a.out.resolve());print(json.dumps(dict(verified=True,revision=4,runs=len(m['runs']))))
