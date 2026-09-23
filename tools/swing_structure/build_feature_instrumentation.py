"""Copy the canonical engine and add observational callbacks only."""
from pathlib import Path
import hashlib,json,difflib
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/qa/three_wave/feature_research'
OUT.mkdir(parents=True,exist_ok=True)
files=['mql/Experts/USDJPY_M1_M5_3WaveIn3Wave_Long.mq5','mql/Experts/USDJPY_M1_M5_3WaveIn3Wave_Long.ex5',
       'mql/Include/ThreeWaveStructure.mqh','mql/Include/ThreeWaveInputs.mqh','mql/Include/ThreeWaveDrawing.mqh',
       'mql/Indicators/MultiTF_3WaveIn3Wave_Visualizer_Shared.mq5','mql/Indicators/MultiTF_3WaveIn3Wave_Visualizer_Shared.ex5']
manifest={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in files}
if (OUT/'production_manifest.json').exists():
    assert json.loads((OUT/'production_manifest.json').read_text())==manifest,'Production changed during research'
else:(OUT/'production_manifest.json').write_text(json.dumps(manifest,indent=2))
source=(ROOT/'mql/Include/ThreeWaveStructure.mqh').read_text(encoding='utf-8-sig')
anchor='      // READY requires a currently-valid confirmed HL'
assert source.count(anchor)==1
modified=source.replace(anchor,'''      // Observation only: callback rejects historical closes and never mutates structure.
      if(pat.found_choch && pat.choch_time==r[i].time)
         TWFeatureCandidate(s,pat,close_time,"CHOCH");
      if(pat.found_hl && pat.hl.confirmed_time==close_time)
         TWFeatureCandidate(s,pat,close_time,"HL");

'''+anchor)
(ROOT/'mql/Include/ThreeWaveFeatureObserver.mqh').write_text(modified,encoding='utf-8')
(OUT/'observer.diff').write_text(''.join(difflib.unified_diff(source.splitlines(True),modified.splitlines(True),fromfile='Shared unchanged',tofile='research observer copy')),encoding='utf-8')
