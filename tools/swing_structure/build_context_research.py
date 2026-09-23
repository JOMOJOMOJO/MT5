"""Generate observational EA from the immutable previous feature recorder."""
from pathlib import Path
import hashlib,json,difflib
R=Path(__file__).resolve().parents[2]
O=R/'reports/qa/three_wave/context_research';O.mkdir(parents=True,exist_ok=True)
old=json.loads((R/'reports/qa/three_wave/feature_research/production_manifest.json').read_text())
paths=list(old)+['mql/Experts/USDJPY_3Wave_FeatureResearch.mq5','mql/Experts/USDJPY_3Wave_FeatureResearch.ex5','mql/Include/ThreeWaveFeatureObserver.mqh']
manifest={p:hashlib.sha256((R/p).read_bytes()).hexdigest() for p in paths}
assert all(manifest[p]==h for p,h in old.items()),'Production baseline changed'
mf=O/'baseline_manifest.json'
if mf.exists():assert json.loads(mf.read_text())==manifest,'Baseline changed during research'
else:mf.write_text(json.dumps(manifest,indent=2))
s=(R/paths[-3]).read_text(encoding='utf-8-sig')
t=s.replace('#include "../Include/ThreeWaveFeatureObserver.mqh"','#include "../Include/ThreeWaveFeatureObserver.mqh"\n#include "../Include/ThreeWaveContextResearch.mqh"')
t=t.replace('   AddShadow(id,"STAGE",','   ContextRecord(id,close_time,tick.ask);\n   AddShadow(id,"STAGE",')
t=t.replace('   h_ema=iMA(', '   if(!ContextInit()) return INIT_FAILED;\n   h_ema=iMA(')
t=t.replace('   Print("TW_FEATURE_RESULT','   ContextDeinit();\n   Print("TW_FEATURE_RESULT')
assert t.count('ContextRecord(')==1 and t.count('ContextInit()')==1
(R/'mql/Experts/USDJPY_3Wave_ContextResearch.mq5').write_text(t,encoding='utf-8')
(O/'recorder.diff').write_text(''.join(difflib.unified_diff(s.splitlines(True),t.splitlines(True),fromfile='Previous feature recorder unchanged',tofile='Context recorder')),encoding='utf-8')
# Isolated runner follows the previously authorized path; copies only extra context output.
p=(R/'tools/swing_structure/run-three-wave-features.ps1').read_text(encoding='utf-8-sig')
p=p.replace('USDJPY_3Wave_FeatureResearch','USDJPY_3Wave_ContextResearch').replace('feature_research','context_research')
p=p.replace("-Filter 'TW_feature*.csv'","-Filter 'TW_*.csv'")
p=p.replace("Get-ChildItem $qa -Filter ('tw_'+$Run+'*.png') | Copy-Item", "Get-ChildItem $qa -Filter ('tw_'+$Run+'*.png') | Where-Object {$_.LastWriteTimeUtc -ge $start.AddSeconds(-2)} | Copy-Item")
(R/'tools/swing_structure/run-three-wave-context.ps1').write_text(p,encoding='utf-8')
gap=(R/'mql/Scripts/tests/ThreeWaveFeatureGapAudit.mq5').read_text(encoding='utf-8-sig')
gap=gap.replace("D'2024.12.25'","D'2025.07.25'").replace("D'2024.12.01'","D'2025.07.01'")
gap=gap.replace("D'2025.08.01'","D'2025.11.01'").replace("D'2025.01.01'","D'2025.08.01'")
gap=gap.replace(" || (current>=D'2025.04.01'&&current<D'2025.05.01')",'')
gap=gap.replace('TW_feature_gaps.csv','TW_context_gaps.csv').replace('void OnStart()','void ContextGapMain()')
gap=gap.replace('if(n>100)break;',"if(n>100 && all[n-1].time>=D'2025.10.31')break;")
gap=gap.replace('if(n<100){',"if(n<100 || all[n-1].time<D'2025.10.31'){")
gap=gap.replace('if(warm_count>100)break;',"if(warm_count>100 && warm[warm_count-1].time>=D'2025.10.31')break;")
gap=gap.replace('if(warm_count<100){',"if(warm_count<100 || warm[warm_count-1].time<D'2025.10.31'){")
gap+='''
void OnStart()
{
   ContextGapMain();
   int result=FileOpen("TW_context_gap_result.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(result!=INVALID_HANDLE)
   {
      FileWrite(result,"gaps","missed_candidates","errors","passed");
      FileWrite(result,gaps,gap_found,errors,gaps>0 && gap_found==0 && errors==0);
      FileClose(result);
   }
}
'''
(R/'mql/Scripts/tests/ThreeWaveContextGapAudit.mq5').write_text(gap,encoding='utf-8')
print('Generated context EA and isolated runner; baseline hashes match.')
