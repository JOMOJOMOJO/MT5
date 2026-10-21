"""Lossless source decomposition, with byte-for-byte reassembly verification."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'mql/Experts/usdjpy_20260402_round_continuation_long.mq5'
BASE=ROOT/'reports/qa/quality12b_revalidation_20261005/frozen/quality12b_snapshot.mq5'
OUT=ROOT/'reports/qa/quality12b_refactor_20261006'
INCLUDE=ROOT/'mql/Include/Quality12b'
SECTIONS=[('Configuration','struct PivotPoint'),('RuntimeRisk','string TrimSpaces('),
          ('MarketData','bool LoadSignalWindow('),('PositionManagement','int CountManagedPositions('),
          ('PriceStructure','bool IsPivotHigh('),('Signals','bool EvaluateRoundSignal('),
          ('Orders','bool OpenPosition('),('TelemetryControl','bool OpenTelemetryFile(')]
END='int OnInit()'


def sha(b):return hashlib.sha256(b).hexdigest()


def reassemble(data):
    # Only our eight new quoted includes are expanded. Standard Trade include stays intact.
    used=[]
    def expand(m):
        name=m[1].decode('ascii')
        p=INCLUDE/(name+'.mqh')
        body=p.read_bytes()
        prefix=('// QUALITY12B_MODULE_BEGIN '+name+'\n#ifndef QUALITY12B_'+name.upper()+'_MQH\n#define QUALITY12B_'+name.upper()+'_MQH\n').encode()
        suffix=('// QUALITY12B_MODULE_END '+name+'\n#endif\n').encode()
        assert body.startswith(prefix) and body.endswith(suffix),name
        used.append(name)
        return body[len(prefix):-len(suffix)]
    restored=re.sub(rb'#include "\.\./Include/Quality12b/(\w+)\.mqh"\n',expand,data)
    assert used==[n for n,_ in SECTIONS]
    return restored,used


def verify():
    data=SOURCE.read_bytes()
    restored,used=reassemble(data)
    baseline=BASE.read_bytes()
    assert restored==baseline,'Refactor changes source semantics/text after include reassembly'
    assert not re.search(rb'\b__(?:FILE|LINE|PATH)__\b',baseline),'File/line macros require separate audit'
    inputs=re.findall(rb'^input\s+\w+\s+(Inp\w+)\s*=',restored,re.M)
    result=dict(passed=True,reassembled_byte_identical=True,baseline_sha256=sha(baseline),
                reassembled_sha256=sha(restored),input_count=len(inputs),modules=used,
                main_lines=len(data.splitlines()),original_lines=len(baseline.splitlines()),
                changed_logic=False,scope='Exact source text after expanding local modules; no claim of EX5 byte identity or new backtest performance.')
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'source_equivalence.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result))


def refactor():
    baseline=BASE.read_bytes()
    assert SOURCE.read_bytes()==baseline,'Current EA differs from reviewed baseline; preserve user edits'
    assert not INCLUDE.exists(),'Preserve existing module directory'
    for n,_ in SECTIONS:assert ('QUALITY12B_'+n.upper()+'_MQH').encode() not in baseline
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'before.mq5').write_bytes(baseline)
    INCLUDE.mkdir(parents=True)
    starts=[baseline.index(marker.encode()) for _,marker in SECTIONS]+[baseline.index(END.encode())]
    assert starts==sorted(starts)
    parts=[baseline[:starts[0]]]
    for i,(name,_) in enumerate(SECTIONS):
        body=baseline[starts[i]:starts[i+1]]
        prefix=('// QUALITY12B_MODULE_BEGIN '+name+'\n#ifndef QUALITY12B_'+name.upper()+'_MQH\n#define QUALITY12B_'+name.upper()+'_MQH\n').encode()
        suffix=('// QUALITY12B_MODULE_END '+name+'\n#endif\n').encode()
        (INCLUDE/(name+'.mqh')).write_bytes(prefix+body+suffix)
        parts.append(('#include "../Include/Quality12b/'+name+'.mqh"\n').encode())
    parts.append(baseline[starts[-1]:])
    SOURCE.write_bytes(b''.join(parts))
    verify()


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');a=p.parse_args()
    (refactor if a.apply else verify)()
