"""Freeze 18 cells and two fixed periods; do not inspect outcomes or launch MT5."""
import hashlib
import itertools
import json
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/qa/rc_search_20261007'

def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def prepare():
    if OUT.exists(): raise SystemExit('Frozen package already exists; do not overwrite/reselect')
    main=ROOT/'mql/Experts/RelativeContinuation.mq5'
    source=main.read_text(encoding='utf-8')
    source=re.sub(r'#include "../Include/RelativeContinuation/(\w+\.mqh)"',
                  lambda m:(ROOT/'mql/Include/RelativeContinuation'/m[1]).read_text(encoding='utf-8'),source)
    values={}
    for typ,name,value in re.findall(r'^input\s+(\w+)\s+(Inp\w+)\s*=\s*([^;]+);',source,re.M):
        value=value.strip().strip('"')
        if typ=='ENUM_TIMEFRAMES': value={'PERIOD_M15':'15','PERIOD_M5':'5'}[value]
        if typ=='double': value=str(float(value))
        values[name]=value
    values.update(InpSymbol='USDJPY',InpMinWindowRangeAtr='1.5',InpEnableTelemetry='true',
                  InpWriteFunnel='true',InpAllowParallelBuckets='false',InpMaxOpenPositions='1',
                  InpEnableOperatorControl='false',InpEnableStatusSnapshot='false')
    runs=[dict(run_id='smoke',stage='Smoke',date_from='2026.09.01',date_to='2026.09.08',label='ENGINEERING_SMOKE',overrides={})]
    cells=[]
    for i,(spread,sl,rr) in enumerate(itertools.product((0.10,0.20,0.30),(1.5,2.2,3.0),(1.0,1.5)),1):
        cells.append(dict(cell=f'c{i:02}',overrides=dict(InpMaxSpreadAtr=str(spread),InpStopLossAtr=str(sl),InpTargetRMultiple=str(rr))))
    for stage,start,end in [('Search','2023.01.01','2025.01.01'),('Validate','2025.01.01','2026.10.01')]:
        for cell in cells:
            runs.append(dict(run_id=stage.lower()+'_'+cell['cell'],stage=stage,date_from=start,date_to=end,
                             label='KNOWN_RETROSPECTIVE_NOT_OOS',**cell))
    frozen=OUT/'frozen';frozen.mkdir(parents=True)
    (frozen/'quality12b_snapshot.mq5').write_text(source,encoding='utf-8')
    (frozen/'inputs.json').write_text(json.dumps(values,indent=2)+'\n')
    preset='; RelativeContinuation v2 only. NOT compatible with legacy quality12b.\n'+'\n'.join(f'{k}={v}' for k,v in values.items())+'\n'
    (frozen/'quality12b_full.set').write_text(preset,encoding='ascii')
    presets=ROOT/'presets/RelativeContinuation';presets.mkdir(exist_ok=True,parents=True)
    (presets/'USDJPY_relative_baseline.set').write_text(preset,encoding='ascii')
    analyzer=ROOT/'tools/quality12b/analyze_relative_search.py'
    manifest=dict(schema=1,purpose='RELATIVE_CONTINUATION_SEARCH',created='2026-10-07',input_count=len(values),
                  source=str(main.relative_to(ROOT)),source_sha256=digest(frozen/'quality12b_snapshot.mq5'),
                  analysis_sha256=digest(analyzer),expected_broker='Vantage Trading Ltd',expected_server='VantageTradingLtd-Live',
                  reference_reports=[],symbol='USDJPY',timeframe='M15',model=4,execution_mode=0,
                  deposit=10000,currency='USD',leverage=100,runs=runs,
                  sha256={p.relative_to(OUT).as_posix():digest(p) for p in frozen.iterdir()})
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'Frozen {len(cells)} cells, {len(runs)} runs, {len(values)} inputs. No application launched.')

if __name__=='__main__': prepare()
